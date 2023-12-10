Vagrant.configure("2") do |config|
  config.vm.define "windows" do |windows|
    windows.vm.box = "gusztavvargadr/windows-10"
    windows.vm.communicator = "winssh"
    windows.vm.synced_folder ".", "/Users/vagrant/scoop/apps/scoop/current"
  end
  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box = "gusztavvargadr/ubuntu-desktop"
    ubuntu.vm.synced_folder ".", "/home/vagrant/scoop/apps/scoop/current"
  end
end
