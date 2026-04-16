#cloud-config
hostname: ${name}
ssh_pwauth: true
users:
  - name: ${username}
    lock_passwd: false
    passwd: ${password_hash}
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${ssh_key}

# Pacotes úteis (opcional)
packages:
  - qemu-guest-agent
  - haproxy
  - keepalived

runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
  # Se quiser, posso gerar aqui configs de haproxy/keepalived com o VIP 192.168.0.219