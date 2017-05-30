require 'spec_helper'

describe Puppet::Type.type(:bgp_network).provider(:quagga) do
  describe 'instances' do
    it 'should have an instance method' do
      expect(described_class).to respond_to :instances
    end
  end

  describe 'methods' do
    it 'should have a prefetch method' do
      expect(described_class).to respond_to :prefetch
    end
  end

  context 'running-config' do
    before :each do
      described_class.expects(:vtysh).with(
        '-c', 'show running-config'
      ).returns '!
router bgp 197888
 bgp router-id 172.16.32.103
 no bgp default ipv4-unicast
 bgp graceful-restart stalepath-time 300
 bgp graceful-restart restart-time 300
 bgp network import-check
 network 172.16.32.0/24
 neighbor INTERNAL peer-group
 neighbor INTERNAL remote-as 197888
 neighbor INTERNAL allowas-in 1
 neighbor INTERNAL update-source 172.16.32.103
 neighbor INTERNAL activate
 neighbor INTERNAL next-hop-self
 neighbor INTERNAL soft-reconfiguration inbound
 neighbor RR peer-group
 neighbor RR remote-as 197888
 neighbor RR update-source 172.16.32.103
 neighbor RR activate
 neighbor RR next-hop-self
 neighbor RR_WEAK peer-group
 neighbor RR_WEAK remote-as 197888
 neighbor RR_WEAK update-source 172.16.32.103
 neighbor RR_WEAK activate
 neighbor RR_WEAK next-hop-self
 neighbor RR_WEAK route-map RR_WEAK_out out
 neighbor 172.16.32.108 peer-group INTERNAL
 neighbor 172.16.32.108 default-originate
 neighbor 172.16.32.108 shutdown
 maximum-paths 4
 maximum-paths ibgp 4
!
 address-family ipv6
 network 1::/64
 network 2::/64
 exit-address-family
 exit
!'
    end

    it 'should return a resource' do
      expect(described_class.instances.size).to eq(3)
    end

    it 'should return the 197888:INTERNAL resource' do
      expect(described_class.instances[0].instance_variable_get('@property_hash')).to eq({
          :ensure => :present,
          :name => '197888 172.16.32.0/24',
          :provider => :quagga,
      })
    end

    it 'should return the 197888:INTERNAL resource' do
      expect(described_class.instances[1].instance_variable_get('@property_hash')).to eq({
        :ensure => :present,
        :name => '197888 1::/64',
        :provider => :quagga,
      })
    end

    it 'should return the 197888:INTERNAL resource' do
      expect(described_class.instances[2].instance_variable_get('@property_hash')).to eq({
        :ensure => :present,
        :name => '197888 2::/64',
        :provider => :quagga,
      })
    end
  end
end