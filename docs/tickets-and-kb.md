# Help desk practice tickets

These are the 20 scenarios used in the lab. The opening lines are examples of how someone might describe the problem when they ask for help. The notes below each one give you a way to set up the exercise, investigate it, and write a short answer for the help center.

Start each rerun with a fresh ticket and record what you actually observe. Use PC01 unless a ticket says otherwise, work with the listed test account, and use the VM console for anything that could disconnect you. Retest before closing the ticket and undo any exercise changes that are still in place. [Results from the original run](../evidence/validation.md#ticket-resolutions)

## Login

### T01 / KB01 - Account locked out

**it01 · Normal** — “I tried my password a few times and now I can’t sign in.”

Check the lockout policy, then enter the wrong password five times. On DC01, run `Search-ADAccount -LockedOut`. If account-management auditing is enabled, look for Security event 4740 to confirm the account and the computer that triggered the lockout.

Verify the requester’s identity and run `Unlock-ADAccount it01`. Have the user sign in with the correct password. If the account locks again, look for a saved credential or scheduled task that’s still using the old password and clear or update it.

**For the employee.** Stop trying old passwords and contact the help desk so they can verify your identity and unlock the account.

### T02 / KB02 - Forgotten password

**hr01 · Normal** — “I’ve forgotten my password. Can you reset it?”

Use a test employee who can’t recall their password. Before resetting it, verify their identity, check the account spelling and whether it’s enabled or locked, and confirm the computer can reach DC01. Keep all passwords out of the ticket.

Choose **Reset Password** in Active Directory Users and Computers. Set a unique temporary password, require a change at the next sign-in, and deliver it through a separate secure channel. Verify that the user can change the temporary password and sign in again. Remove any temporary credential record.

**For the employee.** Ask the help desk for a password reset and keep passwords out of your ticket. They’ll verify your identity before issuing a temporary password.

### T03 / KB03 - Disabled account

**finance01 · Normal** — “My work account won’t let me sign in anymore.”

On DC01, use `Disable-ADAccount finance01`, then try to sign in at a Windows client. Check `Get-ADUser finance01 -Properties Enabled` and confirm whether the account is supposed to be active.

Once the lab request is authorized, run `Enable-ADAccount finance01`. Check that `Enabled` is true and verify with a fresh sign-in. Leave the test account enabled.

**For the employee.** Ask the help desk to review whether your account is active before you try signing in again.

### T04 / KB04 - Account expired

**sales01 · Normal** — “My account worked yesterday. Today I can’t sign in.”

On DC01, set an expiration date in the past with `Set-ADAccountExpiration sales01 -DateTime (Get-Date).AddDays(-1)`. When sign-in fails, use `Get-ADUser sales01 -Properties AccountExpirationDate,Enabled,LockedOut` to check the account itself. Account expiration and password expiration require different fixes.

For this permanent test account, run `Clear-ADAccountExpiration sales01`. Confirm the date is cleared and sign-in works. If the account were for a contractor, use the extension date approved for that person.

**For the employee.** Include the authorization for continued access when asking for an account extension.

### T05 / KB05 - Local account used instead of domain account

**operations01 · Low** — “Windows won’t accept the username I normally use at work.”

At the sign-in screen, enter `.\operations01`. The `.\` tells Windows to look for an account on that computer, where the test user doesn’t exist. Check which sign-in domain Windows displays.

Choose **Other user**, then sign in as `CORP\operations01` or `operations01@corp.example.test`. Run `whoami` and look for `corp\operations01`. Open a resource the user normally has access to.

**For the employee.** Use the work username format you received during onboarding.

## DNS

### T06 / KB06 - Client points to the wrong DNS server

**it02 · High** — “I can’t get to any of our internal resources from this computer.”

On PC01, temporarily set the adapter’s DNS server to the unused `10.77.0.99`. Check `ipconfig /all` and compare `Resolve-DnsName DC01.corp.example.test` with `Resolve-DnsName DC01.corp.example.test -Server 10.77.0.10`. If the direct query works, check the DNS settings on the client.

Run `Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ResetServerAddresses`, substituting the actual adapter name. Confirm DHCP supplies `10.77.0.10` and flush the DNS cache. Retest DC01 and the LDAP SRV records through the default resolver, then check that the user can sign in and reach FS01.

**For the employee.** Leave DNS set to automatic on a managed computer so it can find internal services.

### T07 / KB07 - Incorrect application A record

**hr02 · Normal** — “The help desk site won’t open, but I can still use my other work tools.”

Record the current `helpdesk` A record. In DNS Manager, change just that record to the unused `10.77.0.99`. Query DC01 with `Resolve-DnsName helpdesk.corp.example.test -Server 10.77.0.10` and compare the answer with HD01’s address, `10.77.0.30`.

Restore the record in DNS Manager and run `ipconfig /flushdns` on the client. Confirm the name resolves to `10.77.0.30` and the help desk opens over HTTPS with a trusted certificate.

**For the employee.** Include the exact site address when you report a page that won’t load.

### T08 / KB08 - Hosts file overrides DNS

**finance02 · Normal** — “The help desk site works on another computer, but it won’t open on mine.”

Back up PC01’s `C:\Windows\System32\drivers\etc\hosts` file. Using an elevated editor, add the line `10.77.0.99 helpdesk.corp.example.test`. Compare what the application uses with what the DNS server returns. A direct DNS lookup returns `10.77.0.30`, but the local entry sends the application to `10.77.0.99`.

Remove the exercise line, preserve the other entries, and flush the DNS cache. Confirm that the hosts file matches the backup and that the application connects to `10.77.0.30`.

**For the employee.** Tell the help desk if the problem happens on only one computer. Let them check that computer’s settings before trying a local workaround.

### T09 / KB09 - Negative DNS cache after record creation

**sales02 · Low** — “A new internal address was set up, but my computer still says it can’t find it.”

Look up `kbtest.corp.example.test` from PC01 before the record exists. On DC01, add an A record named `kbtest` pointing to `10.77.0.30`, then retry from the client. Compare `Get-DnsClientCache` with a direct query to DC01. If the client refreshes the answer on its own, record what happened. The original run reproduced the stale answer only on a cache-only lookup.

Once the DNS server is returning the correct record, run `Clear-DnsClientCache`. Verify that a fresh lookup returns `10.77.0.30`, then remove the `kbtest` record.

**For the employee.** Tell the help desk when the address was added and what error you see. They can check whether your computer still has an older answer.

### T10 / KB10 - Short hostname fails, FQDN works

**operations02 · Low** — “I can reach `FS01.corp.example.test`, but `FS01` by itself doesn’t work.”

On PC01, save the settings shown by `Get-DnsClientGlobalSetting`, then temporarily set the DNS suffix search list to `invalid.test` from elevated PowerShell. Try the short and full names separately. The domain suffix can still be applied in some lookups, so record the result you get and use `nslookup` to see how the short name is expanded.

Compare `ipconfig /all`, `Get-DnsClientGlobalSetting`, and `Resolve-DnsName FS01.corp.example.test`. Restore the saved search list, or use `corp.example.test` if that is the lab baseline. Check that both names reach FS01, then return the setting to its original value.

**For the employee.** Include the full server name and say whether the short name is the only one that fails.

## Connectivity

### T11 / KB11 - APIPA / no DHCP lease

**it03 · High** — “This computer can’t get to any of our internal services.”

Shut down PC01 and connect its virtual adapter to a separate, empty internal network. Boot it and renew IPv4. Check `ipconfig /all` for an address beginning with `169.254` or the absence of a usable lease. Check the VM’s network attachment and use PC02 to see whether DHCP is still working elsewhere.

Shut down PC01, reconnect it to `HelpDeskLab`, boot, and run `ipconfig /renew`. Look for a lease in `10.77.0.100`–`10.77.0.199`, a `/24` mask, and DNS at `10.77.0.10`. Confirm that Active Directory names resolve.

**For the employee.** Tell the help desk which internal services you tried and keep your network address set to automatic.

### T12 / KB12 - Incorrect subnet mask

**hr03 · High** — “My computer shows a network connection, but I can’t reach the office servers.”

From the PC01 console, record the current configuration and temporarily assign a static address with a `/30` mask and no gateway. If you use `10.77.0.150`, check that it’s unused and temporarily exclude it from DHCP before assigning it. Compare `Get-NetIPConfiguration` and the routes with the baseline `/24`. DC01 is outside the smaller local subnet.

Enable DHCP again using `Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -Dhcp Enabled` with the actual interface name. Remove the temporary address if it persists, return DNS to automatic, and renew the lease. Confirm the client has a `/24` lease and can reach DC01 and FS01. Remove any DHCP exclusion after the temporary address is no longer assigned.

**For the employee.** Leave managed network settings on automatic and tell the help desk which servers you couldn’t reach.

### T13 / KB13 - Disabled client network adapter

**finance03 · High** — “The network icon says I’m disconnected and nothing on the network opens.”

Use PC01’s VM console to disable its lab adapter in Network Connections. Run `Get-NetAdapter` and look for a `Disabled` status. Re-enable that adapter from the console and make sure its virtual cable is connected.

Once it’s up, verify the DHCP lease, resolve a domain name, and open a shared folder from the client.

**For the employee.** Mention the disconnected icon in your ticket. It helps narrow down where to look first.

### T14 / KB14 - SMB blocked on one client

**sales03 · Normal** — “The network is working, but I can’t get to the shared drive from this computer.”

On PC01, add this outbound rule while leaving PC02 available for comparison.

~~~powershell
New-NetFirewallRule -DisplayName 'Lab-T14' -Direction Outbound -Action Block -Protocol TCP -RemotePort 445 -RemoteAddress 10.77.0.20
~~~

Check that DNS works, then compare `Test-NetConnection FS01 -Port 445` on PC01 and PC02. Inspect the named rule on PC01. Remove it with `Remove-NetFirewallRule -DisplayName 'Lab-T14'` and keep the firewall enabled.

Confirm that the rule is gone, that port 445 is reachable, and that an authorized user can open their share.

**For the employee.** Say which shared drive stopped working and mention any other services that still open.

### T15 / KB15 - Invalid default gateway (optional routed lab)

**operations03 · Normal** — “I can use the shared drive, but websites outside the office won’t load.”

Run this one only if HD01 already routes outbound traffic through `10.77.0.1`. Pick an external HTTPS destination you can reach and save PC01’s default route. Replace just its gateway with the unused `10.77.0.254`. Leave the DHCP scope settings alone.

Check `Get-NetRoute -DestinationPrefix 0.0.0.0/0` for the wrong gateway. Compare the failed external HTTPS connection with internal DNS and file access. Restore the original route, or return to DHCP, renew, and confirm DHCP option 003 points to `10.77.0.1`. Retest the same external destination and the internal services. If the lab has no working router, leave this ticket pending.

**For the employee.** Tell the help desk whether you can still open the shared drive when websites go down.

## File Access

### T16 / KB16 - Missing department group membership

**hr04 · Normal** — “I can sign in, but Windows won’t let me open the HR folder.”

Record the user’s membership and remove `hr04` from `GG_HR`. Sign out and back in as that user before opening `\\FS01\HR`. Compare `whoami /groups` with `Get-ADPrincipalGroupMembership hr04`. Check that `GG_HR` belongs to `DL_HR_Modify` and that the resource group has both SMB and NTFS access.

Restore the approved membership with `Add-ADGroupMember GG_HR hr04`. Start a fresh sign-in and check that the user can read, create, and delete a test file in HR. Try Finance as the same user to confirm it denies access.

**For the employee.** Ask your department to approve the access request. You may need to sign out and back in once it’s granted.

### T17 / KB17 - NTFS permissions missing despite share permission

**finance04 · Normal** — “I can see the Finance share, but I get an access-denied message when I open it.”

On FS01, save the Finance folder’s permissions as SDDL and take a screenshot. Remove only the NTFS Allow entry for `DL_Finance_Modify`. Keep SYSTEM and administrator access. Compare `Get-SmbShareAccess Finance` with `(Get-Acl C:\LabShares\Finance).Access`. The group still has share access, and its folder-level Modify entry is missing.

Restore the saved, inheritable Modify entry for `CORP\DL_Finance_Modify` and compare the restored permissions with the baseline. As `finance04`, create, edit, and delete a Finance test file and confirm that access to another department is denied.

**For the employee.** Include the folder name and exact error when you report a shared folder you can see but can’t open.

### T18 / KB18 - Share permission missing despite NTFS permission

**sales04 · Normal** — “I’m supposed to have access to Sales, but the folder won’t open from my computer.”

On FS01, save the output of `Get-SmbShareAccess Sales`, then run `Revoke-SmbShareAccess -Name Sales -AccountName 'CORP\DL_Sales_Modify' -Force`. Test from a client so the request goes through the share. The NTFS Modify permission is still present even though the SMB permission is missing.

Restore it with `Grant-SmbShareAccess -Name Sales -AccountName 'CORP\DL_Sales_Modify' -AccessRight Change -Force`. Confirm the share permissions match the baseline. Check that `sales04` can edit a file over the network and gets access denied when opening another department’s folder.

**For the employee.** Send the full folder path, such as `\\FS01\Sales`, and the exact error message.

### T19 / KB19 - Stale group token after access granted

**operations04 · Low** — “I was told I have access now, but I still can’t open the Operations folder.”

Remove `operations04` from `GG_Operations` and sign in as that user. Add the membership back on DC01 while the user is still signed in. Check Active Directory and `whoami /groups` side by side. Active Directory has the group, but the current Windows session started before the grant.

Save any open work, sign out fully, sign back in, and reconnect the share. Confirm the group appears in the new session, the Operations folder opens, and access to unrelated shares is denied. Check that the original membership is in place when you finish.

**For the employee.** Save your work and sign out all the way. A fresh sign-in lets Windows pick up the new access.

### T20 / KB20 - Read-only Public share mistaken for a writable folder

**it04 · Low** — “I can open files in Public, but it won’t let me save one there.”

As an administrator, put a test `ReadMe.txt` in Public. As `it04`, open it and then try creating a file in `\\FS01\Public`. Check that the share grants SMB Read and that the folder grants NTFS ReadAndExecute. Those settings match the intended use of Public.

Explain that Public is for reference material and point the user to `\\FS01\IT`. Confirm that Public allows reading and rejects writes, then verify that the employee can create a file in IT. Remove the exercise files when you finish.

**For the employee.** Open reference files from Public. Save anything you need to edit in your department’s shared folder.
