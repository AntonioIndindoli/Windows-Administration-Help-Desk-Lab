# Using the deployed lab

The five VirtualBox VMs are registered on this computer. Open VirtualBox Manager, select a running VM and choose **Show** to use its console. The disks remain in the workspace's `VMs` directory. The build ZIP contains scripts, configuration data, guides and evidence; VM disks, installation media and credentials are separate.

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

Each department has six users, a global membership group, and a domain-local resource group. Own-department SMB access allows modification; other departments are denied. Public permits reading only. `Lab-User-Experience` maps P: to Public and H: to the user's department through group targeting. The interactive it04 session verified both mappings. The three lab GPOs and their backups are in `evidence`.

## Start, stop and restore

Start DC01 and HD01 first, then FS01 and the clients. Wait for domain services before signing in. Shut clients and FS01 down before DC01 and HD01. Use normal guest shutdowns. VirtualBox's NEM backend is slow on this host; several guest setup/restart operations stalled and required a VM reset. Do not infer guest readiness from a registered VM or a stale screenshot; verify guest services and the secure channel.

The completed osTicket SQL/application backups are in root-only HD01 storage and `LabSecrets\Backups` on this host. Their independent hashes match. SQL was restored into a separate database and the application configuration was extracted and compared. See `osticket-completed-restore.txt` and the hash records.

If `evidence\lab-checkpoints.json` exists, its entries identify a coordinated five-VM recovery set. Restore all members of that set together while the VMs are stopped; avoid restoring an older DC by itself into a continuing domain. Protect VM files and snapshots because disks and memory contain operating-system secrets. Recovery checkpoints are not a substitute for independent backups.

## Reproduce and revalidate

Use `build-guide.md` for a fresh installation, `08-InstallWindowsGuests.ps1` for unattended Windows setup, and the numbered domain/share/policy scripts for the specified guests. Scripts that deliberately create new resources can refuse to rerun on existing resources; review the state before retrying. The provisioning script skips existing accounts without resetting their passwords.

`Invoke-LabGuest.ps1` is the host console channel. It requires VirtualBox, Guest Additions, and the restricted VM credential files. It works during guest network faults when local credentials are used. Domain authentication may wait for a disconnected DC, so use local Administrator for isolated-network exercises.

Live test scripts 13–19 reproduce authentication, DNS, connectivity and permission cases. Script 20 creates the remaining account and user-experience GPOs. Stage scripts inside the named guest before running them. Run one network fault at a time, preserve local console access, and restore the precise injected change. Script 18 keeps a real ordinary-user token alive while its group membership changes.

T09 has a measured limitation: ordinary application DNS lookups refreshed automatically on this Windows build. A stale **cache-only** negative lookup was reproduced and repaired, and the public FAQ states that scope. T10 uses nslookup's suffix-search behavior; an early Resolve-DnsName short-name probe was unsuitable and is retained in the diagnostic history. No failed attempt counts as a successful check.

`prepare_verified_results.py` accepts only observed successful records. `finalize-osticket.php` closes tickets and publishes FAQs only from those records. `evidence\validation.md` is the final acceptance register, with the raw observations linked. Secrets are excluded from the build ZIP.
