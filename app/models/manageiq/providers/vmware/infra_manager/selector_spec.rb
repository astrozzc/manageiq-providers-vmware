module ManageIQ::Providers::Vmware::InfraManager::SelectorSpec
  VIM_SELECTOR_SPEC = {
    :ems_refresh_host        => [
      "MOR",
      "config.adminDisabled",
      "config.consoleReservation.serviceConsoleReserved",
      "config.hyperThread.active",
      "config.network.consoleVnic[*].device",
      "config.network.consoleVnic[*].port",
      "config.network.consoleVnic[*].portgroup",
      "config.network.consoleVnic[*].spec.ip.dhcp",
      "config.network.consoleVnic[*].spec.ip.ipAddress",
      "config.network.consoleVnic[*].spec.ip.subnetMask",
      "config.network.dnsConfig.domainName",
      "config.network.dnsConfig.hostName",
      "config.network.ipRouteConfig.defaultGateway",
      "config.network.opaqueNetwork[*].opaqueNetworkId",
      "config.network.opaqueNetwork[*].opaqueNetworkName",
      "config.network.opaqueNetwork[*].opaqueNetworkType",
      "config.network.opaqueSwitch[*].key",
      "config.network.opaqueSwitch[*].name",
      "config.network.opaqueSwitch[*].pnic",
      "config.network.opaqueSwitch[*].status",
      "config.network.pnic[*].device",
      "config.network.pnic[*].key",
      "config.network.pnic[*].pci",
      "config.network.pnic[*].mac",
      "config.network.pnic[*].linkSpeed",
      "config.network.portgroup[*].computedPolicy.security.allowPromiscuous",
      "config.network.portgroup[*].computedPolicy.security.forgedTransmits",
      "config.network.portgroup[*].computedPolicy.security.macChanges",
      "config.network.portgroup[*].port[*].key",
      "config.network.portgroup[*].spec.name",
      "config.network.portgroup[*].spec.policy.security.allowPromiscuous",
      "config.network.portgroup[*].spec.policy.security.forgedTransmits",
      "config.network.portgroup[*].spec.policy.security.macChanges",
      "config.network.portgroup[*].spec.vlanId",
      "config.network.portgroup[*].spec.vswitchName",
      "config.network.portgroup[*].vswitch",
      "config.network.vnic[*].device",
      "config.network.vnic[*].port",
      "config.network.vnic[*].portgroup",
      "config.network.vnic[*].spec.ip.dhcp",
      "config.network.vnic[*].spec.ip.ipAddress",
      "config.network.vnic[*].spec.ip.subnetMask",
      "config.network.vswitch[*].key",
      "config.network.vswitch[*].mtu",
      "config.network.vswitch[*].name",
      "config.network.vswitch[*].numPorts",
      "config.network.vswitch[*].pnic",
      "config.network.vswitch[*].spec.policy.security.allowPromiscuous",
      "config.network.vswitch[*].spec.policy.security.forgedTransmits",
      "config.network.vswitch[*].spec.policy.security.macChanges",
      "config.service.service[*].key",
      "config.service.service[*].label",
      "config.service.service[*].running",
      "datastore",
      "datastore.ManagedObjectReference",
      "hardware.systemInfo.otherIdentifyingInfo[*].identifierValue",
      "hardware.systemInfo.otherIdentifyingInfo[*].identifierType.key",
      "hardware.systemInfo.uuid",
      "name",
      "summary.config.name",
      "summary.config.product.build",
      "summary.config.product.name",
      "summary.config.product.osType",
      "summary.config.product.vendor",
      "summary.config.product.version",
      "summary.config.vmotionEnabled",
      "summary.hardware.cpuMhz",
      "summary.hardware.cpuModel",
      "summary.hardware.memorySize",
      "summary.hardware.model",
      "summary.hardware.numCpuCores",
      "summary.hardware.numCpuPkgs",
      "summary.hardware.numNics",
      "summary.hardware.vendor",
      "summary.quickStats.overallCpuUsage",
      "summary.quickStats.overallMemoryUsage",
      "summary.runtime.connectionState",
      "summary.runtime.inMaintenanceMode",
    ],

    :ems_refresh_vm          => [
      "MOR",
      "availableField[*].key",
      "availableField[*].name",
      "config.cpuAffinity.affinitySet",
      "config.cpuHotAddEnabled",
      "config.cpuHotRemoveEnabled",
      "config.defaultPowerOps.standbyAction",
      "config.hardware.device[*].backing.compatibilityMode",
      "config.hardware.device[*].backing.datastore",
      "config.hardware.device[*].backing.deviceName",
      "config.hardware.device[*].backing.port.switchUuid",
      "config.hardware.device[*].backing.port.portgroupKey",
      "config.hardware.device[*].backing.diskMode",
      "config.hardware.device[*].backing.fileName",
      "config.hardware.device[*].backing.thinProvisioned",
      "config.hardware.device[*].busNumber",
      "config.hardware.device[*].capacityInKB",
      "config.hardware.device[*].connectable.connected",
      "config.hardware.device[*].connectable.startConnected",
      "config.hardware.device[*].controllerKey",
      "config.hardware.device[*].deviceInfo.label",
      "config.hardware.device[*].key",
      "config.hardware.device[*].macAddress",
      "config.hardware.device[*].unitNumber",
      "config.hardware.numCoresPerSocket",
      "config.hotPlugMemoryIncrementSize",
      "config.hotPlugMemoryLimit",
      "config.memoryHotAddEnabled",
      "config.uuid",
      "config.version",
      "datastore",
      "datastore.ManagedObjectReference",
      "guest.net[*].ipAddress",
      "guest.net[*].macAddress",
      "resourceConfig.cpuAllocation.expandableReservation",
      "resourceConfig.cpuAllocation.limit",
      "resourceConfig.cpuAllocation.reservation",
      "resourceConfig.cpuAllocation.shares.level",
      "resourceConfig.cpuAllocation.shares.shares",
      "resourceConfig.memoryAllocation.expandableReservation",
      "resourceConfig.memoryAllocation.limit",
      "resourceConfig.memoryAllocation.reservation",
      "resourceConfig.memoryAllocation.shares.level",
      "resourceConfig.memoryAllocation.shares.shares",
      "snapshot.currentSnapshot",
      "snapshot.rootSnapshotList[*].createTime",
      "snapshot.rootSnapshotList[*].description",
      "snapshot.rootSnapshotList[*].name",
      "snapshot.rootSnapshotList[*].snapshot",
      "snapshot.rootSnapshotList[*].childSnapshotList", # Recursively uses: createTime, description, name, snapshot, childSnapshotList
      "summary.config.annotation",
      "summary.config.ftInfo.instanceUuids",
      "summary.config.guestFullName",
      "summary.config.guestId",
      "summary.config.memorySizeMB",
      "summary.config.name",
      "summary.config.numCpu",
      "summary.config.template",
      "summary.config.uuid",
      "summary.config.vmLocalPathName",
      "summary.config.vmPathName",
      "summary.customValue[*].key",
      "summary.customValue[*].value",
      "summary.guest.hostName",
      "summary.guest.ipAddress",
      "summary.guest.toolsStatus",
      "summary.runtime.bootTime",
      "summary.runtime.connectionState",
      "summary.runtime.host",
      "summary.runtime.powerState",
      "summary.storage.unshared",
      "summary.storage.committed"
    ],

    :ems_refresh_storage     => [
      "MOR",
      "capability.directoryHierarchySupported",
      "capability.perFileThinProvisioningSupported",
      "capability.rawDiskMappingsSupported",
      "host",
      "summary.capacity",
      "summary.datastore",
      "summary.freeSpace",
      "summary.multipleHostAccess",
      "summary.name",
      "summary.type",
      "summary.uncommitted",
      "summary.url",
      "parent"
    ],

    :ems_refresh_storage_pod => [
      "MOR",
      "summary.capacity",
      "summary.freeSpace",
      "summary.name",
      "childEntity",
      "parent"
    ],

    :ems_refresh_dvportgroup => [
      "MOR",
      "host",
      "config.key",
      "config.distributedVirtualSwitch",
      "config.name",
      "summary.name",
      "parent",
      "tag"
    ],

    :ems_refresh_dvswitch    => [
      "MOR",
      "config.uplinkPortgroup",
      "config.defaultPortConfig",
      "config.numPorts",
      "summary.name",
      "summary.uuid",
      "summary.host",
      "summary.hostMember",
      "parent"
    ],

    :ems_refresh_cluster     => [
      "MOR",
      "configuration.dasConfig.admissionControlEnabled",
      "configuration.dasConfig.admissionControlPolicy",
      "configuration.dasConfig.enabled",
      "configuration.dasConfig.failoverLevel",
      "configuration.drsConfig.defaultVmBehavior",
      "configuration.drsConfig.enabled",
      "configuration.drsConfig.vmotionRate",
      "host",
      "host.ManagedObjectReference",
      "name",
      "parent", # Used by ManageIQ::Providers::Vmware::InfraManager::RefreshParser::Filter#ems_metadata_inv_by_*
      "resourcePool",
      "resourcePool.ManagedObjectReference",
      "summary.effectiveCpu",
      "summary.effectiveMemory",
    ],

    :ems_refresh_host_res    => [
      "host",
      "host.ManagedObjectReference",
      "parent", # Used by ManageIQ::Providers::Vmware::InfraManager::RefreshParser::Filter#ems_metadata_inv_by_*
      "resourcePool",
      "resourcePool.ManagedObjectReference",
    ],

    :ems_refresh_rp          => [
      "MOR",
      "name",
      "parent", # Used by ManageIQ::Providers::Vmware::InfraManager::RefreshParser::Filter#ems_metadata_inv_by_*
      "resourcePool",
      "resourcePool.ManagedObjectReference",
      "summary.config.cpuAllocation.expandableReservation",
      "summary.config.cpuAllocation.limit",
      "summary.config.cpuAllocation.reservation",
      "summary.config.cpuAllocation.shares.level",
      "summary.config.cpuAllocation.shares.shares",
      "summary.config.memoryAllocation.expandableReservation",
      "summary.config.memoryAllocation.limit",
      "summary.config.memoryAllocation.reservation",
      "summary.config.memoryAllocation.shares.level",
      "summary.config.memoryAllocation.shares.shares",
      "vm",
      "vm.ManagedObjectReference",
    ],

    :ems_refresh_folder      => [
      "MOR",
      "childEntity",
      "childEntity.ManagedObjectReference",
      "name",
      "parent", # Used by ManageIQ::Providers::Vmware::InfraManager::RefreshParser::Filter#ems_metadata_inv_by_*
    ],

    :ems_refresh_dc          => [
      "MOR",
      "datastoreFolder",
      "datastoreFolder.ManagedObjectReference",
      "hostFolder",
      "hostFolder.ManagedObjectReference",
      "name",
      "networkFolder",
      "networkFolder.ManagedObjectReference",
      "parent", # Used by ManageIQ::Providers::Vmware::InfraManager::RefreshParser::Filter#ems_metadata_inv_by_*
      "vmFolder",
      "vmFolder.ManagedObjectReference",
    ],

    :ems_refresh_host_scsi   => [
      "MOR",
      "config.storageDevice.hostBusAdapter[*].authenticationProperties.chapAuthEnabled",
      "config.storageDevice.hostBusAdapter[*].device",
      "config.storageDevice.hostBusAdapter[*].iScsiAlias",
      "config.storageDevice.hostBusAdapter[*].iScsiName",
      "config.storageDevice.hostBusAdapter[*].key",
      "config.storageDevice.hostBusAdapter[*].model",
      "config.storageDevice.hostBusAdapter[*].pci",
      "config.storageDevice.scsiLun[*].canonicalName",
      "config.storageDevice.scsiLun[*].capacity.block",
      "config.storageDevice.scsiLun[*].capacity.blockSize",
      "config.storageDevice.scsiLun[*].deviceName",
      "config.storageDevice.scsiLun[*].deviceType",
      "config.storageDevice.scsiLun[*].key",
      "config.storageDevice.scsiLun[*].lunType",
      "config.storageDevice.scsiLun[*].uuid",
      "config.storageDevice.scsiTopology.adapter[*].adapter",
      "config.storageDevice.scsiTopology.adapter[*].target[*].lun[*].lun",
      "config.storageDevice.scsiTopology.adapter[*].target[*].lun[*].scsiLun",
      "config.storageDevice.scsiTopology.adapter[*].target[*].target",
      "config.storageDevice.scsiTopology.adapter[*].target[*].transport.address",
      "config.storageDevice.scsiTopology.adapter[*].target[*].transport.iScsiAlias",
      "config.storageDevice.scsiTopology.adapter[*].target[*].transport.iScsiName",
    ],

    :ems_refresh_licenses    => [
      "MOR",
      "licenses[*].name",
      "licenses[*].licenseKey",
      "licenses[*].editionKey",
      "licenses[*].total",
      "licenses[*].used"
    ],

    :ems_refresh_extensions  => [
      "MOR",
      "extensionList[*].key",
      "extensionList[*].company",
      "extensionList[*].description.label",
      "extensionList[*].description.summary",
      "extensionList[*].version",
    ]
  }
  # Virtual Apps are treated like Resource Pools
  VIM_SELECTOR_SPEC[:ems_refresh_vapp] = VIM_SELECTOR_SPEC[:ems_refresh_rp].dup

  def self.selected_property?(type, prop)
    selected = VIM_SELECTOR_SPEC[:"ems_refresh_#{type}"]
    return if selected.blank?

    prop = prop.gsub(/\[".+?"\]/, "[*]").gsub(/\[.+?\]/, "[*]") if prop.include?("[")
    prop = /^#{Regexp.escape(prop)}(?=\.|\[|$)/

    selected.any? { |s| s =~ prop }
  end
end
