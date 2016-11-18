require 'spec_helper'

describe MachineUpdateService do
  describe '.update_from_facts' do
    let(:facts) do
      Puppetdb::Facts.new(
        interfaces: 'eth0,eth1,eth2,lo',
        ipaddress_eth0: '172.20.10.7',
        ipaddress6_eth0: '172.20.10.7v6',
        ipaddress_eth1: '10.0.0.1',
        ipaddress_lo: '127.0.0.1',
        macaddress_eth0: '6a:a8:6d:e0:a2:a6',
        macaddress_eth1: '3c:97:0e:40:06:be',
        macaddress_eth2: '3c:97:0e:40:06:b1',
        netmask_eth0: '255.255.255.240',
        netmask_eth1: '255.255.255.0',
        netmask_lo: '255.0.0.0',
        is_virtual: false,
        serialnumber: '42Q6F5J',
        memorysize_mb: '12018.26',
        blockdevices: 'hda,sda',
        blockdevice_hda_size: 2000000,
        blockdevice_sda_size: 1000000
      )
    end

    let(:machine) do
      Machine.create!(fqdn: 'test.example.com')
    end

    before do
      allow(Puppetdb::FactsV3).to receive(:for).and_return(facts)
      allow(Puppetdb::FactsV3).to receive(:raw_data).and_return(facts.to_s)
      allow(Puppetdb::FactsV4).to receive(:for).and_return(facts)
      allow(Puppetdb::FactsV4).to receive(:raw_data).and_return(facts.to_s)
      @url = "https://puppetdb.example.com"
    end

    it 'sets the device type' do
      described_class.update_from_facts(machine,  @url)

      expect(machine.device_type_id).to_not be_nil
    end

    it 'sets the serialnumber' do
      described_class.update_from_facts(machine,  @url)

      expect(machine.serialnumber).to eq('42Q6F5J')
    end
    
    it 'sets the RAM' do
      described_class.update_from_facts(machine, @url)

      expect(machine.ram).to eq(12018)
    end

    it 'sets the auto_update flag to true' do
      described_class.update_from_facts(machine, @url)

      expect(machine.auto_update).to eq(true)
    end

    context 'when no fact can be found' do
      before { allow(facts).to receive(:missing?).and_return(true) }

      it 'does not set auto_update to true' do
        described_class.update_from_facts(machine, @url)

        expect(machine.auto_update).to eq(false)
      end
    end

    describe 'interfaces' do
      context 'without existing interfaces' do
        before do
          described_class.update_from_facts(machine, @url)
        end

        it 'skips interfaces without an ip address' do
          nic = machine.nics.find {|n| n.name == 'eth2' }

          expect(nic).to be_nil
        end

        describe 'eth0 interface' do
          let(:nic) { machine.nics.find {|n| n.name == 'eth0' } }

          it 'sets the mac address' do
            expect(nic.mac).to eq('6a:a8:6d:e0:a2:a6')
          end

          it 'sets the ip address' do
            expect(nic.ip_address.addr).to eq('172.20.10.7')
          end

          it 'sets the netmask' do
            expect(nic.ip_address.netmask).to eq('255.255.255.240')
          end
        end

        describe 'eth1 interface' do
          let(:nic) { machine.nics.find {|n| n.name == 'eth1' } }

          it 'sets the mac address' do
            expect(nic.mac).to eq('3c:97:0e:40:06:be')
          end

          it 'sets the ip address' do
            expect(nic.ip_address.addr).to eq('10.0.0.1')
          end

          it 'sets the netmask' do
            expect(nic.ip_address.netmask).to eq('255.255.255.0')
          end
        end
      end

      context 'with existing nic objects' do
        before do
          nic = Nic.new(name: 'eth0', mac: 'aa:aa:aa:aa:aa:aa')
          nic.ip_address = IpAddress.new(addr: '1.1.1.1', netmask: '0.0.0.0', family: 'a')

          nic2 = Nic.new(name: 'eth9', mac: 'bb:aa:aa:aa:aa:aa')
          nic2.ip_address = IpAddress.new(addr: '10.1.1.1', netmask: '0.0.0.0', family: 'a')

          nic3 = Nic.new(name: 'eth2', mac: 'cc:aa:aa:aa:aa:aa')
          nic3.ip_address = IpAddress.new

          machine.nics << nic
          machine.nics << nic2
          machine.nics << nic3

          described_class.update_from_facts(machine, @url)
        end

        it 'removes non-existant nics' do
          nic = machine.nics.where(name: 'eth9').first

          expect(nic).to be_nil
          expect(Nic.exists?(name: 'eth9')).to eq(false)
        end

        it 'removes interfaces without ip address' do
          nic = machine.nics.where(name: 'eth2').first

          expect(nic).to be_nil
        end

        describe 'eth0 interface' do
          let(:nic) { machine.nics.find {|n| n.name == 'eth0' } }

          it 'sets the mac address' do
            expect(nic.mac).to eq('6a:a8:6d:e0:a2:a6')
          end

          it 'sets the ip address' do
            expect(nic.ip_address.addr).to eq('172.20.10.7')
          end

          it 'sets the ipv6 address' do
            expect(nic.ip_address.addr_v6).to eq('172.20.10.7v6')
          end

          it 'sets the netmask' do
            expect(nic.ip_address.netmask).to eq('255.255.255.240')
          end

          it 'sets the family' do
            expect(nic.ip_address.family).to eq('inet')
          end
        end
      end
    end
  end

  describe '.update_from_alternative_facts' do
    let(:facts2) do
      Puppetdb::Facts.new(
        serialnumber: '42Q6F5J',
        memorysize: '23.60 GB'
      )
    end

    let(:machine) do
      Machine.create!(fqdn: 'test.example.com')
    end

    before do
      allow(Puppetdb::FactsV3).to receive(:for).and_return(facts2)
      allow(Puppetdb::FactsV3).to receive(:raw_data).and_return(facts2.to_s)
      allow(Puppetdb::FactsV4).to receive(:for).and_return(facts2)
      allow(Puppetdb::FactsV4).to receive(:raw_data).and_return(facts2.to_s)
      @url = "https://puppetdb.example.com"
    end

    it 'sets the serialnumber' do
      described_class.update_from_facts(machine, @url)

      expect(machine.serialnumber).to eq('42Q6F5J')
    end

    it 'sets the RAM if memorysize_mb is not defined' do
      described_class.update_from_facts(machine, @url)

      expect(machine.ram).to eq(24166)
    end
  end
end