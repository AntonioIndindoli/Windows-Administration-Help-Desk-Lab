"""Create HD01's NoCloud seed from its VM NIC identities and a local SSH public key."""
import io
import json
import pathlib
import sys
root = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / '.tools'))
import pycdlib

facts = json.loads((root / 'data' / 'hd01-nics.json').read_text(encoding='utf-8-sig'))
key = (root / 'LabSecrets' / 'hd01_ed25519.pub').read_text().strip()
user_data = f'''#cloud-config
hostname: hd01
fqdn: hd01.corp.example.test
manage_etc_hosts: true
timezone: America/Los_Angeles
users:
  - name: labadmin
    groups: [sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - {key}
ssh_pwauth: false
disable_root: true
package_update: true
packages:
  - apache2
  - mariadb-server
  - php
  - php-mysql
  - php-imap
  - php-mbstring
  - php-intl
  - php-xml
  - php-gd
  - php-curl
  - php-zip
  - php-apcu
  - unzip
  - curl
  - iptables
write_files:
  - path: /etc/sysctl.d/90-helpdesk-lab.conf
    content: |
      net.ipv4.ip_forward=1
  - path: /usr/local/sbin/lab-router
    permissions: '0755'
    content: |
      #!/bin/sh
      sysctl -w net.ipv4.ip_forward=1
      iptables -t nat -C POSTROUTING -s 10.77.0.0/24 -o nat0 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.77.0.0/24 -o nat0 -j MASQUERADE
      iptables -C FORWARD -i lab0 -o nat0 -s 10.77.0.0/24 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i lab0 -o nat0 -s 10.77.0.0/24 -j ACCEPT
      iptables -C FORWARD -i nat0 -o lab0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -A FORWARD -i nat0 -o lab0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  - path: /etc/systemd/system/lab-router.service
    content: |
      [Unit]
      Description=Isolated help desk lab outbound NAT
      Wants=network-online.target
      After=network-online.target
      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/lab-router
      RemainAfterExit=yes
      [Install]
      WantedBy=multi-user.target
runcmd:
  - [systemctl, daemon-reload]
  - [systemctl, enable, --now, lab-router.service]
  - [sh, -c, 'mkdir -p /var/lib/helpdesk-lab; date -Is > /var/lib/helpdesk-lab/cloud-ready']
'''
network = f'''version: 2
ethernets:
  lab0:
    match:
      macaddress: "{facts['lab']}"
    set-name: lab0
    dhcp4: false
    addresses: [10.77.0.30/24, 10.77.0.1/24]
  nat0:
    match:
      macaddress: "{facts['nat']}"
    set-name: nat0
    dhcp4: true
'''
iso = pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=3, vol_ident='cidata', rock_ridge='1.09')
for name, text in [('user-data', user_data), ('meta-data', 'instance-id: helpdesk-hd01-v1\nlocal-hostname: hd01\n'), ('network-config', network)]:
    data = text.encode()
    iso.add_fp(io.BytesIO(data), len(data), iso_path='/' + name.upper().replace('-', '_') + ';1', rr_name=name, joliet_path='/' + name)
iso.write(str(root / 'media' / 'HD01-seed.iso'))
iso.close()
print('HD01 cloud-init seed prepared; no password authentication enabled.')
