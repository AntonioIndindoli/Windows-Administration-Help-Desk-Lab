# 20 support tickets and knowledge base solutions

All exercises start **Not run**. Each entry is both a ticket brief and the source for one FAQ. Proposed causes and repairs are instructor guidance, not observed results. Capture actual diagnostics and test the repair before closing a ticket. Use PC01 unless specified, local console access for network faults, and a dedicated test account. Restore only the change made after each exercise.

## T01 / KB01 - Account locked out

**Category:** Login. **User:** it01. **Priority:** Normal.

**Symptom / inject:** Enter an incorrect password five times after lockout policy is verified. The domain account cannot sign in.

**Diagnose:** On DC01 use `Search-ADAccount -LockedOut` and inspect Security event 4740 if account-management auditing is enabled. Confirm the affected account and caller machine; do not assume every sign-in failure is a lockout.

**Expected cause / repair:** Lockout threshold reached. After validating the requester, run `Unlock-ADAccount it01`. Remove the stale credential or scheduled task if one keeps retrying.

**Verify / rollback:** Correct password signs in and lockout does not recur. If locked again, investigate the retry source. No policy rollback needed. **Client FAQ:** Stop retrying old passwords and contact the help desk for identity verification.

## T02 / KB02 - Forgotten password

**Category:** Login. **User:** hr01. **Priority:** Normal.

**Symptom / inject:** Simulate a requester who cannot recall the account password; do not record real passwords in the ticket.

**Diagnose:** Verify identity, account spelling, enabled/locked state, and that the client reaches DC01.

**Expected cause / repair:** Forgotten credential. Use AD Users and Computers → Reset Password; generate a new unique temporary password and require change at next sign-in. Deliver it through a separate secure channel.

**Verify / rollback:** User signs in, changes the temporary password, and signs in again. Remove any temporary credential record. **Client FAQ:** Request a verified reset; never send passwords in tickets.

## T03 / KB03 - Disabled account

**Category:** Login. **User:** finance01. **Priority:** Normal.

**Symptom / inject:** On DC01 `Disable-ADAccount finance01`; interactive domain sign-in fails.

**Diagnose:** `Get-ADUser finance01 -Properties Enabled` and review the authorized account lifecycle status.

**Expected cause / repair:** Account disabled for this exercise. With the lab request authorized, `Enable-ADAccount finance01`.

**Verify / rollback:** Enabled is true and a fresh sign-in succeeds. Leave the baseline account enabled. **Client FAQ:** Disabled accounts require help desk review, not repeated password attempts.

## T04 / KB04 - Account expired

**Category:** Login. **User:** sales01. **Priority:** Normal.

**Symptom / inject:** `Set-ADAccountExpiration sales01 -DateTime (Get-Date).AddDays(-1)` on DC01.

**Diagnose:** `Get-ADUser sales01 -Properties AccountExpirationDate,Enabled,LockedOut`; distinguish expiration from password expiration.

**Expected cause / repair:** Account expiration date passed. For this permanent test account run `Clear-ADAccountExpiration sales01`; for a real contractor use the approved extension date.

**Verify / rollback:** Expiration cleared and sign-in succeeds. **Client FAQ:** Provide employment/access authorization when requesting an extension.

## T05 / KB05 - Local account used instead of domain account

**Category:** Login. **User:** operations01. **Priority:** Low.

**Symptom / inject:** At sign-in enter `.\operations01` rather than the domain identity; no matching local account exists.

**Diagnose:** Check the sign-in domain indicator. On a working session, `whoami` identifies the actual security principal.

**Expected cause / repair:** Wrong account namespace. Select Other user and use `CORP\operations01` or `operations01@corp.example.test`.

**Verify / rollback:** `whoami` returns `corp\operations01` and expected domain resources work. No configuration change. **Client FAQ:** Use the domain username format provided at onboarding.

## T06 / KB06 - Client points to the wrong DNS server

**Category:** DNS. **User:** it02. **Priority:** High.

**Symptom / inject:** On PC01 only, set NIC DNS to unused `10.77.0.99`. Domain names fail to resolve.

**Diagnose:** `ipconfig /all`; `Resolve-DnsName DC01.corp.example.test`; compare with `Resolve-DnsName DC01.corp.example.test -Server 10.77.0.10`.

**Expected cause / repair:** Client DNS misconfiguration. Reset the client adapter DNS to DHCP with `Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ResetServerAddresses` (substitute the actual alias). Confirm DHCP supplies .10; flush cache.

**Verify / rollback:** Resolve DC01 and LDAP SRV records using default DNS; sign in and reach FS01. **Client FAQ:** Leave managed DNS automatic; public resolvers do not serve internal AD records.

## T07 / KB07 - Incorrect application A record

**Category:** DNS. **User:** hr02. **Priority:** Normal.

**Symptom / inject:** Record the baseline `helpdesk` A record, then edit only that record to unused .99 in DNS Manager.

**Diagnose:** `Resolve-DnsName helpdesk.corp.example.test -Server 10.77.0.10`; compare returned IP with HD01's actual .30 address.

**Expected cause / repair:** Incorrect DNS host record. Restore .30 in DNS Manager and flush the client's cache with `ipconfig /flushdns`.

**Verify / rollback:** Resolution returns .30 and HTTPS loads the help desk with its trusted certificate. Baseline record restored. **Client FAQ:** Report the exact application hostname when a site becomes unreachable.

## T08 / KB08 - Hosts file overrides DNS

**Category:** DNS. **User:** finance02. **Priority:** Normal.

**Symptom / inject:** Back up PC01's hosts file, then add `10.77.0.99 helpdesk.corp.example.test` using an elevated editor.

**Diagnose:** DNS server lookup returns .30, but application resolution uses .99. Inspect `C:\Windows\System32\drivers\etc\hosts` for that hostname.

**Expected cause / repair:** Stale local override. Remove only the injected line, preserve other entries, then flush DNS cache.

**Verify / rollback:** Application connects to .30 and the hosts file matches its baseline. **Client FAQ:** Do not add local hostname overrides to fix managed services.

## T09 / KB09 - Negative DNS cache after record creation

**Category:** DNS. **User:** sales02. **Priority:** Low.

**Symptom / inject:** Query nonexistent `kbtest.corp.example.test` on PC01. Then create an A record `kbtest` → .30 on DC01 and promptly retry on the client.

**Diagnose:** Compare client cache (`Get-DnsClientCache`) with a direct server lookup. If the negative cache already expired and the fault does not reproduce, record that outcome rather than claiming a failure.

**Expected cause / repair:** Cached name-not-found response. `Clear-DnsClientCache` after confirming the authoritative record exists.

**Verify / rollback:** Fresh resolution returns .30. Delete only the `kbtest` test record afterward. **Client FAQ:** DNS changes can take time; the help desk can verify and refresh local cached results.

## T10 / KB10 - Short hostname fails; FQDN works

**Category:** DNS. **User:** operations02. **Priority:** Low.

**Symptom / inject:** In an elevated PowerShell process on PC01, save `Get-DnsClientGlobalSetting`, then temporarily set suffix search list to `invalid.test`. Query `FS01` and its FQDN separately. Domain suffix fallback may prevent reproduction; record the observed result.

**Diagnose:** Inspect `ipconfig /all`, `Get-DnsClientGlobalSetting`, and `Resolve-DnsName FS01.corp.example.test`.

**Expected cause / repair:** Incorrect suffix search configuration if reproduced. Restore the saved suffix-search configuration or explicitly configure `corp.example.test` for this lab, consistent with the baseline policy.

**Verify / rollback:** Both short name and FQDN resolve to FS01. Restore the original global setting after the exercise. **Client FAQ:** Give the help desk the full server name when only short names fail.

## T11 / KB11 - APIPA / no DHCP lease

**Category:** Connectivity. **User:** it03. **Priority:** High.

**Symptom / inject:** With PC01 powered off, attach its NIC to a separate empty private switch without DHCP, boot, then renew IPv4.

**Diagnose:** `ipconfig /all` shows 169.254.x.x or no usable IPv4 lease. Check switch attachment before changing server settings; PC02 should still obtain a lease.

**Expected cause / repair:** Client attached to the wrong virtual network. Power off, reconnect PC01 to HelpDeskLab, boot, and run `ipconfig /renew`.

**Verify / rollback:** .100–.199 lease, /24 mask, DNS .10, AD name resolution. Correct switch restored. **Client FAQ:** Report loss of all internal services; do not assign an arbitrary address.

## T12 / KB12 - Incorrect subnet mask

**Category:** Connectivity. **User:** hr03. **Priority:** High.

**Symptom / inject:** Record PC01's current configuration, then assign static .150 with /30 mask and no gateway; use .150 only after confirming it is unused and temporarily excluded from DHCP.

**Diagnose:** Compare `Get-NetIPConfiguration` and routes with baseline /24. DC01 .10 is outside the erroneous local subnet.

**Expected cause / repair:** Wrong static mask. Restore DHCP addressing with `Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -Dhcp Enabled`, reset DNS to DHCP, and renew. Remove any leftover injected manual address if it remains.

**Verify / rollback:** Client has /24 lease and reaches DC01 and FS01. Remove temporary DHCP exclusion only after .150 is no longer manually assigned. **Client FAQ:** Keep managed network settings automatic.

## T13 / KB13 - Disabled client network adapter

**Category:** Connectivity. **User:** finance03. **Priority:** High.

**Symptom / inject:** From PC01's VM console disable its lab NIC in Network Connections. Never perform this on the physical host.

**Diagnose:** `Get-NetAdapter` shows Disabled and all network services fail.

**Expected cause / repair:** Disabled virtual adapter. Enable the same adapter from the VM console; confirm its virtual cable is connected.

**Verify / rollback:** Adapter Up, DHCP lease present, domain DNS and SMB work. **Client FAQ:** Report whether the network icon indicates a disconnected adapter.

## T14 / KB14 - SMB blocked on one client

**Category:** Connectivity. **User:** sales03. **Priority:** Normal.

**Symptom / inject:** Create a named outbound firewall block on PC01 only: `New-NetFirewallRule -DisplayName 'Lab-T14' -Direction Outbound -Action Block -Protocol TCP -RemotePort 445 -RemoteAddress 10.77.0.20`.

**Diagnose:** DNS works but `Test-NetConnection FS01 -Port 445` fails; inspect the named rule. Compare PC02.

**Expected cause / repair:** Injected port block. `Remove-NetFirewallRule -DisplayName 'Lab-T14'`. Keep the firewall enabled.

**Verify / rollback:** Port 445 connects and an authorized user opens their share. Confirm injected rule is gone. **Client FAQ:** Report which service fails even if other services still work.

## T15 / KB15 - Invalid default gateway (optional routed lab)

**Category:** Connectivity. **User:** operations03. **Priority:** Normal.

**Symptom / inject:** This exercise requires a working NAT router at .1 and a known reachable external HTTPS destination. Record PC01's default route; replace only its default gateway with unused .254. Do not change the global DHCP scope.

**Diagnose:** Internal DNS/SMB still work; `Get-NetRoute -DestinationPrefix 0.0.0.0/0` shows .254; external HTTPS fails. Distinguish external routing from AD DNS.

**Expected cause / repair:** Invalid next hop. Restore the original route or return to DHCP and renew, confirming DHCP option 003 is .1.

**Verify / rollback:** Internal services and the same external HTTPS destination work. If no router exists, mark this exercise pending until the optional routed environment is built. **Client FAQ:** State whether internal services work when reporting internet loss.

## T16 / KB16 - Missing department group membership

**Category:** File Access. **User:** hr04. **Priority:** Normal.

**Symptom / inject:** Record membership then remove hr04 from GG_HR; sign out/in before testing `\\FS01\HR`.

**Diagnose:** `whoami /groups`, `Get-ADPrincipalGroupMembership hr04`, and GG_HR → DL_HR_Modify nesting. Check both SMB and NTFS permissions.

**Expected cause / repair:** Missing approved global group membership. `Add-ADGroupMember GG_HR hr04`; sign out/in.

**Verify / rollback:** HR read/create/delete succeeds while Finance access remains denied. Baseline membership restored. **Client FAQ:** Access requests require department authorization and may need a fresh sign-in.

## T17 / KB17 - NTFS permissions missing despite share permission

**Category:** File Access. **User:** finance04. **Priority:** Normal.

**Symptom / inject:** On FS01 capture Finance folder ACL as SDDL and in a screenshot; remove only DL_Finance_Modify's Allow entry from NTFS security, preserving SYSTEM/Administrators.

**Diagnose:** `Get-SmbShareAccess Finance` still permits the resource group. `(Get-Acl C:\LabShares\Finance).Access` lacks its Modify entry.

**Expected cause / repair:** NTFS permission missing. Restore the baseline inheritable Modify entry for CORP\DL_Finance_Modify; preserve all other ACL entries.

**Verify / rollback:** finance04 creates/edits/deletes a test file; another department is denied. Compare restored ACL with baseline. **Client FAQ:** A visible share can still require folder permission review.

## T18 / KB18 - Share permission missing despite NTFS permission

**Category:** File Access. **User:** sales04. **Priority:** Normal.

**Symptom / inject:** Save `Get-SmbShareAccess Sales`, then `Revoke-SmbShareAccess -Name Sales -AccountName 'CORP\DL_Sales_Modify' -Force` on FS01.

**Diagnose:** NTFS Modify is present but SMB access is missing. Test from a client, not locally on FS01.

**Expected cause / repair:** SMB permission missing. `Grant-SmbShareAccess -Name Sales -AccountName 'CORP\DL_Sales_Modify' -AccessRight Change -Force`.

**Verify / rollback:** sales04 can modify a file over SMB; cross-department access fails. Baseline share permission restored. **Client FAQ:** Report the full UNC path and exact access-denied message.

## T19 / KB19 - Stale group token after access granted

**Category:** File Access. **User:** operations04. **Priority:** Low.

**Symptom / inject:** Remove operations04 from GG_Operations, sign in as that user, then add membership back from DC01 without signing out. Test access.

**Diagnose:** AD membership includes the group while `whoami /groups` in the existing user session does not. New logon tokens are required for reliable testing.

**Expected cause / repair:** Existing logon token predates group grant. Save work, sign out fully, and sign back in; reconnect the share.

**Verify / rollback:** Group appears in the token and Operations share works, while unrelated shares remain denied. Ensure original membership remains. **Client FAQ:** Lock/unlock does not reliably refresh newly granted group membership; sign out/in.

## T20 / KB20 - Read-only Public share mistaken for a writable folder

**Category:** File Access. **User:** it04. **Priority:** Low.

**Symptom / inject:** As administrator place `ReadMe.txt` in Public. Ask it04 to open it and then create a file in `\\FS01\Public`.

**Diagnose:** Read succeeds, write is denied. Both SMB Read and NTFS ReadAndExecute match the documented Public design.

**Expected cause / repair:** Expected permission behavior. Explain the read-only purpose and use `\\FS01\IT` for approved departmental collaboration. No permission escalation is needed.

**Verify / rollback:** Public remains readable and rejects writes; IT share allows it04 to create a file. Remove only exercise test files. **Client FAQ:** Public contains published reference material; use the approved department share for edits.
