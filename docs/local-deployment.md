# This computer's deployment

See `evidence/validation.md` for current observed status; prepared scripts are not evidence of successful execution.

## Host and VM manager

Oracle VirtualBox 7.2.20 is installed on the Windows 11 Home host. VM configuration and dynamic disks live in this workspace's `VMs/` directory; the manager also registers these VMs in the current Windows user's VirtualBox configuration. Do not rename/move the workspace while VMs are running.

The host's Windows hypervisor backend is active. HD01 booted successfully with three vCPUs and the Hyper-V paravirtualization provider after default KVM and one-vCPU/no-provider configurations stalled. Windows guests stalled during setup with three vCPUs; retries use four vCPUs and 4 GiB RAM. Staged installation is required to limit host memory use. Virtual Machine Platform, WSL and virtualization-based security are active; host security features and boot configuration have not been disabled.

All guests have an internal NIC on `HelpDeskLab`. HD01 additionally has an outbound NAT NIC and routes the internal network through its alias `10.77.0.1`; its server address remains `10.77.0.30`. Windows guests should use `.1` as gateway, `.10` as DNS, and never the NAT adapter's resolver. DC01 and DHCP scripts accept `-Gateway 10.77.0.1`.

## HD01 management

- SSH: `127.0.0.1:2222`, user `labadmin`, SSH key in the restricted `LabSecrets/hd01_ed25519` file.
- HTTP: `http://127.0.0.1:8080/`.
- HTTPS: `https://127.0.0.1:8443/` once osTicket TLS setup completes.
- Within the lab: `helpdesk.corp.example.test`, `10.77.0.30` after the AD DNS record is created.

Host forwarding binds to loopback only. There are no public or LAN-facing management forwards. Private keys, initial guest passwords and unattended answer files remain excluded from Git under `LabSecrets/`; clean up generated answer files after successful installation.

## Download recovery

Official media is in `media/`. ISO `.parts` directories contain resumable 4 MiB downloads. Each accepted range is checked against its exact Content-Range header and expected length. `download_media.py` assembles media only after all ranges succeed; a `.sha256` sidecar records the resulting digest. That locally generated digest alone is not a publisher authenticity check. Ubuntu's disk was also matched to Canonical's published SHA-256 manifest; the verification result is saved under evidence.

The unused partial Ubuntu installer ISO was superseded by Canonical's verified, smaller cloud disk. It is not bootable installation media. Do not attach partial files to guests.

## Restore test

The `Ubuntu-Web-Ready` HD01 snapshot was taken while the guest was shut down, then successfully restored after creating a disposable marker. This is a local VM checkpoint, not an independent disaster-recovery backup. Test application/database backup separately after installing osTicket, and store independent backup copies outside the VM directory.
