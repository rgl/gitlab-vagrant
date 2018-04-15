# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-16.04"
  
  config.vm.hostname = "gitlab.example.com"

  config.vm.network "private_network", ip: "192.168.33.20"

  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    #vb.gui = true
    vb.memory = "2048"
  end

  config.trigger.before :up do
    ldap_ca_cert_path = '../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der'
    run "sh -c 'mkdir -p tmp && cp #{ldap_ca_cert_path} tmp'" if File.file? ldap_ca_cert_path
  end

  config.vm.provision "shell", path: "provision.sh"
end
