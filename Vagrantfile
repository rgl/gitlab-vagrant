gitlab_version = '12.8.5-ce.0' # NB execute apt-cache madison gitlab-ce to known the available versions.

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu-18.04-amd64"

  config.vm.hostname = "gitlab.example.com"

  config.vm.network "private_network", ip: "10.10.9.99", libvirt__forward_mode: "route", libvirt__dhcp_enabled: false

  config.vm.provider 'libvirt' do |lv, config|
    lv.memory = 4*1024
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs'
  end

  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = 4*1024
    vb.cpus = 4
  end

  config.trigger.before :up do |trigger|
    ldap_ca_cert_path = '../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der'
    trigger.run = {inline: "sh -c 'mkdir -p tmp && cp #{ldap_ca_cert_path} tmp'"} if File.file? ldap_ca_cert_path
  end

  config.vm.provision "shell", path: "provision-mailhog.sh"
  config.vm.provision "shell", path: "provision.sh", args: [gitlab_version]
  config.vm.provision "shell", path: "provision-gitlab-source-link-proxy.sh"
  config.vm.provision "shell", path: "provision-gitlab-cli.sh"
  config.vm.provision "shell", path: "provision-examples.sh"
  config.vm.provision "shell", path: "summary.sh"
end
