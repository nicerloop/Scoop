windows:
    vagrant up
    vagrant snapshot restore initial-snapshot || vagrant snapshot create initial-snapshot
    vagrant provision
    vagrant ssh

ubuntu:
    multipass start scoop || multipass launch --name scoop --mount .:/home/ubuntu/scoop/apps/scoop/current --cloud-init ./cloud-config.yaml 22.04
    multipass shell scoop

down:
    -vagrant destroy -f
    -multipass delete scoop
    -multipass purge
