#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$RootPath='C:\LabShares')
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ne 'FS01' -or (Get-CimInstance Win32_ComputerSystem).Domain -ne 'corp.example.test') { throw 'Run on domain-joined FS01.' }
if(-not(Get-NetFirewallRule -Name Lab-SMB-Domain -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name Lab-SMB-Domain -DisplayName 'Lab SMB from domain clients' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Profile Domain -RemoteAddress 10.77.0.0/24 | Out-Null
}
foreach ($dept in 'IT','HR','Finance','Sales','Operations','Public') {
    $path = Join-Path $RootPath $dept
    if (Test-Path $path) { throw "Path already exists: $path. Review existing ACLs manually; this script only creates new resources." }
    if (Get-SmbShare -Name $dept -ErrorAction SilentlyContinue) { throw "Share already exists: $dept" }
}
foreach ($dept in 'IT','HR','Finance','Sales','Operations','Public') {
    $path = Join-Path $RootPath $dept
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in 'S-1-5-18','S-1-5-32-544') {
        $identity = New-Object System.Security.Principal.SecurityIdentifier($sid)
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
    }
    $principal = if ($dept -eq 'Public') {'CORP\Domain Users'} else {"CORP\DL_${dept}_Modify"}
    $rights = if ($dept -eq 'Public') {'ReadAndExecute'} else {'Modify'}
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($principal,$rights,'ContainerInherit,ObjectInherit','None','Allow')))
    Set-Acl -LiteralPath $path -AclObject $acl
    $share = @{Name=$dept;Path=$path;FullAccess='CORP\Domain Admins';FolderEnumerationMode='AccessBased'}
    if ($dept -eq 'Public') { $share.ReadAccess=$principal } else { $share.ChangeAccess=$principal }
    New-SmbShare @share | Out-Null
}
Write-Host 'Created department Modify shares and Public read-only share. Test with ordinary users.'
