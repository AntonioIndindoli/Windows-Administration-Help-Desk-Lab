# Build and run

## 1. Prepare virtualization

Use Hyper-V, VMware, or VirtualBox with a private/internal virtual network named `HelpDeskLab`. Attach every lab NIC to this same isolated network. Disable any hypervisor-provided DHCP on it; DC01 will provide DHCP. Do not connect this virtual switch directly to a physical network. Create Generation 2/equivalent UEFI VMs, install updates, and take clean-install checkpoints. Use Desktop Experience on the Windows servers for these exercises.

Install Server 2025 on DC01 and FS01. Install a domain-capable Windows 11 edition on PC01/PC02. Give machines these names before continuing. Use strong, distinct local administrator credentials. On a newly installed machine, run `Get-NetAdapter` to find the actual NIC alias. Scripts intentionally require explicit interface selection.

## 2. Create the forest on DC01

Copy this project into `C:\Lab` on DC01. In elevated Windows PowerShell 5.1:

```powershell
Set-Location C:\Lab
.\scripts\01-NewForest.ps1 -InterfaceAlias 'Ethernet'
```

Enter a strong Directory Services Restore Mode password. The script assigns 10.77.0.10/24, installs AD DS/DNS, promotes DC01, and restarts it. Optional internet routing must exist before passing `-Gateway 10.77.0.1`; the script does not create a router. After restart sign in as `CORP\Administrator`, verify DNS and run:

```powershell
.\scripts\02-ConfigureDomain.ps1
.\scripts\03-ProvisionUsers.ps1 -CsvPath .\data\users.csv -CredentialOutputPath C:\LabSecrets\initial-users.csv -WhatIf
.\scripts\03-ProvisionUsers.ps1 -CsvPath .\data\users.csv -CredentialOutputPath C:\LabSecrets\initial-users.csv
```

The first provisioning invocation previews creation. The real invocation generates a different password per new user and requires a password change at first interactive sign-in. Existing users are skipped without resetting passwords. Existing accounts are checked for department group membership. This workflow does not relocate or reconcile all attributes of existing users.

## 3. Join FS01 and clients

On FS01, set IPv4 manually to 10.77.0.20/24 and DNS 10.77.0.10 (leave gateway empty unless configured). On PC01/PC02, keep IPv4 on DHCP. Confirm `ipconfig /all` reports a .100–.199 lease and DNS .10. Copy the join script to each guest and run elevated:

```powershell
.\04-JoinDomain.ps1 -InterfaceAlias 'Ethernet' -ComputerName FS01 -TargetOU Servers
# On respective clients substitute PC01 or PC02 and -TargetOU Workstations
```

Use a domain administrator for this isolated setup. The script prompts for credentials and restarts the guest. In a production environment delegate computer creation/join rights instead. On FS01 after restart, sign in with a domain admin and run `05-ConfigureShares.ps1`. The data folder is `C:\LabShares` by default; a separate data volume may be supplied with `-RootPath D:\LabShares`.

## 4. Apply policies and set up osTicket

Follow `group-policy.md` and `osticket.md`. Configure HD01 static .30 and DNS .10; create an A record on DC01 using DNS Manager: forward zone `corp.example.test`, host `helpdesk`, address `10.77.0.30`. Add a reverse zone for `10.77.0.0/24` and PTR records as a DNS exercise. PTR is useful for diagnostics but does not replace forward/SRV lookups.

## 5. Validate before fault injection

On DC01 run `06-ValidateLab.ps1 -OutputPath C:\Lab\evidence\baseline.csv`. Run `dcdiag /test:dns` separately and save its output. On both clients:

```powershell
ipconfig /all
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.corp.example.test
Test-ComputerSecureChannel -Verbose
gpresult /r
Test-NetConnection FS01 -Port 445
```

Sign in with one user from each department; change initial passwords. Confirm own department share permits file creation/deletion, another department share denies access, and a shared read-only resource rejects writes. Use a fresh sign-in after group changes. Enter actual results, timestamps, machine names, and evidence locations in the evidence register.

## 6. Perform 20 support exercises

Create one osTicket ticket per scenario. Take a baseline checkpoint first. Inject one fault at a time on test clients/accounts. Capture symptom, diagnostics, repair, and successful retest. Restore the baseline after each exercise. Do not restore only a DC checkpoint into a continuing domain as routine rollback; prefer reversing the individual fault or restoring a coordinated powered-off whole-lab snapshot. Scenarios involving broad network changes should be restricted to one disposable client.

## Completion criteria

- DC01 advertises healthy AD/DNS; DHCP is authorized and both clients obtain leases.
- FS01, PC01, PC02 are domain members in the intended OUs.
- Exactly 30 CSV users exist in the lab user OU; department global groups feed resource domain-local groups.
- GPO results and positive/negative SMB access tests are recorded.
- 20 real osTicket tickets contain evidence and validated resolutions; 20 corresponding FAQs are published and searchable.
- Credentials removed from export, VM backups/checkpoints documented, and no secrets in the portfolio.
