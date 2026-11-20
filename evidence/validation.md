# How the lab held up

On October 18, 2026, the lab was running across five VirtualBox machines with 30 test accounts in five departments. The original run closed all 20 practice tickets in osTicket and published a help article for each one. These notes come from the original deployment and automated tests. They describe what worked that day. The test scripts have since been removed.

## Acceptance results

### Getting people signed in

All 19 checks for the domain setup passed. FS01 and both Windows 11 clients joined `corp.example.test` and passed their secure-channel checks. The domain controller passed its advertising, services, and basic DNS tests. The clients picked up `10.77.0.100` and `10.77.0.101` from the authorized DHCP pool, with a `/24` mask, DNS at `10.77.0.10`, and a gateway at `10.77.0.1`. [Domain checks](baseline-final.csv) · [Domain controller tests](dcdiag-final.txt) · [DHCP leases](dhcp-final-leases.json) · [DHCP configuration](dhcp-configuration.txt) · [FS01 details](fs01-shares.txt)

Each department had six accounts, and all 30 completed an authenticated password change. The account policy required at least 14 characters, password complexity, and a history of 24 passwords. Five failed attempts triggered a 15-minute lockout, with a 15-minute reset window. Both workstations had a 15-minute idle timeout and an enabled domain firewall that blocked incoming traffic and allowed outgoing traffic by default. [Group counts](final-group-counts.json) · [Password-change results](onboarding-password-changes.csv) · [Account policy](final-account-policy.json) · [Domain Group Policy](domain-account-gpo.html) · [PC01 policy](pc01-domain-policy.txt) · [PC02 policy](pc02-domain-policy.txt) · [Firewall check](pc02-final-client-host.txt)

### Checking what employees could open

A console sign-in as `CORP\it04` showed the expected drives in Windows: `P:` for Public and `H:` for IT. The earlier check from a background session didn’t apply the drive mappings, so the console sign-in is the evidence for that result. [Drive mappings](interactive-mappings.json) · [Policy events](interactive-gp-events.json) · [Applied user policy](interactive-user-gpresult.html)

In each of the five departments, a standard user could create, read, and delete a file in their own share. Five checks against other departments returned access denied. The IT test account could read files in Public, got an access-denied response when trying to write there, and could edit files in IT. [Department share tests](suffix-and-share-baselines.txt) · [Public share test](share-T20-it04-Public.json) · [IT share test](share-baseline-it04-IT.json)

### Opening the help desk

Both Windows clients opened the help desk over HTTPS and trusted the lab certificate. A separate check from the host confirmed the certificate authority and hostname. The osTicket records show 20 closed exercise tickets and 20 published FAQs. The article text and public search were checked as well. The extra ticket in the system is the installer’s welcome ticket. [PC01 HTTPS check](pc01-https.txt) · [PC02 HTTPS check](pc02-final-client-host.txt) · [Staff login](osticket-staff-login.json) · [Ticket and FAQ inventory](osticket-ticket-manifest.json) · [Public FAQ checks](osticket-public-faq-checks.json)

### Trying the backups

The finished osTicket database was restored into a separate test database. It contained 21 tickets including the welcome ticket, 20 FAQs, and 61 thread entries. The application configuration was restored and compared too, and the guest and host backup hashes matched. [Restore test](osticket-completed-restore.txt) · [Guest backup hashes](osticket-completed-backup-hashes.txt) · [Host backup hashes](osticket-completed-host-hashes.json)

An earlier HD01 snapshot was also restored. The test marker disappeared and the services came back up. The five machines were later paused together, checkpointed, and resumed. That newer checkpoint set was saved for restoring all five machines together. The restore test covered the earlier HD01 snapshot. [HD01 restore test](hd01-restore-test.txt) · [Checkpoint record](lab-checkpoints.json)

## Ticket resolutions

The osTicket links below are for the local lab. The linked test files can be opened directly from this repository. For each scenario, the ticket holds the internal notes and its FAQ gives the employee-facing advice.

### Login

- **T01 · Account locked out.** The account hit the lockout threshold. After the test identity and account state were checked, `it01` was unlocked. Windows accepted the correct password and reported the account as unlocked. [Ticket 309263](https://127.0.0.1:8443/scp/tickets.php?id=2) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=1) · [Test notes](login-ticket-observations.json)
- **T02 · Forgotten password.** A unique temporary password was issued with a change required. The old password was rejected. Windows accepted the password change and authenticated the replacement. [Ticket 362597](https://127.0.0.1:8443/scp/tickets.php?id=3) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=2) · [Test notes](login-ticket-observations.json)
- **T03 · Disabled account.** The account was disabled for the exercise. After checking that it was supposed to be active, the test re-enabled `finance01` and confirmed that Windows accepted the same credentials. [Ticket 907575](https://127.0.0.1:8443/scp/tickets.php?id=4) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=3) · [Test notes](login-ticket-observations.json)
- **T04 · Expired account.** `sales01` had an account expiration date in the past. Clearing the date restored network logon for the permanent test account. [Ticket 180602](https://127.0.0.1:8443/scp/tickets.php?id=5) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=4) · [Test notes](login-ticket-observations.json)
- **T05 · Wrong sign-in account.** Windows was looking for a local `operations01` account. Signing in with the domain credentials succeeded, and Windows identified the user as `CORP\operations01`. [Ticket 114502](https://127.0.0.1:8443/scp/tickets.php?id=6) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=5) · [Test notes](T05-observations.json)

The login checks used Windows authentication calls. The mapped-drive check above also included a sign-in at the workstation console.

### DNS

- **T06 · Wrong DNS server.** The workstation was pointed at the wrong DNS address. After switching it back to DHCP-provided DNS and clearing the cache, the client resolved DC01 to `10.77.0.10`. [Ticket 490643](https://127.0.0.1:8443/scp/tickets.php?id=7) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=6) · [Test notes](T06-observations.json)
- **T07 · Help desk site sent users to the wrong address.** The `helpdesk` record was restored to `10.77.0.30` and the client’s cache was cleared. The client resolved the correct address and got HTTP 200 over HTTPS with a valid certificate. [Ticket 497707](https://127.0.0.1:8443/scp/tickets.php?id=8) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=7) · [Test notes](T07-observations.json)
- **T08 · One computer ignored the DNS answer.** A local hosts file entry took precedence. Restoring the original file and clearing the cache sent the application back to `10.77.0.30`, where it could reach the HTTPS port. [Ticket 784878](https://127.0.0.1:8443/scp/tickets.php?id=9) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=8) · [Test notes](T08-observations.json)
- **T09 · A cached answer outlasted a DNS change.** A cache-only query gave the old “name not found” response even after DC01 had the correct record. Ordinary application lookups refreshed on their own during the test. After clearing the cache, both a fresh lookup and the next cache-only query returned `10.77.0.30`. The test record was removed. [Ticket 546639](https://127.0.0.1:8443/scp/tickets.php?id=10) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=9) · [Test notes](T09-observations.json)
- **T10 · A short server name stopped working.** The suffix search list was set to `invalid.test`. After restoring the saved list, `nslookup` expanded `FS01` to `FS01.corp.example.test` and returned `10.77.0.20`. The test notes include an earlier attempt with `Resolve-DnsName` that didn’t verify the expansion. [Ticket 800590](https://127.0.0.1:8443/scp/tickets.php?id=11) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=10) · [Test notes](T10-observations.json)

### Connectivity

- **T11 · No address from DHCP.** PC01 was attached to an empty virtual network with no DHCP service. It got a lease on the `10.77.0.0/24` network again after reconnecting to `HelpDeskLab` and renewing. [Ticket 978281](https://127.0.0.1:8443/scp/tickets.php?id=12) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=11) · [Test notes](T11-observations.json)
- **T12 · Wrong subnet mask.** PC01 temporarily used `10.77.0.250` with a `/30` mask. The address was outside the DHCP pool. After removing it and restoring DHCP and automatic DNS, the client received a `/24` lease and could reach DC01 on TCP port 389. [Ticket 342687](https://127.0.0.1:8443/scp/tickets.php?id=13) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=12) · [Test notes](T12-observations.json)
- **T13 · Disconnected workstation.** The virtual adapter was disabled. Enabling it and renewing DHCP brought the adapter up and restored connectivity to FS01 on TCP port 445. [Ticket 924720](https://127.0.0.1:8443/scp/tickets.php?id=14) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=13) · [Test notes](T13-observations.json)
- **T14 · One workstation couldn’t reach the file server.** An outbound rule named `Lab-T14` blocked file-sharing traffic from PC01. Removing the rule restored the connection to FS01 on TCP port 445. [Ticket 875136](https://127.0.0.1:8443/scp/tickets.php?id=15) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=14) · [Test notes](T14-observations.json)
- **T15 · Internet access failed.** PC01’s gateway was set to the unused `10.77.0.254`. After restoring the route through HD01 at `10.77.0.1`, the same external HTTPS connection succeeded. [Ticket 901233](https://127.0.0.1:8443/scp/tickets.php?id=16) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=15) · [Test notes](T15-observations.json)

### File access

- **T16 · HR employee couldn’t access the HR folder.** `hr04` was missing from `GG_HR`. Restoring the approved membership and starting a fresh session let the user read, create, and delete a file in HR. The same account was denied access to Finance. [Ticket 231786](https://127.0.0.1:8443/scp/tickets.php?id=17) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=16) · [Before](share-T16-fault-hr04-HR.json) · [After](share-T16-repair-hr04-HR.json)
- **T17 · Finance had share access but lacked folder permissions.** The NTFS Allow entry was missing. Restoring the saved folder permissions brought back the user’s ability to read, create, and delete files. An attempt to access HR was denied. [Ticket 802439](https://127.0.0.1:8443/scp/tickets.php?id=18) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=17) · [Before](share-T17-fault-finance04-Finance.json) · [After](share-T17-repair-finance04-Finance.json)
- **T18 · Sales had folder permissions but lacked share access.** The share was missing SMB Change for `CORP\DL_Sales_Modify`. Restoring that entry let the user read, create, and delete a file over the network. An attempt to access HR was denied. [Ticket 193262](https://127.0.0.1:8443/scp/tickets.php?id=19) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=18) · [Before](share-T18-fault-sales04-Sales.json) · [After](share-T18-repair-sales04-Sales.json)
- **T19 · Recently granted access didn’t show up.** The existing Windows session still used the old membership. A fresh sign-in let the Operations user read, create, and delete a test file. [Ticket 920659](https://127.0.0.1:8443/scp/tickets.php?id=20) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=19) · [Test notes](T19-observations.json)
- **T20 · Public rejected edits.** Public is a read-only folder for reference material. The IT test account could read there and was denied write access. It could read, create, and delete a file in its department folder, which was the right place for the work. [Ticket 856842](https://127.0.0.1:8443/scp/tickets.php?id=21) · [FAQ](https://127.0.0.1:8443/kb/faq.php?id=20) · [Public test](share-T20-it04-Public.json) · [IT test](share-baseline-it04-IT.json)

The file access test log also records the failed attempts against other departments and the successful retests after restoring the original permissions. [File access test log](permission-live-tickets.txt)

## Notes from the run

All four Windows guests reported activated evaluation licenses. At the end of setup, the installation DVDs had been detached, automatic administrator sign-in was disabled, the default password registry value was absent, and Guest Additions was running. [Domain controller setup check](dc01-setup-cleanup.json) · [File server setup check](fs01-setup-cleanup.json) · [PC01 setup check](pc01-setup-cleanup.json) · [PC02 setup check](pc02-setup-cleanup.json)

VirtualBox used its slower NEM backend with the host’s virtualization-based security enabled. Several guests stalled during setup or shutdown and needed a VM reset. The guest and domain checks were repeated afterward. The lab used an internal virtual network and HD01’s host forwards listened only on loopback.

The VM disks, credentials, private keys, and application and database backups are stored locally outside Git. The build ZIP and the original automation tooling were removed. For current access and recovery instructions, see the [guide to the existing lab](../docs/live-lab.md).
