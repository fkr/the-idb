module Puppetdb
  class Facts
    WINDOWS_VERSIONS = {
      '6.1.7601' => '7 SP1 / Server 2008 R2 SP1',
      '6.1.7600' => '7 / Server 2008 R2'
    }.freeze

    def self.for(machine, url)
      for_node(machine.fqdn, url)
    end

    include Virtus.model

    attribute :operatingsystem, String
    attribute :operatingsystemrelease, String
    attribute :architecture, String
    attribute :memorysize_mb, Float
    attribute :memorysize, Float
    attribute :diskspace, Integer
    attribute :blockdevices, String
    attribute :processorcount, Integer
    attribute :uptime_seconds, Integer
    attribute :is_virtual, Boolean
    attribute :serialnumber, String
    attribute :drac_name, String
    attribute :drac_domain, String
    attribute :drac_ipaddress, String
    attribute :drac_netmask, String
    attribute :drac_macaddress, String
    attribute :idb_unattended_upgrades, Boolean
    attribute :idb_unattended_upgrades_blacklisted_packages, Array
    attribute :idb_unattended_upgrades_reboot, Boolean
    attribute :idb_unattended_upgrades_time, String
    attribute :idb_unattended_upgrades_repos, Array
    attribute :idb_pending_updates, Integer
    attribute :idb_pending_security_updates, Integer
    attribute :idb_pending_updates_sum, Integer
    attribute :idb_pending_updates_package_names, Array
    attribute :idb_reboot_required, Boolean
    attribute :idb_installed_packages, JSON

    attr_reader :interfaces

    def initialize(attributes = {})
      # Call super to initialize all attributes.
      super

      # If we cannot find facts for a machine, it is probably not managed
      # by Puppet.
      @missing = !!attributes.empty?

      @interfaces = {}

      attributes = HashWithIndifferentAccess.new(attributes)

      attributes[:interfaces].to_s.split(',').each do |interface|
        nic = build_nic(interface.downcase, attributes)

        if nic
          @interfaces[nic.name] = nic
        end
      end

      build_drac(@interfaces)
      windows_fixes
    end

    def missing?
      !!@missing
    end

    def virtual_machine?
      is_virtual
    end

    def unattended_upgrades?
      idb_unattended_upgrades
    end

    def pending_updates?
    end

    def serialnumber
      super =~ /not specified|system serial number/i ? nil : super
    end

    def memorysize_mb
      if @memorysize_mb
        @memorysize_mb
      elsif @memorysize
        if @memorysize.end_with?("GB")
          (@memorysize.to_f*1024).to_i
        end
      end
    end

    private

    def build_nic(name, attributes)
      # We don't need local loopback interfaces.
      return if name == 'lo'

      Nic.new(name: name).tap do |nic|
        # XXX Revisit: Windows seems to only set "macaddress".
        nic.mac = attributes["macaddress_#{name}"] || attributes['macaddress']
        nic.mac = nic.mac.downcase if nic.mac
        nic.ip_address = IpAddress.new
        nic.ip_address.addr = attributes["ipaddress_#{name}"]
        nic.ip_address.addr_v6 = attributes["ipaddress6_#{name}"]
        nic.ip_address.netmask = attributes["netmask_#{name}"]
        # XXX Hardcoded for now! Not sure how facter displays ipv6 addresses.
        nic.ip_address.family = 'inet'
      end
    end

    def build_drac(interfaces)
      if drac_name && drac_ipaddress && drac_macaddress
        Nic.new(name: 'idrac').tap do |nic|
          nic.mac = drac_macaddress
          nic.ip_address = IpAddress.new
          nic.ip_address.addr = drac_ipaddress
          nic.ip_address.netmask = drac_netmask
          nic.ip_address.family = 'inet'

          interfaces[nic.name] = nic
        end
      end
    end

    def windows_fixes
      return unless operatingsystem =~ /windows/i

      if WINDOWS_VERSIONS.has_key?(operatingsystemrelease)
        self.operatingsystemrelease = WINDOWS_VERSIONS[operatingsystemrelease]
      end
    end
  end
end
