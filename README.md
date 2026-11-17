# Windows Administration & Help Desk Lab

A local practice environment for Active Directory, DNS, DHCP, Group Policy, file permissions, and help desk troubleshooting.

The original deployment and testing used automation. The automation and build tooling have been removed from this working copy. Retained evidence records that earlier run; it does not establish that the exercises were completed manually.

## Environment

| Machine | Role | Lab address |
|---|---|---|
| DC01 | Windows Server 2025: Active Directory, DNS, DHCP | 10.77.0.10 |
| FS01 | Windows Server 2025: department file shares | 10.77.0.20 |
| HD01 | Ubuntu: osTicket and lab internet routing | 10.77.0.30; gateway 10.77.0.1 |
| PC01 / PC02 | Windows 11 domain workstations | DHCP |

Domain: `corp.example.test` (`CORP`). The internal VirtualBox network is `HelpDeskLab`. There are 30 test accounts across IT, HR, Finance, Sales, and Operations.

Department members can modify their own share; other departments are denied access. Public is read-only. Group Policy supplies account rules, workstation security settings, and mapped drives.

## Project files

- [Lab access and recovery](docs/live-lab.md): start the existing VMs, sign in, and access osTicket.
- [Manual build guide](docs/build-guide.md): recreate the environment using the management consoles.
- [Group Policy and permissions](docs/group-policy.md): policy settings and the access model.
- [osTicket guide](docs/osticket.md): application setup and manual ticket handling.
- [Troubleshooting exercises](docs/tickets-and-kb.md): 20 scenarios to repeat and document yourself.
- [Recorded results](evidence/validation.md): historical test outcomes and supporting evidence.
- `data/`: account roster, media inventory, and public lab CA certificate.
- `evidence/`: diagnostic output, policy exports, screenshots, and recovery records.

Local VM disks, installation media, credentials, and backups are excluded from Git. Open the existing VMs in VirtualBox; the project no longer includes a build package or automation scripts. Keep the workspace at its current location because VirtualBox references files within it.
