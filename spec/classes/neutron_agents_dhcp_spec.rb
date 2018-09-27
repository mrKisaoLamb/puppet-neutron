require 'spec_helper'

describe 'neutron::agents::dhcp' do

  let :pre_condition do
    "class { 'neutron': }"
  end

  let :params do
    {}
  end

  let :default_params do
    { :package_ensure           => 'present',
      :enabled                  => true,
      :state_path               => '/var/lib/neutron',
      :resync_interval          => 30,
      :interface_driver         => 'neutron.agent.linux.interface.OVSInterfaceDriver',
      :root_helper              => 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf',
      :enable_isolated_metadata => false,
      :enable_metadata_network  => false,
      :purge_config             => false }
  end

  let :test_facts do
    { :operatingsystem           => 'default',
      :operatingsystemrelease    => 'default'
    }
  end

  shared_examples_for 'neutron dhcp agent' do
    let :p do
      default_params.merge(params)
    end

    it { is_expected.to contain_class('neutron::params') }

    it 'configures dhcp_agent.ini' do
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/debug').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/state_path').with_value(p[:state_path]);
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/resync_interval').with_value(p[:resync_interval]);
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/interface_driver').with_value(p[:interface_driver]);
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/dhcp_driver').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/root_helper').with_value(p[:root_helper]);
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_isolated_metadata').with_value(p[:enable_isolated_metadata]);
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/force_metadata').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_metadata_network').with_value(p[:enable_metadata_network]);
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/dhcp_broadcast_reply').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/ovs_integration_bridge').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/dnsmasq_local_resolv').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('AGENT/availability_zone').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('OVS/ovsdb_connection').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('OVS/ssl_key_file').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('OVS/ssl_cert_file').with_value('<SERVICE DEFAULT>');
      is_expected.to contain_neutron_dhcp_agent_config('OVS/ssl_ca_cert_file').with_value('<SERVICE DEFAULT>');
    end

    it 'installs neutron dhcp agent package' do
      if platform_params.has_key?(:dhcp_agent_package)
        is_expected.to contain_package('neutron-dhcp-agent').with(
          :name   => platform_params[:dhcp_agent_package],
          :ensure => p[:package_ensure],
          :tag    => ['openstack', 'neutron-package'],
        )
        is_expected.to contain_package('neutron').that_requires('Anchor[neutron::install::begin]')
        is_expected.to contain_package('neutron').that_notifies('Anchor[neutron::install::end]')
        is_expected.to contain_package('neutron-dhcp-agent').that_requires('Anchor[neutron::install::begin]')
        is_expected.to contain_package('neutron-dhcp-agent').that_notifies('Anchor[neutron::install::end]')
      else
        is_expected.to contain_package('neutron').that_requires('Anchor[neutron::install::begin]')
        is_expected.to contain_package('neutron').that_notifies('Anchor[neutron::install::end]')
      end
    end

    it 'configures neutron dhcp agent service' do
      is_expected.to contain_service('neutron-dhcp-service').with(
        :name    => platform_params[:dhcp_agent_service],
        :enable  => true,
        :ensure  => 'running',
        :tag     => 'neutron-service',
      )
      is_expected.to contain_service('neutron-dhcp-service').that_subscribes_to('Anchor[neutron::service::begin]')
      is_expected.to contain_service('neutron-dhcp-service').that_notifies('Anchor[neutron::service::end]')
    end

    it 'passes purge to resource' do
      is_expected.to contain_resources('neutron_dhcp_agent_config').with({
        :purge => false
      })
    end

    context 'with manage_service as false' do
      before :each do
        params.merge!(:manage_service => false)
      end
      it 'should not start/stop service' do
        is_expected.to contain_service('neutron-dhcp-service').without_ensure
      end
    end

    context 'when enabling isolated metadata only' do
      before :each do
        params.merge!(:enable_isolated_metadata => true, :enable_metadata_network => false)
      end
      it 'should enable isolated_metadata only' do
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_isolated_metadata').with_value('true');
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_metadata_network').with_value('false');
      end
    end

    context 'when enabling isolated metadata with metadata networks' do
      before :each do
        params.merge!(:enable_isolated_metadata => true, :enable_metadata_network => true)
      end
      it 'should enable both isolated_metadata and metadata_network' do
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_isolated_metadata').with_value('true');
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_metadata_network').with_value('true');
      end
    end

    context 'when enabling metadata networks without enabling isolated metadata or force metadata' do
      before :each do
        params.merge!(:enable_isolated_metadata => false, :enable_force_metadata => false, :enable_metadata_network => true)
      end

      it_raises 'a Puppet::Error', /enable_metadata_network to true requires enable_isolated_metadata or enable_force_metadata also enabled./
    end

    context 'when enabling force metadata only' do
      before :each do
        params.merge!(:enable_force_metadata => true, :enable_metadata_network => false)
      end
      it 'should enable force_metadata only' do
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/force_metadata').with_value('true');
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_metadata_network').with_value('false');
      end
    end

    context 'when enabling force metadata with metadata networks' do
      before :each do
        params.merge!(:enable_force_metadata => true, :enable_metadata_network => true)
      end
      it 'should enable both force_metadata and metadata_network' do
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/force_metadata').with_value('true');
        is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/enable_metadata_network').with_value('true');
      end
    end

    context 'when availability zone is set' do
      before :each do
        params.merge!(:availability_zone => 'zone1')
      end
      it 'should configure availability zone' do
        is_expected.to contain_neutron_dhcp_agent_config('AGENT/availability_zone').with_value(p[:availability_zone]);
      end
    end

    context 'with SSL configuration' do
      before do
        params.merge!({
          :ovsdb_connection          => 'ssl:127.0.0.1:6639',
          :ovsdb_agent_ssl_key_file  => '/tmp/dummy.pem',
          :ovsdb_agent_ssl_cert_file => '/tmp/dummy.crt',
          :ovsdb_agent_ssl_ca_file   => '/tmp/ca.crt'
        })
      end
      it 'configures neutron SSL settings' do
        is_expected.to contain_neutron_dhcp_agent_config('OVS/ovsdb_connection').with_value(params[:ovsdb_connection])
        is_expected.to contain_neutron_dhcp_agent_config('OVS/ssl_key_file').with_value(params[:ovsdb_agent_ssl_key_file])
        is_expected.to contain_neutron_dhcp_agent_config('OVS/ssl_cert_file').with_value(params[:ovsdb_agent_ssl_cert_file])
        is_expected.to contain_neutron_dhcp_agent_config('OVS/ssl_ca_cert_file').with_value(params[:ovsdb_agent_ssl_ca_file])
      end
    end

    context 'with SSL enabled, but missing file config' do
      before do
        params.merge!({
          :ovsdb_connection => 'ssl:127.0.0.1:6639'
        })
      end
      it 'fails to configure' do
        is_expected.to raise_error(Puppet::Error)
      end
    end
  end

  shared_examples_for 'neutron dhcp agent with dnsmasq_config_file specified' do
    before do
      params.merge!(
        :dnsmasq_config_file => '/foo'
      )
    end
    it 'configures dnsmasq_config_file' do
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/dnsmasq_config_file').with_value(params[:dnsmasq_config_file])
    end
  end

  shared_examples_for 'enable advertisement of the DNS resolver on the host.' do
    before do
      params.merge!(
        :dnsmasq_local_resolv => true
      )
    end
    it 'configures dnsmasq_local_resolv' do
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/dnsmasq_local_resolv').with_value(params[:dnsmasq_config_file])
    end
  end

  shared_examples_for 'neutron dhcp agent with dnsmasq_dns_servers set' do
    before do
      params.merge!(
        :dnsmasq_dns_servers => ['1.2.3.4','5.6.7.8']
      )
    end
    it 'should set dnsmasq_dns_servers' do
      is_expected.to contain_neutron_dhcp_agent_config('DEFAULT/dnsmasq_dns_servers').with_value(params[:dnsmasq_dns_servers].join(','))
    end
  end

  context 'on Debian platforms' do
    let :facts do
      @default_facts.merge(test_facts.merge({
         :osfamily => 'Debian',
         :os       => { :name  => 'Debian', :family => 'Debian', :release => { :major => '8', :minor => '0' } },
      }))
    end

    let :platform_params do
      { :dhcp_agent_package    => 'neutron-dhcp-agent',
        :dhcp_agent_service    => 'neutron-dhcp-agent' }
    end

    it_configures 'neutron dhcp agent'
    it_configures 'neutron dhcp agent with dnsmasq_config_file specified'
    it_configures 'neutron dhcp agent with dnsmasq_dns_servers set'
    it 'configures subscription to neutron-dhcp-agent package' do
      is_expected.to contain_service('neutron-dhcp-service').that_subscribes_to('Anchor[neutron::service::begin]')
    end
  end

  context 'on RedHat platforms' do
    let :facts do
      @default_facts.merge(test_facts.merge({
         :osfamily               => 'RedHat',
         :operatingsystemrelease => '7',
         :os       => { :name  => 'CentOS', :family => 'RedHat', :release => { :major => '7', :minor => '0' } },
      }))
    end

    let :platform_params do
      { :dhcp_agent_service    => 'neutron-dhcp-agent' }
    end

    it_configures 'neutron dhcp agent'
    it_configures 'neutron dhcp agent with dnsmasq_config_file specified'
    it_configures 'neutron dhcp agent with dnsmasq_dns_servers set'
  end
end
