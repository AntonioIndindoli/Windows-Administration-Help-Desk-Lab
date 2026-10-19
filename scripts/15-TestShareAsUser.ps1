[CmdletBinding()]
param([Parameter(Mandatory)][string]$User,[Parameter(Mandatory)][string]$Share,[ValidateSet('Modify','ReadOnly','Denied')][string]$Expected='Modify',[string]$Label='baseline')
$ErrorActionPreference='Stop'
if($env:COMPUTERNAME -ne 'PC01'){throw 'PC01 only'}
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class ShareAuth {
 [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] public static extern bool LogonUser(string u,string d,string p,int t,int r,out IntPtr h);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
'@
$cred=Import-Csv C:\LabSecrets\working-users.csv|Where-Object SamAccountName -eq $User
if(-not $cred){throw 'Missing protected credential'}
$h=[IntPtr]::Zero
if(-not [ShareAuth]::LogonUser($User,'CORP',$cred.Password,2,0,[ref]$h)){throw "Logon failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"}
$identity=New-Object Security.Principal.WindowsIdentity($h)
$context=$null;$read=$false;$write=$false;$deleted=$false;$errors=@();$path="\\FS01.corp.example.test\$Share";$testFile="$path\Lab-$User-$([guid]::NewGuid().ToString('N')).txt"
try{
 $context=$identity.Impersonate()
 $principal=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 try{[void][IO.Directory]::GetFiles($path);if($Expected -eq 'ReadOnly'){[void][IO.File]::ReadAllText("$path\ReadMe.txt")};$read=$true}catch{$errors+=$_.Exception.Message}
 try{[IO.File]::WriteAllText($testFile,"Lab permission verification for $principal");$write=[IO.File]::ReadAllText($testFile) -like 'Lab permission*';[IO.File]::Delete($testFile);$deleted=-not[IO.File]::Exists($testFile)}catch{$errors+=$_.Exception.Message}
}finally{if($context){$context.Undo();$context.Dispose()};$identity.Dispose();[void][ShareAuth]::CloseHandle($h)}
$pass=switch($Expected){'Modify'{$read -and $write -and $deleted};'ReadOnly'{$read -and -not $write};'Denied'{-not $read -and -not $write}}
$result=[pscustomobject]@{time=(Get-Date -Format o);label=$Label;user=$User;identity=$principal;share=$Share;expected=$Expected;read=$read;write=$write;test_file_removed=$deleted;pass=[bool]$pass;errors=$errors}
$result|ConvertTo-Json -Depth 5|Set-Content "C:\LabEvidence\share-$Label-$User-$Share.json"
$result|ConvertTo-Json -Depth 5
if(-not $pass){throw "Share assertion failed: $User $Share $Expected"}
