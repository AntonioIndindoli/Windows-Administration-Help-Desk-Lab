# Windows Administration & Help Desk Lab

A reproducible practice lab using Windows Server 2025, Windows 11, Active Directory, DNS, DHCP, PowerShell, and osTicket.

**Status:** Partial deployment: VirtualBox 7.2.20 installed; five isolated VMs created. HD01 runs Ubuntu with Apache, MariaDB, PHP and lab NAT active. Windows installations are pending ISO transfers; osTicket application setup is pending. No live domain accounts or resolved tickets yet. Actual results are recorded in `evidence/validation.md`; the 20 ticket solutions remain expected resolutions to validate during practice.

## Start here

1. Read [Build guide](docs/build-guide.md) and create the isolated VMs.
2. Run the numbered scripts in order on their specified machines, using elevated **Windows PowerShell 5.1**. Read each script before running it.
3. Import the 30 users from [users.csv](data/users.csv), configure the file server, then join clients.
4. Follow [Group Policy](docs/group-policy.md) and [osTicket setup](docs/osticket.md).
5. Work through [20 tickets and solutions](docs/tickets-and-kb.md), enter them in osTicket, and capture evidence.

## Topology

| Machine | OS / role | Address | Suggested RAM |
|---|---|---|---|
| DC01 | Server 2025; AD DS, DNS, DHCP | 10.77.0.10/24 | 4 GB |
| FS01 | Server 2025 member; SMB files | 10.77.0.20/24 | 4 GB |
| HD01 | Linux VM; osTicket web/database | 10.77.0.30/24 | 2–4 GB |
| PC01, PC02 | Windows 11 Pro/Enterprise/Education | DHCP .100–.199 | 4 GB each |

Domain: `corp.example.test`; NetBIOS: `CORP`. Network: `10.77.0.0/24`. No default gateway is required for the isolated exercises. All Windows guests use **only 10.77.0.10 for DNS**. Use an optional isolated NAT router at .1 for updates, then supply its address explicitly to the DHCP script. Never bridge the lab DHCP server to a home, school, or workplace LAN.

Budget approximately 24–32 GB host RAM and 250 GB free disk for the complete lab, with fewer concurrent guests on smaller hosts. Obtain licensed installation media or official evaluation editions. Windows 11 VMs need a compatible virtual CPU, UEFI/Secure Boot and virtual TPM 2.0; Home cannot join this AD domain.

## Package

- `scripts/01-NewForest.ps1`: static DC address and new AD forest; restart required.
- `scripts/02-ConfigureDomain.ps1`: OUs, delegated membership groups, authorized DHCP scope.
- `scripts/03-ProvisionUsers.ps1`: CSV validation, individual random initial passwords, 30 accounts and department membership; supports `-WhatIf`.
- `scripts/04-JoinDomain.ps1`: domain join and restart for FS01/clients.
- `scripts/05-ConfigureShares.ps1`: department shares with group-based NTFS/SMB permissions.
- `scripts/06-ValidateLab.ps1`: domain baseline checks and CSV results.
- `docs/`: deployment, policy, ticket exercises, osTicket KB workflow, and references.
- `evidence/`: blank evidence register; no fabricated results.

Lab accounts have no administrative rights. Initial credentials are written only to an explicitly requested, ACL-restricted local file on DC01. Transfer them securely to test users and remove the credential export after first sign-in. Do not commit credentials or publish screenshots containing passwords.
