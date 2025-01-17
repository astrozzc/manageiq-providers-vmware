require 'VMwareWebService/MiqVim'
require 'http-access2' # Required in case it is not already loaded

module ManageIQ::Providers
  module Vmware
    class InfraManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include InfraManager::RefreshParser::Filter

      # Development helper method for setting up the selector specs for VC
      def self.init_console(*_)
        return @initialized_console unless @initialized_console.nil?
        klass = ManageIQ::Providers::Vmware::InfraManager.use_vim_broker? ? MiqVimBroker : MiqVimInventory
        klass.cacheScope = :cache_scope_ems_refresh
        klass.setSelector(parent::SelectorSpec::VIM_SELECTOR_SPEC)
        @initialized_console = true
      end

      def collect_inventory_for_targets(ems, targets)
        Benchmark.realtime_block(:get_ems_data) { get_ems_data(ems) }
        Benchmark.realtime_block(:get_vc_data) { get_vc_data(ems) }

        Benchmark.realtime_block(:get_vc_data_storage_profile) { get_vc_data_storage_profile(ems, targets) }
        Benchmark.realtime_block(:get_vc_data_ems_customization_specs) { get_vc_data_ems_customization_specs(ems) } if targets.include?(ems)

        # Filter the data, and determine for which hosts we will need to get extended data
        filtered_host_mors = []
        targets_with_data = targets.collect do |target|
          filter_result, = Benchmark.realtime_block(:filter_vc_data) { filter_vc_data(ems, target) }

          target, filtered_data = filter_result
          filtered_host_mors += filtered_data[:host].keys
          [target, filtered_data]
        end
        filtered_host_mors.uniq!

        Benchmark.realtime_block(:get_vc_data_host_scsi) { get_vc_data_host_scsi(ems, filtered_host_mors) }

        # After collecting all inventory mark the date of the data
        @last_inventory_date = Time.now.utc

        return targets_with_data
      ensure
        disconnect_from_ems(ems)
      end

      def parse_targeted_inventory(ems, _target, inventory)
        log_header = format_ems_for_logging(ems)
        _log.debug "#{log_header} Parsing VC inventory..."
        hashes, = Benchmark.realtime_block(:parse_vc_data) do
          InfraManager::RefreshParser.ems_inv_to_hashes(inventory)
        end
        _log.debug "#{log_header} Parsing VC inventory...Complete"

        hashes
      end

      def save_inventory(ems, target, hashes)
        Benchmark.realtime_block(:db_save_inventory) do
          # TODO: really wanna kill this @ems_data instance var
          ems.update(@ems_data) unless @ems_data.nil?
          EmsRefresh.save_ems_inventory(ems, hashes, target)
        end
      end

      def post_refresh(ems, start_time)
        # Update the last_inventory_date in post_refresh because save_ems_inventory is
        # run on each target even though the inventory came from the same time.  This
        # would allow for the ems's last_inventory_date to be updated before each target.
        set_last_inventory_date(ems)

        log_header = format_ems_for_logging(ems)
        [VmOrTemplate, Host].each do |klass|
          next unless klass.respond_to?(:post_refresh_ems)
          _log.info "#{log_header} Performing post-refresh operations for #{klass} instances..."
          klass.post_refresh_ems(ems.id, start_time)
          _log.info "#{log_header} Performing post-refresh operations for #{klass} instances...Complete"
        end
      end

      def set_last_inventory_date(ems)
        ems.update!(:last_inventory_date => @last_inventory_date)
      end

      #
      # VC data collection methods
      #

      def collect_and_log_inventory(ems, type)
        log_header = format_ems_for_logging(ems)

        _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...")

        inv_hash = yield

        inv_count = inv_hash.blank? ? 0 : inv_hash.length
        @vc_data[type] = inv_hash unless inv_hash.blank?

        _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...Complete - Count: [#{inv_count}]")
      end

      VC_ACCESSORS_HASH = {
        :storage     => :dataStoresByMor,
        :storage_pod => :storagePodsByMor,
        :dvportgroup => :dvPortgroupsByMor,
        :dvswitch    => :dvSwitchesByMor,
        :host        => :hostSystemsByMor,
        :vm          => :virtualMachinesByMor,
        :dc          => :datacentersByMor,
        :folder      => :foldersByMor,
        :cluster     => :clusterComputeResourcesByMor,
        :host_res    => :computeResourcesByMor,
        :rp          => :resourcePoolsByMor,
        :vapp        => :virtualAppsByMor,
        :extensions  => :extensionManagersByMor,
        :licenses    => :licenseManagersByMor,
      }.freeze

      def get_vc_data(ems, accessors = VC_ACCESSORS_HASH, mor_filters = {})
        log_header = format_ems_for_logging(ems)

        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          @vc_data = Hash.new { |h, k| h[k] = {} }

          accessors.each do |type, accessor|
            _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...")
            if mor_filters.any?
              inv_hash = mor_filters[type].each_with_object({}) do |mor, memo|
                data = @vi.send(accessor, mor)
                memo[mor] = data unless data.nil?
              end
            else
              inv_hash = @vi.send(accessor, :"ems_refresh_#{type}")
            end
            EmsRefresh.log_inv_debug_trace(inv_hash, "#{_log.prefix} #{log_header} inv_hash:")

            @vc_data[type] = inv_hash unless inv_hash.blank?
            _log.info("#{log_header} Retrieving #{type.to_s.titleize} inventory...Complete - Count: [#{inv_hash.blank? ? 0 : inv_hash.length}]")
          end
        end

        # Merge Virtual Apps into Resource Pools
        if @vc_data.key?(:vapp)
          @vc_data[:rp] ||= {}
          @vc_data[:rp].merge!(@vc_data.delete(:vapp))
        end

        EmsRefresh.log_inv_debug_trace(@vc_data, "#{_log.prefix} #{log_header} @vc_data:", 2)
      end

      def get_vc_data_storage_profile(ems, targets)
        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          collect_and_log_inventory(ems, :storage_profile) do
            # Ignore storage profiles which cannot be added to virtual machines or virtual disks
            @vi.pbmProfilesByUid.reject { |_uid, profile| profile.profileCategory == "DATA_SERVICE_POLICY" }
          end

          unless @vc_data[:storage_profile].blank?
            storage_profile_ids = @vc_data[:storage_profile].keys

            collect_and_log_inventory(ems, :storage_profile_entity) { @vi.pbmQueryAssociatedEntity(storage_profile_ids) }

            if targets.include?(ems)
              collect_and_log_inventory(ems, :storage_profile_datastore) { @vi.pbmQueryMatchingHub(storage_profile_ids) }
            end
          end
        end
      end

      def get_vc_data_ems_customization_specs(ems)
        log_header = format_ems_for_logging(ems)

        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          _log.info("#{log_header} Retrieving Customization Spec inventory...")
          begin
            vim_csm = @vi.getVimCustomizationSpecManager
            @vc_data[:customization_specs] = vim_csm.getAllCustomizationSpecs
          rescue RuntimeError => err
            raise unless err.message.include?("not supported on this system")
            _log.info("#{log_header} #{err}")
          ensure
            vim_csm.release if vim_csm rescue nil
          end
          _log.info("#{log_header} Retrieving Customization Spec inventory...Complete - Count: [#{@vc_data[:customization_specs].length}]")

          EmsRefresh.log_inv_debug_trace(@vc_data[:customization_specs], "#{_log.prefix} #{log_header} customization_spec_inv:")
        end
      end

      def get_vc_data_host_scsi(ems, host_mors)
        log_header = format_ems_for_logging(ems)
        return _log.info("#{log_header} Not retrieving Storage Device inventory for hosts...") if host_mors.empty?

        cleanup_callback = proc { @vc_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          _log.info("#{log_header} Retrieving Storage Device inventory for [#{host_mors.length}] hosts...")
          host_mors.each do |mor|
            data = @vc_data.fetch_path(:host, mor)
            next if data.nil?

            _log.info("#{log_header} Retrieving Storage Device inventory for Host [#{mor}]...")
            begin
              vim_host = @vi.getVimHostByMor(mor)
              sd = vim_host.storageDevice(:ems_refresh_host_scsi)
              data.store_path('config', 'storageDevice', sd.fetch_path('config', 'storageDevice')) unless sd.nil?
            ensure
              vim_host.release if vim_host rescue nil
            end
            _log.info("#{log_header} Retrieving Storage Device inventory for Host [#{mor}]...Complete")
          end
          _log.info("#{log_header} Retrieving Storage Device inventory for [#{host_mors.length}] hosts...Complete")

          EmsRefresh.log_inv_debug_trace(@vc_data[:host], "#{_log.prefix} #{log_header} host_inv:")
        end
      end

      def get_ems_data(ems)
        log_header = format_ems_for_logging(ems)

        cleanup_callback = proc { @ems_data = nil }

        retrieve_from_vc(ems, cleanup_callback) do
          _log.info("#{log_header} Retrieving EMS information...")
          about = @vi.about
          @ems_data = {:api_version => about['apiVersion'], :uid_ems => about['instanceUuid']}
          _log.info("#{log_header} Retrieving EMS information...Complete")
        end

        EmsRefresh.log_inv_debug_trace(@ems_data, "#{_log.prefix} #{log_header} ext_management_system_inv:")
      end

      MAX_RETRIES = 5
      RETRY_SLEEP_TIME = 30 # seconds

      def retrieve_from_vc(ems, cleanup_callback = nil)
        return unless block_given?

        log_header = format_ems_for_logging(ems)

        retries = 0
        begin
          @vi ||= ems.connect
          yield
        rescue HTTPAccess2::Session::KeepAliveDisconnected => httperr
          # Handle this error by trying again multiple times and sleeping between attempts
          _log.log_backtrace(httperr)

          cleanup_callback.call unless cleanup_callback.nil?

          unless retries >= MAX_RETRIES
            retries += 1

            # disconnect before trying again
            disconnect_from_ems(ems)

            _log.warn("#{log_header} Abnormally disconnected from VC...Retrying in #{RETRY_SLEEP_TIME} seconds")
            sleep RETRY_SLEEP_TIME
            _log.warn("#{log_header} Beginning EMS refresh retry \##{retries}")
            retry
          end

          # after MAX_RETRIES, give up...
          raise "EMS: [#{ems.name}] Exhausted all #{MAX_RETRIES} retries."
        rescue Exception
          cleanup_callback.call unless cleanup_callback.nil?
          raise
        end
      end

      def disconnect_from_ems(ems)
        return if @vi.nil?
        _log.info("Disconnecting from EMS: [#{ems.name}], id: [#{ems.id}]...")
        @vi.disconnect
        @vi = nil
        _log.info("Disconnecting from EMS: [#{ems.name}], id: [#{ems.id}]...Complete")
      end
    end
  end
end
