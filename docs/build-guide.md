# Building the help desk lab

This guide walks through setting up the mock office from scratch. If the lab is already installed and you just want to start it or sign in, use the [guide to the existing lab](live-lab.md).

## 1. Set up the five machines

Create these machines in VirtualBox Manager.

| Machine | Install | What it does |
| --- | --- | --- |
| DC01 | Windows Server 2025 Desktop Experience | Manages accounts, DNS and DHCP |
| FS01 | Windows Server 2025 Desktop Experience | Hosts the department folders |
| PC01 and PC02 | A Windows 11 edition that can join a domain | Act as employee computers |
| HD01 | Ubuntu | Runs the help desk and can provide outbound internet access |

Use UEFI and configure the TPM for Windows 11. Attach each machine to the VirtualBox internal network named `HelpDeskLab`. Give HD01 a second adapter in NAT mode if you plan to use the optional internet connection. Keep the lab off the physical LAN by using the internal network for all lab traffic.

Install the operating systems, name the machines, and install Guest Additions. Use separate administrator credentials and store them outside the repository. The original build used four virtual CPUs for each Windows guest and three for HD01 to get past startup problems on the host.

## 2. Set up employee sign-ins

On DC01, set the IPv4 address to `10.77.0.10`, the subnet mask to `255.255.255.0`, and DNS to `10.77.0.10`. Leave the gateway blank until you have working routing through `10.77.0.1`.

In Server Manager, install Active Directory Domain Services and DNS. Promote DC01 to a domain controller for a new forest named `corp.example.test` and use `CORP` as the NetBIOS name. Save the Directory Services Restore Mode password somewhere private. After the restart, sign in as `CORP\Administrator`.

In Active Directory Users and Computers, create the organizational units `LabUsers`, `Workstations`, `Servers`, and `LabGroups`. For IT, HR, Finance, Sales, and Operations, create a global security group named `GG_<department>` and a domain-local security group named `DL_<department>_Modify`. Add each global group to its matching domain-local group. This lets you manage access by changing who belongs to a department.

Create the 30 accounts in `LabUsers` and assign each one to its department’s global group. Require a password change on the first sign-in, then complete those changes from the Windows clients after they join the domain. [Account roster](../data/users.csv)

## 3. Get the machines talking

Install the DHCP Server role on DC01 and authorize it using the post-install wizard. In DHCP Manager, create and activate a scope from `10.77.0.100` to `10.77.0.199` with mask `255.255.255.0`. Set the scope’s DNS server to `10.77.0.10` and its DNS domain to `corp.example.test`. DC01 should be the only DHCP server on `HelpDeskLab`.

Set FS01 to `10.77.0.20/24` and HD01 to `10.77.0.30/24`. Both should use DC01 for DNS. Let PC01 and PC02 pick up their settings from DHCP. In DNS Manager, add a `helpdesk` A record for `10.77.0.30`. If you want to practice reverse DNS, add the reverse lookup zone and PTR records here as well.

You can do the domain and file-sharing exercises with just the internal network. For the optional internet exercise, give HD01 the internal address alias `10.77.0.1`, enable IPv4 forwarding, and configure NAT through its outbound adapter. After you confirm routing works, use `10.77.0.1` as the gateway on DC01 and add it as the router option in DHCP.

## 4. Join the computers and set up shared folders

On FS01, PC01, and PC02, open System Properties and join `corp.example.test` using a domain account authorized to join computers. Restart all three. Back in Active Directory Users and Computers, move FS01 into `Servers` and the two Windows 11 computers into `Workstations`.

On FS01, create `C:\LabShares` with a folder for each department and one called `Public`. In the folder’s **Security** and **Advanced Sharing** settings, give its domain-local group NTFS **Modify** and SMB **Change**. Give `Domain Users` read-only access to Public and keep access for SYSTEM and administrators. On the domain firewall profile, allow SMB from the lab subnet. [Group Policy and permissions](group-policy.md)

## 5. Apply workstation settings and open the help desk

Use Group Policy Management to set up the account rules, workstation settings, and shared drives. [Group Policy settings](group-policy.md)

Install osTicket on HD01. Add the public lab CA certificate to the Windows clients’ trusted certificates, then open the help desk from a client and check that it loads without a certificate warning. [osTicket setup](osticket.md)

## 6. Check the office before running tickets

Start with an ordinary employee account. Sign in on a Windows client and check that the shared drives appear. Create a test file in the employee’s department folder and try opening another department’s folder to confirm access is denied. Open a file in Public and try to create one there, which should be denied. Repeat the department checks with a test account from each team.

On DC01, review the users, group memberships, DHCP leases and computer locations in the management consoles. Run `dcdiag /test:dns` there. These commands are useful on the Windows clients when you want to check the setup from their side.

```powershell
ipconfig /all
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.corp.example.test
Test-ComputerSecureChannel -Verbose
gpresult /r
Test-NetConnection FS01 -Port 445
```

Save dated output or screenshots so you have something to compare against as you work through the tickets. Run one exercise at a time. Use the VM console for anything that might cut off the network, undo the exercise change at the end, and log the request, diagnosis, fix, and retest in osTicket. Save your own results with the date you ran them. [Practice tickets](tickets-and-kb.md)

Back up the osTicket application and database once the setup is working. Try restoring the backup before you rely on it.
