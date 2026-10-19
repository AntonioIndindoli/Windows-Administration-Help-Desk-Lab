# Group Policy and access model

On DC01 open Group Policy Management (`gpmc.msc`). Back up any existing policy before editing. Do not apply lab policy to your physical host. Create the following named GPOs and record each setting and link in evidence.

| Policy | Link | Settings |
|---|---|---|
| Lab-Domain-Account-Policy | Domain root | Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies: minimum password length 14, complexity enabled, history 24; lockout threshold 5, duration 15 minutes, reset counter 15 minutes. Keep other password defaults unless documenting a deliberate change. |
| Lab-Workstation-Security | Workstations OU | Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options: interactive logon machine inactivity limit 900 seconds. Under Computer Configuration → Policies → Administrative Templates → Network → Network Connections → Windows Defender Firewall, enable domain firewall; retain default outbound allow/inbound block. Confirm policy paths in installed ADMX templates. |
| Lab-User-Experience | LabUsers OU | User Configuration → Preferences → Windows Settings → Drive Maps: Update P: to `\\FS01\Public`. Add an H: Update mapping for each department share, using item-level targeting → Security Group → corresponding `CORP\GG_<department>`. Only one department group per test user. |

Domain password/lockout policy must be linked at the domain root to affect domain accounts. Check precedence/inheritance and `Get-ADDefaultDomainPasswordPolicy`; a fine-grained password policy can override it for selected users. Do not put a test account in Domain Admins. No loopback processing is needed because the user GPO links to the users OU.

Run `gpupdate /force` on clients; sign out/in. Save `gpresult /h C:\LabEvidence\gpresult.html` after creating that folder. Verify the 15-minute lock, mapped drives, firewall state, and resultant password policy. Never disable the firewall globally to fix connectivity; diagnose the required service/profile/rule.

## Group-based permissions

`User → GG_Department (global) → DL_Department_Modify (domain local) → NTFS Modify and SMB Change`.

FS01's local Administrators and SYSTEM have NTFS Full Control. Domain Admins have SMB Full Control. Ordinary department members receive Modify, which permits deletion; Public is Read only for Domain Users. Share and NTFS permissions both apply over SMB. Avoid explicit Deny rules in the baseline. A fresh logon refreshes group membership; an existing SMB connection can also retain credentials.

For every department test one allowed user and one user from another department. Confirm create/read/edit/delete on the allowed share, denial on the other share, and read-but-no-write on Public (seed a public file as administrator). Record `whoami /groups`, `Get-SmbShareAccess`, and `(Get-Acl <folder>).Access` when investigating.
