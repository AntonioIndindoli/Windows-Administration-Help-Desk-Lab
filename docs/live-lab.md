# Using the deployed lab

The five VirtualBox VMs are registered on this computer. Open VirtualBox Manager, select a running VM and choose **Show** to use its console. The disks remain in the workspace's `VMs` directory. VM disks, installation media, credentials, and backups are local files excluded from Git. Configuration details below describe the recorded deployment; check the guests for their current state.

| VM | Role | Address | Current memory |
|---|---|---|---|
| DC01 | Windows Server 2025; AD DS, DNS, DHCP | 10.77.0.10 | 4 GB |
| FS01 | Windows Server 2025; department SMB shares | 10.77.0.20 | 2 GB |
| HD01 | Ubuntu; osTicket, Apache, MariaDB, isolated NAT router | 10.77.0.30; gateway alias .1 | 2 GB |
| PC01 | Windows 11 Enterprise Evaluation; domain workstation | DHCP 10.77.0.100 | 4 GB |
| PC02 | Windows 11 Enterprise Evaluation; domain workstation | DHCP 10.77.0.101 | 4 GB |

Domain: `corp.example.test`, NetBIOS `CORP`. Both clients and FS01 are joined in their intended OUs. All Windows guests use DC01 for DNS. DHCP stays on VirtualBox internal network `HelpDeskLab`. HD01 has the only NAT adapter; host forwards bind to loopback only. The physical host's VBS/security settings remain enabled.

## Sign-in and support portal

- Test users sign in as `CORP\it04`, `CORP\hr04`, etc. All 30 current test credentials are in the ACL-restricted host file `LabSecrets\working-users.csv`. These are lab credentials; keep this file private.
- Domain administrator: `CORP\Administrator`; its password is in `LabSecrets\DC01.password`. Individual VM password files are local administrator credentials. Do not put test users into administrative groups.
- From a lab client: `https://helpdesk.corp.example.test/`. PC01 and PC02 trust the lab CA and passed HTTPS certificate validation.
- From this host: `https://127.0.0.1:8443/`; staff panel `/scp/`. The host trust store was not changed. The public CA certificate is `data\lab-ca.crt`; use a trusted lab client if the host browser does not trust it.
- osTicket staff username is `lab.supervisor`; the independent generated password is in restricted `LabSecrets\osticket.json`.
- HD01 SSH uses the restricted private key `LabSecrets\hd01_ed25519` and loopback port 2222. Password SSH is disabled.

Each department has six users, a global membership group, and a domain-local resource group. Own-department SMB access allows modification; other departments are denied. Public permits reading only. `Lab-User-Experience` maps P: to Public and H: to the user's department through group targeting. The interactive it04 session verified both mappings. The three lab GPO reports are in `evidence`; the previously exported GPO backup directory is no longer present.

## Start, stop and restore

Start DC01 and HD01 first, then FS01 and the clients. Wait for domain services before signing in. Shut clients and FS01 down before DC01 and HD01. Use normal guest shutdowns. VirtualBox's NEM backend is slow on this host; several guest setup/restart operations stalled and required a VM reset. Do not infer guest readiness from a registered VM or a stale screenshot; verify guest services and the secure channel.

The completed osTicket SQL/application backups are in root-only HD01 storage and `LabSecrets\Backups` on this host. Their independent hashes match. SQL was restored into a separate database and the application configuration was extracted and compared. See `osticket-completed-restore.txt` and the hash records.

If `evidence\lab-checkpoints.json` exists, its entries identify a coordinated five-VM recovery set. Restore all members of that set together while the VMs are stopped; avoid restoring an older DC by itself into a continuing domain. Protect VM files and snapshots because disks and memory contain operating-system secrets. Recovery checkpoints are not a substitute for independent backups.

## Repeat the exercises manually

Use [build-guide.md](build-guide.md) for a new installation and [tickets-and-kb.md](tickets-and-kb.md) for practice scenarios. Work in the VM consoles and management tools. Run one fault at a time, preserve local console access, and restore the precise injected change. Enter your own observations and resolutions in osTicket.

The retained [validation report](../evidence/validation.md) records the earlier automated run. T09 reproduced stale cache-only negative DNS results, not a persistent failure in ordinary application lookups. T10 used nslookup to test suffix search. Record what you observe when repeating either exercise.

## Local files and host notes

The host's Windows hypervisor backend is active; VirtualBox uses its slower NEM backend. The original deployment retained Virtual Machine Platform, WSL, and virtualization-based security. HD01 used three virtual CPUs and the Hyper-V paravirtualization provider; Windows guests used four virtual CPUs after earlier setup stalls.

Build scripts, staging copies, download fragments, temporary tooling, and the exported build ZIP have been removed. Complete installation media remains available locally. Some private unattended-install files and the HD01 seed ISO remain because the VirtualBox configurations still reference them. Keep these with the local VM/recovery files; they are not part of the published project. No scripts or services inside the guest disks were changed during the repository cleanup.
