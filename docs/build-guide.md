# Manual build guide

These are instructions for a new build, not a claim that the existing deployment was built manually. For the existing environment, use [live-lab.md](live-lab.md).

## 1. Install the virtual machines

In VirtualBox Manager, create DC01 and FS01 with Windows Server 2025 Desktop Experience, PC01 and PC02 with a domain-capable Windows 11 edition, and HD01 with Ubuntu. Use UEFI and the required Windows 11 TPM settings. Attach each lab adapter to the internal network `HelpDeskLab`. Only HD01 needs a second adapter using NAT for outbound access. Do not bridge the lab network to the physical LAN.

Install each operating system through its installer, set the machine names, install Guest Additions, and use separate administrator credentials. Keep credentials outside the repository. The existing deployment uses four virtual CPUs for Windows guests and three for HD01 because of host-specific startup problems.

## 2. Create the domain

On DC01, open the network adapter's IPv4 properties and set `10.77.0.10`, mask `255.255.255.0`, and DNS `10.77.0.10`. Use gateway `10.77.0.1` only after HD01 routing is configured.

In Server Manager, add Active Directory Domain Services and DNS. Promote DC01 to a new forest named `corp.example.test`, with NetBIOS name `CORP`. Store the Directory Services Restore Mode password privately. Restart and sign in as `CORP\Administrator`.

In Active Directory Users and Computers, create the OUs `LabUsers`, `Workstations`, `Servers`, and `LabGroups`. For each department (IT, HR, Finance, Sales, Operations), create a global security group `GG_<department>` and a domain-local security group `DL_<department>_Modify`. Nest each global group in its matching domain-local group.

Use [users.csv](../data/users.csv) as the account roster. Create the 30 users in LabUsers, assign their department groups, and require a password change at the next sign-in. Complete those password changes through the clients.

## 3. Configure DHCP and DNS

Add the DHCP Server role on DC01 and complete its post-install authorization. In DHCP Manager, create and activate the scope `10.77.0.100` through `10.77.0.199`, with mask `255.255.255.0`. Set DNS server to `10.77.0.10` and DNS domain to `corp.example.test`. Supply router `10.77.0.1` only if routing is working. Ensure no other DHCP server serves HelpDeskLab.

Set FS01 to `10.77.0.20/24` and HD01 to `10.77.0.30/24`, using DC01 for DNS. Keep PC01 and PC02 on DHCP. In DNS Manager, add `helpdesk` pointing to `10.77.0.30`. Add a reverse lookup zone and appropriate PTR records if practicing reverse DNS.

HD01's optional routing role requires an internal address alias `10.77.0.1`, IPv4 forwarding, and NAT through its outbound adapter. Until that is configured and verified, omit the gateway and skip the external-connectivity exercise. The domain and file-share exercises work without internet routing.

## 4. Join the computers and create shares

On FS01, PC01, and PC02, use System Properties to join `corp.example.test` with an authorized domain account, then restart. Move FS01's computer object into Servers and the clients into Workstations using Active Directory Users and Computers.

On FS01, create `C:\LabShares` and folders for the five departments plus Public. Configure folder Security and Advanced Sharing as described in [group-policy.md](group-policy.md). Preserve SYSTEM and administrator access. Grant departmental domain-local groups NTFS Modify and SMB Change; grant Domain Users read-only access to Public. Allow SMB from the lab subnet on the domain firewall profile.

## 5. Configure policy and help desk

Use Group Policy Management to apply the settings in [group-policy.md](group-policy.md). Follow [osticket.md](osticket.md) for the help desk. Trust the public lab CA certificate on the clients and confirm the help desk opens without a certificate warning.

## 6. Check the baseline and perform exercises

Inspect the users, group nesting, DHCP leases, computer OUs, and effective policies in their management consoles. Useful individual diagnostic commands include:

```powershell
ipconfig /all
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.corp.example.test
Test-ComputerSecureChannel -Verbose
gpresult /r
Test-NetConnection FS01 -Port 445
```

On DC01, run `dcdiag /test:dns`. Sign in as ordinary department users and test allowed and denied shares, read-only Public access, and mapped drives. Save dated output and screenshots from your own checks.

Work through [tickets-and-kb.md](tickets-and-kb.md) one fault at a time. Enter each request, diagnosis, repair, and actual retest in osTicket manually. Preserve console access during network faults and reverse each injected change. Keep new results separate from the historical validation report. Back up the application/database and test recovery before relying on the backup.
