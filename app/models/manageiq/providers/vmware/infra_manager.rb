module ManageIQ::Providers
  class Vmware::InfraManager < InfraManager
    require_nested :DistributedVirtualSwitch
    require_nested :OrchestrationTemplate
    require_nested :EventCatcher
    require_nested :EventParser
    require_nested :RefreshWorker
    require_nested :RefreshParser
    require_nested :MetricsCapture
    require_nested :MetricsCollectorWorker
    require_nested :Refresher
    require_nested :Host
    require_nested :HostEsx
    require_nested :HostVirtualSwitch
    require_nested :Inventory
    require_nested :Provision
    require_nested :ProvisionViaPxe
    require_nested :ProvisionWorkflow
    require_nested :SelectorSpec
    require_nested :Template
    require_nested :Vm

    include VimConnectMixin

    before_save :stop_event_monitor_queue_on_change
    before_destroy :stop_event_monitor

    supports :provisioning
    supports :smartstate_analysis
    supports :streaming_refresh do
      unsupported_reason_add(:streaming_refresh, "Streaming refresh not enabled") unless streaming_refresh_enabled?
    end

    has_many :host_guest_devices, :through => :host_hardwares, :source => :guest_devices
    has_many :miq_scsi_targets, -> { distinct }, :through => :host_guest_devices
    has_many :miq_scsi_luns, -> { distinct }, :through => :miq_scsi_targets
    has_many :host_system_services, :through => :hosts, :source => :system_services
    has_many :distributed_virtual_switches, :dependent => :destroy, :foreign_key => :ems_id

    def self.ems_type
      @ems_type ||= "vmwarews".freeze
    end

    def self.description
      @description ||= "VMware vCenter".freeze
    end

    def supported_auth_types
      %w(default console)
    end

    def supports_authentication?(authtype)
      supported_auth_types.include?(authtype.to_s)
    end

    def supported_catalog_types
      %w(vmware)
    end

    def streaming_refresh_enabled?
      Settings.prototype.ems_vmware.update_driven_refresh
    end

    def remote_console_vmrc_acquire_ticket
      vim = connect(:auth_type => :console)
      ticket = vim.acquireCloneTicket

      # The ticket received is valid for 30 seconds, but we can't disconnect the
      #   session until it is used.  So, in a separate thread we will disconnect
      #   after 30 seconds.
      Thread.new(vim) do |handle|
        begin
          sleep 30
        ensure
          handle.disconnect if handle rescue nil
        end
      end

      ticket
    end

    def remote_console_vmrc_support_known?
      !api_version.blank? && !hostname.blank? && !uid_ems.blank?
    end

    def validate_remote_console_vmrc_support
      raise(MiqException::RemoteConsoleNotSupportedError, "vCenter needs to be refreshed to determine VMRC remote console support.")   unless self.remote_console_vmrc_support_known?
      raise(MiqException::RemoteConsoleNotSupportedError, "vCenter version #{api_version} does not support VMRC remote console.") unless api_version >= "4.1"
      raise(MiqException::RemoteConsoleNotSupportedError, "vCenter versions earlier than 5.x are not supported.  Found version #{api_version}.") unless api_version >= "5."
      true
    end

    def validate_remote_console_webmks_support
      raise(MiqException::RemoteConsoleNotSupportedError, "vCenter version #{api_version} does not support WebMKS remote console.") unless api_version >= "6.0"
    end

    def self.use_vim_broker?
      return false if defined?(Rails::Console) && !::Settings.development.use_vim_broker_in_console
      MiqVimBrokerWorker.has_required_role?
    end

    delegate :use_vim_broker?, :to => :class

    def self.event_monitor_class
      self::EventCatcher
    end

    def self.provision_class(via)
      case via
      when "pxe" then self::ProvisionViaPxe
      else            self::Provision
      end
    end

    def self.default_blacklisted_event_names
      %w(
        AlarmActionTriggeredEvent
        AlarmCreatedEvent
        AlarmEmailCompletedEvent
        AlarmEmailFailedEvent
        AlarmReconfiguredEvent
        AlarmRemovedEvent
        AlarmScriptCompleteEvent
        AlarmScriptFailedEvent
        AlarmSnmpCompletedEvent
        AlarmSnmpFailedEvent
        AlarmStatusChangedEvent
        AlreadyAuthenticatedSessionEvent
        EventEx
        UserLoginSessionEvent
        UserLogoutSessionEvent
      )
    end

    def control_monitor
      MiqControlMonitor.find_by_ems(self)
    end

    def start_control_monitor
      MiqControlMonitor.start_worker_for_ems(self)
    end

    def stop_control_monitor
      _log.info "EMS [#{name}] id [#{id}]: Stopping control monitor."
      MiqControlMonitor.stop_worker_for_ems(self)
    end

    def verify_credentials(auth_type = nil, _options = {})
      self.class.raw_connect(:use_broker => false, :ems => self)
    end

    def reset_vim_cache
      return unless self.use_vim_broker?
      with_provider_connection do |vim|
        _log.info("Resetting broker cache for EMS id: [#{id}]")
        vim.resetCache
      end
    end

    def reset_vim_cache_queue
      return unless self.use_vim_broker?
      MiqQueue.put(
        :class_name  => self.class.name,
        :method_name => "reset_vim_cache",
        :instance_id => id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :queue_name  => MiqEmsRefreshWorker.queue_name_for_ems(self),
        :zone        => my_zone,
        :role        => "ems_inventory"
      )
    end

    def get_alarms
      with_provider_connection do |vim|
        miqAm = vim.getVimAlarmManager
        miqAm.getAlarm
      end
    end

    def vm_start(vm, options = {})
      invoke_vim_ws(:start, vm, options[:user_event])
    end

    def vm_stop(vm, options = {})
      invoke_vim_ws(:stop, vm, options[:user_event])
    end

    def vm_poweroff(vm, options = {})
      vm_stop(vm, options)
    end

    def vm_suspend(vm, options = {})
      invoke_vim_ws(:suspend, vm, options[:user_event])
    end

    def vm_shutdown_guest(vm, options = {})
      invoke_vim_ws(:shutdownGuest, vm, options[:user_event])
    end

    def vm_reboot_guest(vm, options = {})
      invoke_vim_ws(:rebootGuest, vm, options[:user_event])
    end

    def vm_reset(vm, options = {})
      invoke_vim_ws(:reset, vm, options[:user_event])
    end

    def vm_standby_guest(vm, options = {})
      invoke_vim_ws(:standbyGuest, vm, options[:user_event])
    end

    def vm_unregister(vm, options = {})
      invoke_vim_ws(:unregister, vm, options[:user_event])
    end

    def vm_mark_as_template(vm, options = {})
      invoke_vim_ws(:markAsTemplate, vm, options[:user_event])
    end

    def vm_mark_as_vm(vm, options = {})
      defaults = {
        :host     => nil,
      }
      options = defaults.merge(options)
      invoke_vim_ws(:markAsVm, vm, options[:user_event], options[:pool], options[:host])
    end

    def vm_migrate(vm, options = {})
      defaults = {
        :pool     => nil,
        :priority => "defaultPriority",
        :state    => nil
      }
      options = defaults.merge(options)

      # Convert host to its MOR, if host is an ActiveRecord Host
      host     = options[:host]
      host_mor = host.kind_of?(Host) ? host.ems_ref_obj : host

      # If pool is nil, use the host's default resource pool, if possible
      # Convert pool to its MOR, if pool is an ActiveRecord ResourcePool
      pool     = options[:pool]
      pool ||= (host.default_resource_pool || (host.ems_cluster && host.ems_cluster.default_resource_pool)) if host.kind_of?(Host)
      pool_mor = pool.kind_of?(ResourcePool) ? pool.ems_ref_obj : pool

      invoke_vim_ws(:migrate, vm, options[:user_event], host_mor, pool_mor, options[:priority], options[:state])
    end

    def vm_relocate(vm, options = {})
      defaults = {
        :host           => nil,
        :pool           => nil,
        :datastore      => nil,
        :disk_move_type => nil,
        :transform      => nil,
        :priority       => "defaultPriority",
        :disk           => nil
      }
      options = defaults.merge(options)
      invoke_vim_ws(:relocateVM, vm, options[:user_event], options[:host], options[:pool], options[:datastore], options[:disk_move_type], options[:transform], options[:priority], options[:disk])
    end

    def vm_move_into_folder(vm, options = {})
      invoke_vim_ws(:moveIntoFolder, options[:folder], options[:user_event], vm.ems_ref_obj)
    end

    def vm_clone(vm, options = {})
      defaults = {
        :pool          => nil,
        :host          => nil,
        :datastore     => nil,
        :powerOn       => false,
        :template      => false,
        :transform     => nil,
        :config        => nil,
        :customization => nil,
        :disk          => nil
      }
      options = defaults.merge(options)
      invoke_vim_ws(:cloneVM, vm, options[:user_event], options[:name], options[:folder], options[:pool], options[:host], options[:datastore], options[:powerOn], options[:template], options[:transform], options[:config], options[:customization], options[:disk])
    end

    def vm_rename(vm, options = {})
      invoke_vim_ws(:renameVM, vm, options[:user_event], options[:new_name])
    end

    def vm_connect_all(vm, options = {})
      defaults = {:onStartup => false}
      options  = defaults.merge(options)
      vm_connect_disconnect_all_connectable_devices(vm, true, options[:onStartup], options[:user_event])
    end

    def vm_disconnect_all(vm, options = {})
      defaults = {:onStartup => false}
      options  = defaults.merge(options)
      vm_connect_disconnect_all_connectable_devices(vm, false, options[:onStartup], options[:user_event])
    end

    def vm_connect_cdrom(vm, options = {})
      defaults = {:onStartup => false}
      options  = defaults.merge(options)
      vm_connect_disconnect_cdrom(vm, true, options[:onStartup], options[:user_event])
    end

    def vm_disconnect_cdrom(vm, options = {})
      defaults = {:onStartup => false}
      options  = defaults.merge(options)
      vm_connect_disconnect_cdrom(vm, false, options[:onStartup], options[:user_event])
    end

    def vm_connect_floppy(vm, options = {})
      defaults = {:onStartup => false}
      options  = defaults.merge(options)
      vm_connect_disconnect_floppy(vm, true, options[:onStartup], options[:user_event])
    end

    def vm_disconnect_floppy(vm, options = {})
      defaults = {:onStartup => false}
      options  = defaults.merge(options)
      vm_connect_disconnect_floppy(vm, false, options[:onStartup], options[:user_event])
    end

    def vm_connect_disconnect_cdrom(vm, connect, onStartup = false, user_event = nil)
      vm_connect_disconnect_specified_connectable_devices(vm, "CD/DVD Drive", connect, onStartup, user_event)
    end

    def vm_connect_disconnect_floppy(vm, connect, onStartup = false, user_event = nil)
      vm_connect_disconnect_specified_connectable_devices(vm, "Floppy Drive", connect, onStartup, user_event)
    end

    def vm_connect_disconnect_all_connectable_devices(vm, connect, onStartup = false, user_event = nil)
      vm_connect_disconnect_specified_connectable_devices(vm, "*", connect, onStartup, user_event)
    end

    def vm_connect_disconnect_specified_connectable_devices(vm, deviceLabel, connect, onStartup = false, user_event = nil)
      vm.with_provider_object do |vim_vm|
        vim_vm.logUserEvent(user_event) if user_event

        _log.info("EMS: [#{name}] VM path [#{vm.path}] Invoking [devicesByFilter]...")
        devs = vim_vm.devicesByFilter("connectable.connected" => /(false|true)/)
        devs.each do |dev|
          currentLabel = dev['deviceInfo']['label']
          next if  (deviceLabel != "*") && (currentLabel.index(deviceLabel) != 0)
          _log.info("EMS: [#{name}] VM path [#{vm.path}] Invoking [connectDevice] for device [#{currentLabel}]...")
          result = vim_vm.connectDevice(dev, connect, onStartup)
          _log.info("EMS: [#{name}] VM path [#{vm.path}] Returned with result [#{result}]...")
        end

        _log.info("EMS: [#{name}] VM path [#{vm.path}] Invoking [refresh]...")
        vim_vm.refresh
      end
    end

    def vm_create_snapshot(vm, options = {})
      defaults = {
        :memory             => false,
        :quiesce            => "false",
        :wait               => true,
        :free_space_percent => ::Settings.snapshots.create_free_percent
      }
      options = defaults.merge(options)
      invoke_vim_ws(:createSnapshot, vm, options[:user_event], options[:name], options[:desc], options[:memory], options[:quiesce], options[:wait], options[:free_space_percent])
    end

    def vm_create_evm_snapshot(vm, options = {})
      defaults = {
        :quiesce            => "false",
        :wait               => true,
        :free_space_percent => ::Settings.snapshots.create_free_percent
      }
      options = defaults.merge(options)
      invoke_vim_ws(:createEvmSnapshot, vm, options[:user_event], options[:desc], options[:quiesce], options[:wait], options[:free_space_percent])
    end

    def vm_remove_snapshot(vm, options = {})
      defaults = {
        :subTree            => "false",
        :wait               => true,
        :free_space_percent => ::Settings.snapshots.remove_free_percent
      }
      options = defaults.merge(options)
      invoke_vim_ws(:removeSnapshot, vm, options[:user_event], options[:snMor], options[:subTree], options[:wait], options[:free_space_percent])
    end

    def vm_remove_snapshot_by_description(vm, options = {})
      defaults = {
        :subTree            => "false",
        :refresh            => false,
        :wait               => true,
        :free_space_percent => ::Settings.snapshots.remove_free_percent
      }
      options.reverse_merge!(defaults)
      invoke_vim_ws(:removeSnapshotByDescription, vm, options[:user_event], options[:description], options[:refresh], options[:subTree], options[:wait], options[:free_space_percent])
    end

    def vm_remove_all_snapshots(vm, options = {})
      defaults = {
        :free_space_percent => ::Settings.snapshots.remove_free_percent
      }
      options.reverse_merge!(defaults)
      invoke_vim_ws(:removeAllSnapshots, vm, options[:user_event], options[:free_space_percent])
    end

    def vm_revert_to_snapshot(vm, options = {})
      invoke_vim_ws(:revertToSnapshot, vm, options[:user_event], options[:snMor])
    end

    def vm_add_disk(vm, options = {})
      invoke_vim_ws(:addDisk, vm, options[:user_event], options[:diskName], options[:diskSize], nil, nil,
                    :thin_provisioned => options[:thinProvisioned], :dependent => options[:dependent], :persistent => options[:persistent])
    end

    def vm_remove_disk_by_file(vm, options = {})
      options[:delete_backing] = true if options[:delete_backing].nil?
      invoke_vim_ws(:removeDiskByFile, vm, options[:user_event], options[:diskName], options[:delete_backing])
    end
    alias vm_remove_disk vm_remove_disk_by_file

    def vm_acquire_ticket(vm, options = {})
      invoke_vim_ws(:acquireTicket, vm, options[:user_event], options[:ticket_type])
    end
    alias_method :vm_remote_console_acquire_ticket, :vm_acquire_ticket

    def vm_acquire_webmks_ticket(vm, options = {})
      vm_acquire_ticket(vm, options.merge(:ticket_type => 'webmks'))
    end
    alias_method :vm_remote_console_webmks_acquire_ticket, :vm_acquire_webmks_ticket

    def vm_add_miq_alarm(vm, _options = {})
      result = nil
      vm.with_provider_object do |vim_vm|
        vim_vm.removeMiqAlarm
        result = vim_vm.addMiqAlarm
      end
      result
    end

    def vm_set_memory(vm, options = {})
      invoke_vim_ws(:setMemory, vm, options[:user_event], options[:value])
    end

    def vm_set_num_cpus(vm, options = {})
      invoke_vim_ws(:setNumCPUs, vm, options[:user_event], options[:value])
    end

    def vm_set_custom_field(vm, options = {})
      invoke_vim_ws(:setCustomField, vm, options[:user_event], options[:attribute], options[:value])
    end

    def vm_reconfigure(vm, options = {})
      invoke_vim_ws(:reconfig, vm, options[:user_event], options[:spec])
    end

    def vm_destroy(vm, options = {})
      invoke_vim_ws(:destroy, vm, options[:user_event])
    end

    def vm_quick_stats(obj, options = {})
      invoke_vim_ws(:quickStats, obj, options[:user_event])
    end
    alias_method :host_quick_stats, :vm_quick_stats

    def invoke_vim_ws(cmd, obj, user_event = nil, *opts)
      log_header = "EMS: [#{name}] #{obj.class.name}: id [#{obj.id}], name [#{obj.name}], ems_ref [#{obj.ems_ref}]"
      result = nil

      if obj.kind_of?(self.class::Vm) || obj.kind_of?(self.class::Template) || obj.kind_of?(self.class::Host) || obj.kind_of?(EmsCluster) || obj.kind_of?(EmsFolder)
        obj.with_provider_object do |vim_obj|
          vim_obj.logUserEvent(user_event) if user_event && obj.kind_of?(Vm)

          _log.info("#{log_header} Invoking [#{cmd}]...")
          result = vim_obj.send(cmd, *opts)
          _log.info("#{log_header} Returned with result [#{result}]")
        end
      else
        _log.warn("#{log_header} VIM calls not supported, invocation skipped")
      end

      result
    end

    def vm_log_user_event(vm, event_message)
      vm.with_provider_object do |vim_vm|
        vim_vm.logUserEvent(event_message)
      end
      nil
    end

    # Find the VmCreated events for a list of VMs and return the time
    def find_vm_create_events(vms_list)
      # Create a hash of VM uuids for lookup
      vm_guids = {}
      vms_list.each { |v| vm_guids[v[:uid_ems]] = v }

      found = []
      event_array = ['VmCreatedEvent']

      with_provider_connection do |vim|
        eventSpec = VimHash.new("EventFilterSpec") do |efs|
          efs.time = VimHash.new("EventFilterSpecByTime") { |eft| eft.endTime = vim.currentServerTime.to_s }
          efs.disableFullMessage = 'false'
          if vim.v4
            efs.eventTypeId = event_array
          else
            efs['type'] = event_array
          end
        end

        miqEh = vim.getVimEventHistory(eventSpec)
        begin
          miqEh.events do |event|
            # Check to see if the VM is still in the inventory.
            # Match by MOR and VM name, just in case the MOR was reused.
            vm = vim.virtualMachinesByFilter('summary.vm' => event.vm.vm, 'config.name' => event.vm.name).first unless event.vm.nil?
            next if vm.nil?
            current_uid = vm.config.uuid
            if vm_guids.key?(current_uid)
              item  = vm_guids.delete(current_uid)
              item[:created_time] = event.createdTime
              found << item
            end
            break if vm_guids.empty?
          end
        ensure
          miqEh.release unless miqEh.nil? rescue nil
        end
      end

      # Return list of VMs that we found create events for
      found
    end

    def get_files_on_datastore(datastore)
      with_provider_connection do |vim|
        begin
          vim_ds = vim.getVimDataStore(datastore.name)
          return vim_ds.dsFolderFileList
        rescue Handsoap::Fault, StandardError, Timeout::Error, DRb::DRbConnError => err
          _log.log_backtrace(err)
          raise MiqException::MiqStorageError, "Error communicating with Host: [#{name}]"
        ensure
          begin
            vim_ds.release if vim_ds
          rescue
            # TODO: specify what to rescue
            # TODO: log it
            nil
          end
        end
      end

      nil
    end

    def refresh_files_on_datastore(datastore)
      hashes = self.class::RefreshParser.datastore_file_inv_to_hashes(
        get_files_on_datastore(datastore), datastore.vm_ids_by_path)
      EmsRefresh.save_storage_files_inventory(datastore, hashes)
    end
  end

  def self.display_name(number = 1)
    n_('Infrastructure Provider (VMware)', 'Infrastructure Providers (VMware)', number)
  end
end
