# to be able to configure the hyper-v vm.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

# NB execute apt-cache madison gitlab-ce to list the available versions.
# see https://gitlab.com/gitlab-org/gitlab-foss/-/tags
# renovate: datasource=gitlab-tags depName=gitlab-org/gitlab-foss
gitlab_version = '16.9.2'
GITLAB_VERSION = "#{gitlab_version}-ce.0"
GITLAB_IP = '10.10.9.99'
DISK_SIZE_GB = 32

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu-22.04-amd64"

  config.vm.hostname = "gitlab.example.com"

  config.vm.network "private_network", ip: GITLAB_IP, libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false, hyperv__bridge: 'gitlab'

  config.vm.provider 'libvirt' do |lv, config|
    lv.memory = 4*1024
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    lv.keymap = 'pt'
    lv.machine_virtual_size = DISK_SIZE_GB
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.provider 'hyperv' do |hv, config|
    hv.linked_clone = true
    hv.memory = 4*1024
    hv.cpus = 4
    hv.enable_virtualization_extensions = false # nested virtualization.
    hv.vlan_id = ENV['HYPERV_VLAN_ID']
    # see https://github.com/hashicorp/vagrant/issues/7915
    # see https://github.com/hashicorp/vagrant/blob/10faa599e7c10541f8b7acf2f8a23727d4d44b6e/plugins/providers/hyperv/action/configure.rb#L21-L35
    config.vm.network :private_network, bridge: ENV['HYPERV_SWITCH_NAME'] if ENV['HYPERV_SWITCH_NAME']
    config.vm.synced_folder '.', '/vagrant',
      type: 'smb',
      smb_username: ENV['VAGRANT_SMB_USERNAME'] || ENV['USER'],
      smb_password: ENV['VAGRANT_SMB_PASSWORD']
    # further configure the VM (e.g. manage the network adapters).
    config.trigger.before :'VagrantPlugins::HyperV::Action::StartInstance', type: :action do |trigger|
      trigger.ruby do |env, machine|
        # see https://github.com/hashicorp/vagrant/blob/v2.2.10/lib/vagrant/machine.rb#L13
        # see https://github.com/hashicorp/vagrant/blob/v2.2.10/plugins/kernel_v2/config/vm.rb#L716
        bridges = machine.config.vm.networks.select{|type, options| type == :private_network && options.key?(:hyperv__bridge)}.map do |type, options|
          mac_address_spoofing = false
          mac_address_spoofing = options[:hyperv__mac_address_spoofing] if options.key?(:hyperv__mac_address_spoofing)
          [options[:hyperv__bridge], mac_address_spoofing]
        end
        system(
          'pwsh',
          '-NoLogo',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'configure-hyperv-vm.ps1',
          machine.id,
          bridges.to_json
        ) or raise "failed to configure hyper-v vm with exit code #{$?.exitstatus}"
      end
    end
  end

  config.trigger.before :up do |trigger|
    ldap_ca_cert_path = '../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der'
    trigger.run = {inline: "sh -c 'mkdir -p tmp && cp #{ldap_ca_cert_path} tmp'"} if File.file? ldap_ca_cert_path
  end

  config.vm.provision "shell", inline: "apt-get update"
  config.vm.provision "shell", path: "provision-resize-disk.sh"
  config.vm.provision "shell", path: "configure-hyperv-guest.sh", args: [GITLAB_IP]
  config.vm.provision "shell", path: "provision-dns-server.sh", args: [GITLAB_IP]
  config.vm.provision "shell", path: "provision-mailpit.sh"
  config.vm.provision "shell", path: "provision.sh", args: [GITLAB_VERSION]
  config.vm.provision "shell", path: "provision-gitlab-source-link-proxy.sh"
  config.vm.provision "shell", path: "provision-gitlab-cli.sh"
  config.vm.provision "shell", path: "provision-examples.sh"
  config.vm.provision "shell", path: "summary.sh"
end
