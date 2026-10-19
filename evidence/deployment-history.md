# Actual validation register

Status: PARTIAL DEPLOYMENT, 2026-10-18 (America/Los_Angeles). Oracle VirtualBox 7.2.20 installed successfully through winget. Five isolated VMs created and registered; Ubuntu is deployed on HD01 and its web/database services are healthy. Windows guest installations and live AD/ticket validation remain pending media download/installation. The initial DC01 power-on test verified the empty VM only.

## Observed host and deployment results

- Host OS: Windows 11 Home, build 10.0.26200; physical memory 33,407,934,464 bytes (31.1 GiB). HypervisorPresent reported true.
- Initial C: free space: 342,825,709,568 bytes (319.3 GiB). Available RAM varied from approximately 10 GiB to 7.8 GiB; guest installation must be staged.
- Session is not an elevated administrator. Initial sandbox CIM access failed; approved host inspection succeeded outside the sandbox. Hyper-V management module absent.
- `winget install --id Oracle.VirtualBox --exact --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity` returned **Successfully installed**. `VBoxManage --version`: `7.2.20r175154`.
- Initial VirtualBox VM inventory was empty. Created DC01, FS01, PC01, PC02 (4 GiB RAM, 2 CPUs each), and HD01 (2 GiB RAM, 2 CPUs). Windows VMs use EFI, TPM 2.0 and Secure Boot. Dynamic disks: 64 GiB for each server, 80 GiB per client, 32 GiB for HD01. NIC1 on each uses internal network `HelpDeskLab`; NIC2 disabled; no bridged network.
- `VBoxManage startvm DC01 --type headless` succeeded and `showvminfo` reported `VMState="running"`. Empty VM then powered off successfully. This verifies host execution only, not a functioning guest OS.
- Official Microsoft Server and Enterprise evaluation download endpoints responded with HTTP 200 and ISO content lengths 8,152,356,864 and 8,225,329,152 bytes. Initial full-file transfer requests stalled at zero bytes. A bounded Server ISO range request succeeded with HTTP 206 and 1,048,576 bytes; this probe is **not installation media**.
- Configuration evidence: [VirtualBox inventory](virtualbox-inventory.txt). VM registration and disk creation succeeded using `scripts/00-CreateVirtualBoxVMs.ps1`.
- HD01 guest OS is now deployed from Canonical's official Ubuntu 24.04 cloud disk. Downloaded 590,749,696 bytes; SHA-256 `9a1e3959c9f4ad9d4752101fd4ff9a43191fb7d72e61fa20e033f9fd235ce794` matches the publisher manifest. See `ubuntu-media-verification.json`.
- First HD01 boots stalled with the default KVM paravirtualization and with one vCPU/no paravirtualization. VBox logs report `AMD-V is not available`, NEM fallback and `Snail execution mode is active` with the Windows hypervisor present. Retried using three vCPUs and the Hyper-V paravirtualization provider: guest boot and SSH succeeded. Windows VM CPU counts also changed to three before their installation (not yet guest-validated).
- HD01 cloud-init completed. SSH reports hostname `hd01`, lab0 `10.77.0.30/24` plus router alias `10.77.0.1/24`, and nat0 `10.0.3.15/24`. Apache, MariaDB and lab-router services are active; PHP reports 8.3.6. Host loopback `http://127.0.0.1:8080/` returned HTTP 200 for the default Apache page. **This is not yet an installed osTicket application.** See `hd01-baseline.txt` and `hd01-apache-default.html`.
- HD01 NAT NIC forwards SSH 2222, HTTP 8080 and HTTPS 8443 on **127.0.0.1 only**. No bridged NICs. Its router alias supports the planned .1 gateway; Windows DHCP/AD are still pending. SSH password authentication disabled; private key stored in ACL-restricted `LabSecrets`.
- RAM allocations adjusted to DC01 3 GiB, FS01 2 GiB, PC01/PC02 4 GiB each, HD01 2 GiB. After the user freed memory, host available memory was 14,609,640 KiB. See `host-inventory.json` for the captured inventory timestamp.

| Milestone | Date / agent | Actual result | Evidence path / link |
|---|---|---|---|
| VM inventory and isolated switch | 2026-10-18 / Codex | PASS: five VM shells; internal HelpDeskLab network; DC01 boot smoke test passed. Guest OS installation pending. | virtualbox-inventory.txt |
| AD forest and DNS health | | Not run | |
| DHCP options and two client leases | | Not run | |
| 30 users and group membership | | Not run | |
| Three domain joins | | Not run | |
| GPO resultant settings | | Not run | |
| Five positive and five negative share tests | | Not run | |
| Public read/write denial | | Not run | |
| osTicket deployment and FAQ visibility | 2026-10-18 / Codex | PARTIAL PASS: app installed; strict CA/hostname TLS check returns HTTP 200. Twenty exercise tickets open, twenty FAQs private/unverified. Staff login PASS via trusted HTTPS; published client FAQ checks pending. | osticket-baseline.txt; osticket-ticket-manifest.json; osticket-client-home.html |
| Backup/restore | 2026-10-18 / Codex | PARTIAL PASS: HD01 Ubuntu-Web-Ready snapshot taken after clean shutdown; marker created, snapshot restored, marker absent; cloud-init done and three services active. osTicket database/application backup still pending. | hd01-restore-test.txt |

## Ticket completion

| Exercise | osTicket ID / URL | FAQ URL | Actual cause / fix / verification evidence | Closed date |
|---|---|---|---|---|
| T01 | [309263](https://127.0.0.1:8443/scp/tickets.php?id=2) | Private draft FAQ 1 | OPEN - no live Windows fault/retest yet | |
| T02 | [362597](https://127.0.0.1:8443/scp/tickets.php?id=3) | Private draft FAQ 2 | OPEN - no live Windows fault/retest yet | |
| T03 | [907575](https://127.0.0.1:8443/scp/tickets.php?id=4) | Private draft FAQ 3 | OPEN - no live Windows fault/retest yet | |
| T04 | [180602](https://127.0.0.1:8443/scp/tickets.php?id=5) | Private draft FAQ 4 | OPEN - no live Windows fault/retest yet | |
| T05 | [114502](https://127.0.0.1:8443/scp/tickets.php?id=6) | Private draft FAQ 5 | OPEN - no live Windows fault/retest yet | |
| T06 | [490643](https://127.0.0.1:8443/scp/tickets.php?id=7) | Private draft FAQ 6 | OPEN - no live Windows fault/retest yet | |
| T07 | [497707](https://127.0.0.1:8443/scp/tickets.php?id=8) | Private draft FAQ 7 | OPEN - no live Windows fault/retest yet | |
| T08 | [784878](https://127.0.0.1:8443/scp/tickets.php?id=9) | Private draft FAQ 8 | OPEN - no live Windows fault/retest yet | |
| T09 | [546639](https://127.0.0.1:8443/scp/tickets.php?id=10) | Private draft FAQ 9 | OPEN - no live Windows fault/retest yet | |
| T10 | [800590](https://127.0.0.1:8443/scp/tickets.php?id=11) | Private draft FAQ 10 | OPEN - no live Windows fault/retest yet | |
| T11 | [978281](https://127.0.0.1:8443/scp/tickets.php?id=12) | Private draft FAQ 11 | OPEN - no live Windows fault/retest yet | |
| T12 | [342687](https://127.0.0.1:8443/scp/tickets.php?id=13) | Private draft FAQ 12 | OPEN - no live Windows fault/retest yet | |
| T13 | [924720](https://127.0.0.1:8443/scp/tickets.php?id=14) | Private draft FAQ 13 | OPEN - no live Windows fault/retest yet | |
| T14 | [875136](https://127.0.0.1:8443/scp/tickets.php?id=15) | Private draft FAQ 14 | OPEN - no live Windows fault/retest yet | |
| T15 | [901233](https://127.0.0.1:8443/scp/tickets.php?id=16) | Private draft FAQ 15 | OPEN - no live Windows fault/retest yet | |
| T16 | [231786](https://127.0.0.1:8443/scp/tickets.php?id=17) | Private draft FAQ 16 | OPEN - no live Windows fault/retest yet | |
| T17 | [802439](https://127.0.0.1:8443/scp/tickets.php?id=18) | Private draft FAQ 17 | OPEN - no live Windows fault/retest yet | |
| T18 | [193262](https://127.0.0.1:8443/scp/tickets.php?id=19) | Private draft FAQ 18 | OPEN - no live Windows fault/retest yet | |
| T19 | [920659](https://127.0.0.1:8443/scp/tickets.php?id=20) | Private draft FAQ 19 | OPEN - no live Windows fault/retest yet | |
| T20 | [856842](https://127.0.0.1:8443/scp/tickets.php?id=21) | Private draft FAQ 20 | OPEN - no live Windows fault/retest yet | |

## osTicket deployment verification

Upstream v1.18.4 source archive passed ZIP CRC validation (2,498 entries). Upstream `manage.php deploy --setup` and installer initialized the database; setup directory moved out of the web root and config mode is 640 (root:www-data). Database reads confirm 21 total tickets (one installer welcome ticket plus 20 exercise tickets), 20 FAQ drafts and four private categories. Initial custom CA lacked strict key-usage extensions; regenerated with CA keyCertSign/cRLSign and leaf digitalSignature/keyEncipherment, then Python SSL chain/hostname verification passed with HTTP 200. No TLS verification bypass used for the successful check. Generated admin/database credentials are stored only under restricted LabSecrets and root-only guest storage.

Server media completed: 8,152,356,864 bytes; SHA-256 7b052573ba7894c9924e3e87ba732ccd354d18cb75a883efa9b900ea125bfd51. VirtualBox detected Standard Evaluation Desktop Experience at image index 2; DC01 and FS01 unattended installations started. osTicket admin login is verified in osticket-staff-login.json. A live database dump imported successfully into the separate osticket_restore_test database and matched 21 tickets, 20 FAQs and 1 staff account; see osticket-database-restore-test.txt. Application archive exists in root-only guest backup storage; full application restore and independent off-VM backup copy remain pending.
