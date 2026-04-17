se for no Windows com WSL

cesguto@CALNETWIN:/mnt/c/Projetos/rke2-ha-proxmox/tmp$ sudo LIBGUESTFS_BACKEND=direct virt-customize -a noble-server-cloudimg-amd64.img \
  --upload ./liburing2_2.5-1build1_amd64.deb:/tmp/liburing.deb \
  --upload ./qemu-guest-agent_1%3a8.2.2+ds-0ubuntu1.16_amd64.deb:/tmp/qga.deb \
  --run-command "dpkg -i /tmp/liburing.deb /tmp/qga.deb" \
  --run-command "systemctl enable qemu-guest-agent" \
  --run-command "rm /tmp/liburing.deb /tmp/qga.deb"
[   0.0] Examining the guest ...
[  15.7] Setting a random seed
virt-customize: warning: random seed could not be set for this type of
guest
[  15.7] Uploading: ./liburing2_2.5-1build1_amd64.deb to /tmp/liburing.deb
[  15.8] Uploading: ./qemu-guest-agent_1%3a8.2.2+ds-0ubuntu1.16_amd64.deb to /tmp/qga.deb
[  15.8] Running: dpkg -i /tmp/liburing.deb /tmp/qga.deb
[  41.6] Running: systemctl enable qemu-guest-agent
[  41.7] Running: rm /tmp/liburing.deb /tmp/qga.deb
[  41.7] SELinux relabelling
[  23.3] Finishing off


APOS INICIAR O QMEU-GUEST-AGENT
sudo LIBGUESTFS_BACKEND=direct virt-customize -a noble-server-cloudimg-amd64.img \
  --run-command "systemctl enable qemu-guest-agent.service" \
  --run-command "ln -sf /lib/systemd/system/qemu-guest-agent.service /etc/systemd/system/multi-user.target.wants/qemu-guest-agent.service"


PRECISO COPIAR O make-template.sh para o PROXMOX

DENTRO DO SHELL DO PROXMOX
root@pve:/tmp# ./make-template.sh -i 110 -n rke2-template -I /tmp/noble-server-cloudimg-amd64.img -s local-lvm
