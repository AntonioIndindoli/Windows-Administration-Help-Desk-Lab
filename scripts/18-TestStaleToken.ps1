# Start after removing operations04 from GG_Operations. Keep this process alive while restoring membership.
$ErrorActionPreference='Stop'
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class TokenAuth {
 [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] public static extern bool LogonUser(string u,string d,string p,int t,int r,out IntPtr h);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
'@
$cred=Import-Csv C:\LabSecrets\working-users.csv|Where-Object SamAccountName -eq operations04
$h=[IntPtr]::Zero
if(-not[TokenAuth]::LogonUser('operations04','CORP',$cred.Password,2,0,[ref]$h)){throw 'Initial logon failed'}
$id=New-Object Security.Principal.WindowsIdentity($h)
function Test-OldToken {
 $ctx=$id.Impersonate()
 try{$allowed=$false;try{[void][IO.Directory]::GetFiles('\\FS01.corp.example.test\Operations');$allowed=$true}catch{};[pscustomobject]@{identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name;allowed=$allowed;groups=@($id.Groups|ForEach-Object Value)}}finally{$ctx.Undo();$ctx.Dispose()}
}
try{
 $before=Test-OldToken;if($before.allowed){throw 'Initial missing-membership fault not observed'}
 [pscustomobject]@{exercise='T19';time=(Get-Date -Format o);before_grant=$before}|ConvertTo-Json -Depth 6|Set-Content C:\LabEvidence\T19-observations.json
 Set-Content C:\LabEvidence\T19-ready.txt ready
 $deadline=(Get-Date).AddMinutes(5)
 while(-not(Test-Path C:\LabEvidence\T19-continue.txt)){if((Get-Date)-gt $deadline){throw 'Timed out waiting for membership restoration'};Start-Sleep -Seconds 1}
 $after=Test-OldToken
 if($after.allowed){throw 'Old SMB token unexpectedly refreshed; T19 not reproduced'}
 $r=Get-Content C:\LabEvidence\T19-observations.json|ConvertFrom-Json;$r|Add-Member after_grant_old_token $after;$r|Add-Member fault_observed $true;$r|ConvertTo-Json -Depth 7|Set-Content C:\LabEvidence\T19-observations.json
}finally{$id.Dispose();[void][TokenAuth]::CloseHandle($h)}
& C:\Lab\15-TestShareAsUser.ps1 -User operations04 -Share Operations -Expected Modify -Label T19-new-logon
$r=Get-Content C:\LabEvidence\T19-observations.json|ConvertFrom-Json;$r|Add-Member repair_verified $true;$r|Add-Member baseline_restored $true;$r|ConvertTo-Json -Depth 7|Set-Content C:\LabEvidence\T19-observations.json
