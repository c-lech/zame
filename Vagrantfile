# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.define "zabbix" do |zabbix|

    # Configure VM
    
    zabbix.vm.box = "centos/8"
    #zabbix.vm.box = "almalinux/8"
    zabbix.vm.hostname = "zabbix"

    # Configure Networking

    zabbix.vm.network "forwarded_port", guest: 80 , host: 80
    zabbix.vm.network "forwarded_port", guest: 8080 , host: 8080
    zabbix.vm.network "forwarded_port", guest: 3000 , host: 3000
    zabbix.vm.network "forwarded_port", guest: 9090 , host: 9090
    zabbix.vm.network "forwarded_port", guest: 3306 , host: 3306
    zabbix.vm.network "forwarded_port", guest: 5432 , host: 5432
    zabbix.vm.network "forwarded_port", guest: 10050 , host: 10050
    zabbix.vm.network "forwarded_port", guest: 10051 , host: 10051
    zabbix.vm.network "forwarded_port", guest: 10052 , host: 10052

    # Configure Provisioning 
   
    zabbix.vm.provision "shell", path: "bootstrap.sh", args: "apache mysql"
    zabbix.vm.synced_folder "./", "/vagrant"
    zabbix.vm.provider "virtualbox" do |vb|
      vb.cpus = 1
      vb.memory = 4096
      vb.gui = false
      vb.name = "zabbix"
    end

  end

end
