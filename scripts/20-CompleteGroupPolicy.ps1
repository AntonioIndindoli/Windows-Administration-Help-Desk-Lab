#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
Import-Module GroupPolicy
if($env:COMPUTERNAME -ne 'DC01' -or (Get-ADDomain).DNSRoot -ne 'corp.example.test'){throw 'Lab DC01 only'}
$base='DC=corp,DC=example,DC=test'
function New-LabPolicy($Name,$Target){
 if(Get-GPO -Name $Name -ErrorAction SilentlyContinue){throw "Policy already exists: $Name. Review before modifying."}
 $g=New-GPO -Name $Name
 New-GPLink -Guid $g.Id -Target $Target -LinkEnabled Yes -Order 1|Out-Null
 $g
}
$g=New-LabPolicy 'Lab-Domain-Account-Policy' $base
$guid='{'+$g.Id.ToString().ToUpper()+'}'
$path="C:\Windows\SYSVOL\sysvol\corp.example.test\Policies\$guid"
New-Item "$path\Machine\Microsoft\Windows NT\SecEdit" -ItemType Directory -Force|Out-Null
$template=@'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[System Access]
MinimumPasswordLength = 14
PasswordComplexity = 1
PasswordHistorySize = 24
LockoutBadCount = 5
ResetLockoutCount = 15
LockoutDuration = 15
'@
$template|Set-Content "$path\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf" -Encoding Unicode
Set-ADObject "CN=$guid,CN=Policies,CN=System,$base" -Replace @{gPCMachineExtensionNames='[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]';versionNumber=1}
"[General]`r`nVersion=1`r`n"|Set-Content "$path\GPT.INI" -Encoding ASCII
Get-GPOReport -Guid $g.Id -ReportType Html -Path C:\LabEvidence\domain-account-gpo.html

$g=New-LabPolicy 'Lab-User-Experience' "OU=LabUsers,$base"
$guid='{'+$g.Id.ToString().ToUpper()+'}'
$path="C:\Windows\SYSVOL\sysvol\corp.example.test\Policies\$guid"
New-Item "$path\User\Preferences\Drives" -ItemType Directory -Force|Out-Null
$doc=New-Object Xml.XmlDocument
$root=$doc.CreateElement('Drives');$root.SetAttribute('clsid','{8FDDCC1A-0C3C-43CD-A6B4-71A6DF20DA8C}');[void]$doc.AppendChild($root)
foreach($dept in 'Public','IT','HR','Finance','Sales','Operations'){
 $letter=if($dept -eq 'Public'){'P'}else{'H'}
 $drive=$doc.CreateElement('Drive')
 foreach($pair in @{clsid='{935D1B74-9CB8-4E3C-9914-7DD559B7A417}';name="${letter}:";status="${letter}:";image='2';changed=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss');uid=('{'+[guid]::NewGuid().ToString().ToUpper()+'}');userContext='1';bypassErrors='1'}.GetEnumerator()){$drive.SetAttribute($pair.Key,$pair.Value)}
 $props=$doc.CreateElement('Properties')
 foreach($pair in @{action='U';thisDrive='NOCHANGE';allDrives='NOCHANGE';userName='';path="\\FS01\$dept";label="Lab $dept";persistent='0';useLetter='1';letter=$letter}.GetEnumerator()){$props.SetAttribute($pair.Key,$pair.Value)}
 [void]$drive.AppendChild($props)
 if($dept -ne 'Public'){
  $filters=$doc.CreateElement('Filters');$filter=$doc.CreateElement('FilterGroup')
  foreach($pair in @{bool='AND';not='0';name="CORP\GG_$dept";sid=(Get-ADGroup "GG_$dept").SID.Value;userContext='1';primaryGroup='0';localGroup='0'}.GetEnumerator()){$filter.SetAttribute($pair.Key,$pair.Value)}
  [void]$filters.AppendChild($filter);[void]$drive.AppendChild($filters)
 }
 [void]$root.AppendChild($drive)
}
$doc.Save("$path\User\Preferences\Drives\Drives.xml")
Set-ADObject "CN=$guid,CN=Policies,CN=System,$base" -Replace @{gPCUserExtensionNames='[{00000000-0000-0000-0000-000000000000}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}][{5794DAFD-BE60-433F-88A2-1A31939AC01F}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}]';versionNumber=65536}
"[General]`r`nVersion=65536`r`n"|Set-Content "$path\GPT.INI" -Encoding ASCII
Get-GPOReport -Guid $g.Id -ReportType Html -Path C:\LabEvidence\user-experience-gpo.html
gpupdate /target:computer /force /wait:60
Get-ADDefaultDomainPasswordPolicy|Select MinPasswordLength,ComplexityEnabled,PasswordHistoryCount,LockoutThreshold,LockoutDuration,LockoutObservationWindow|ConvertTo-Json|Set-Content C:\LabEvidence\final-account-policy.json
