# Windows Administration & Help Desk Lab

A working Windows domain and help desk environment built to demonstrate entry-level IT support and Windows administration skills: deploying servers and workstations, managing user access, troubleshooting faults, automating routine tasks, and documenting verified solutions.

The lab models a small organization with five departments (IT, HR, Finance, Sales, and Operations), with six users per department. Support scenarios use simulated requests and deliberately injected faults against real virtual machines and domain services.

**Technologies:** Windows Server 2025 · Windows 11 Enterprise · Active Directory · DNS · DHCP · Group Policy · PowerShell · osTicket · Ubuntu · Oracle VirtualBox

## Project results

| Deliverable | Verified outcome |
|---|---|
| Virtual infrastructure | Five deployed VMs on an isolated lab network |
| Domain administration | Active Directory, DNS, and authorized DHCP configured; one file server and two Windows 11 clients joined to the domain |
| User provisioning | 30 accounts created from CSV data, with six users in each department and group-based access assignments |
| Policy management | Three lab GPOs covering account security, workstation security, and department drive mappings |
| File access | Five allowed and five denied department-access tests passed; Public allowed reading and denied writing |
| Help desk operations | 20 simulated support tickets investigated, retested, and closed in osTicket; 20 corresponding knowledge-base articles published |
| Domain health | All 19 baseline checks passed; AD advertising, services, and basic DNS diagnostics passed |
| Recovery | Completed help desk database/application backups restored and checked; a coordinated five-VM checkpoint set saved |

[Read the full validation report →](evidence/validation.md)

## Environment

| Machine | Operating system | Purpose | Address |
|---|---|---|---|
| DC01 | Windows Server 2025 | Active Directory Domain Services, DNS, DHCP | `10.77.0.10` |
| FS01 | Windows Server 2025 | Department file shares and Public documents | `10.77.0.20` |
| HD01 | Ubuntu | osTicket, Apache, MariaDB, and lab NAT routing | `10.77.0.30` |
| PC01 | Windows 11 Enterprise | Domain workstation and primary troubleshooting client | DHCP: `10.77.0.100` |
| PC02 | Windows 11 Enterprise | Second domain workstation | DHCP: `10.77.0.101` |

The domain is `corp.example.test` (`CORP`) on `10.77.0.0/24`. Windows guests use DC01 for DNS. The DHCP scope assigns addresses from `.100` to `.199` and supplies DNS and gateway settings. VirtualBox's internal network keeps lab DHCP off the physical LAN; HD01 provides NAT connectivity, with host access ports bound to loopback.

## Administration skills demonstrated

### Active Directory and account management

Created organizational units for users, workstations, servers, and security groups. Provisioned 30 test users through PowerShell, assigned department membership, and completed authenticated initial password changes. Joined FS01 and both clients to the intended OUs and verified their domain secure channels.

The [provisioning script](scripts/03-ProvisionUsers.ps1) validates CSV input, generates individual initial passwords, supports `-WhatIf`, and skips existing accounts without resetting their passwords. This makes account creation repeatable while reducing manual entry errors.

### Group Policy and access control

Configured password and lockout policy, a 15-minute workstation inactivity limit, and domain firewall settings. Applied user drive mappings through group targeting, then verified an interactive IT user received **P:** for Public and **H:** for IT.

Department access follows this membership model:

```text
User → Department global group → Resource domain-local group → NTFS and SMB permissions
```

Authorized users can create, read, and delete files in their department share. Users from other departments are denied access. Public remains read-only. Validation used ordinary domain accounts so administrative privileges could not hide permission problems.

### Troubleshooting and help desk documentation

Worked through 20 support cases using a consistent process: establish the baseline, reproduce the symptom, identify the cause, apply a focused repair, retest, and restore the lab configuration. PowerShell scripts exercised the faults and captured observations; osTicket recorded the resolutions and published client guidance.

| Area | Examples investigated | How recovery was checked |
|---|---|---|
| Logins | Locked, disabled, and expired accounts; password resets; local versus domain identity | Windows authentication results and account-state checks |
| DNS | Incorrect resolver and A record, hosts-file override, negative cache, suffix search | Authoritative and client lookups, cache checks, and trusted HTTPS access |
| Connectivity | APIPA, incorrect subnet mask, disabled adapter, SMB firewall block, incorrect gateway | Renewed DHCP lease, internal service connections, and external TCP connectivity |
| File permissions | Missing membership, NTFS and SMB grants, stale tokens, read-only Public access | Denied access before repair, fresh-user access after repair, and continued denial for unrelated departments |

One useful finding was the difference between restoring group membership and refreshing an existing session: the retained user token stayed denied, while a fresh logon gained the intended access.

**DNS test limitation:** T09 reproduced a stale negative result in a **cache-only** lookup. Ordinary application lookups refreshed automatically on this Windows build, so a persistent outage in ordinary lookups was not reproduced. The ticket, FAQ, and validation report preserve that distinction.

### Validation, security, and recovery

Used `dcdiag`, secure-channel checks, DHCP lease records, resultant Group Policy reports, Windows authentication calls, and user-context file tests to verify behavior. Both clients reached the help desk over HTTPS with the lab CA trusted inside the guests.

Restored the completed osTicket database into a separate test database, extracted the application backup, compared its configuration, and matched the guest and independent host backup hashes. An earlier HD01 checkpoint was restore-tested; the final coordinated five-VM checkpoint set was saved for recovery but was not itself restore-tested.

Passwords, private keys, VM disks, and database/application backups are kept outside the portfolio build ZIP in restricted storage. Test users have no administrative rights.

## Evidence and project files

| Resource | What it shows |
|---|---|
| [Validation report](evidence/validation.md) | Acceptance results, ticket resolutions, evidence links, and limitations |
| [Domain baseline results](evidence/baseline-final.csv) | All 19 domain checks and their recorded outcomes |
| [Domain health diagnostics](evidence/dcdiag-final.txt) | AD advertising, services, and basic DNS results |
| [Interactive user drive mappings](evidence/interactive-mappings.json) | Actual P: and H: mappings from the IT user's desktop session |
| [Verified ticket results](evidence/verified-ticket-results.json) | Observed symptoms, causes, repairs, retests, and client guidance |
| [osTicket completion manifest](evidence/osticket-ticket-manifest.json) | The 20 exercise ticket numbers and published FAQ status |
| [Public knowledge-base checks](evidence/osticket-public-faq-checks.json) | Article visibility, content checks, and search verification |
| [Completed backup restore results](evidence/osticket-completed-restore.txt) | Database restore and application configuration comparison |
| [PowerShell and supporting scripts](scripts/) | Provisioning, configuration, fault testing, and evidence automation |

The osTicket instance is local to the lab. Its live ticket links require access to that environment; the saved evidence can be reviewed independently.

## Run or reproduce the project

- **Use the existing deployment:** [Live lab access and recovery instructions](docs/live-lab.md).
- **Build a fresh environment:** [Build guide](docs/build-guide.md), [Group Policy configuration](docs/group-policy.md), and [osTicket setup](docs/osticket.md).
- **Review or repeat the exercises:** [20 support scenarios](docs/tickets-and-kb.md). These describe expected behavior; the validation report records the actual outcomes.
- **Download the build package:** [Scripts, documentation, and evidence ZIP](Build/Windows-Administration-Help-Desk-Lab.zip). Installation media, VM disks, and credentials remain separate.

Windows guests use activated evaluation editions. Media details and recorded hashes are in the [media manifest](data/media-manifest.json); technical sources are listed in [references](docs/references.md).
