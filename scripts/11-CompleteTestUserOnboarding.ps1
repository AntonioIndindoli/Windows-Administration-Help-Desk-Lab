#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding()]
param([string]$InitialCredentials='C:\LabSecrets\initial-users.csv',
      [string]$WorkingCredentials='C:\LabSecrets\working-users.csv')
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
if($env:COMPUTERNAME -ne 'DC01' -or (Get-ADDomain).DNSRoot -ne 'corp.example.test'){throw 'Lab DC01 only'}
if(Test-Path $WorkingCredentials){throw 'Working credential export exists; inspect prior results before resuming.'}
$rows=@(Import-Csv -LiteralPath $InitialCredentials)
if($rows.Count -ne 30){throw 'Expected 30 initial credentials'}
Add-Type @'
using System.Runtime.InteropServices;
public static class LabPasswordChange {
    [DllImport("netapi32.dll", CharSet=CharSet.Unicode)]
    public static extern uint NetUserChangePassword(string domainname, string username, string oldpassword, string newpassword);
}
'@
$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
$results=@()
try {
    foreach($row in $rows){
        $bytes=New-Object byte[] 24
        $rng.GetBytes($bytes)
        $newPassword='Aa1!'+[Convert]::ToBase64String($bytes)
        # Persist recovery material before changing the password; no credentials are written to evidence.
        [pscustomobject]@{SamAccountName=$row.SamAccountName;UserPrincipalName=$row.UserPrincipalName;Password=$newPassword}|Export-Csv -LiteralPath $WorkingCredentials -NoTypeInformation -Append
        $status=[LabPasswordChange]::NetUserChangePassword('corp.example.test',$row.SamAccountName,$row.InitialPassword,$newPassword)
        $newPassword=$null
        $results += [pscustomobject]@{Time=(Get-Date -Format o);SamAccountName=$row.SamAccountName;PasswordChangeStatus=$status}
        $results|Export-Csv C:\LabEvidence\onboarding-password-changes.csv -NoTypeInformation
        if($status -ne 0){throw "User password-change API returned $status for $($row.SamAccountName). Inspect protected exports before retrying."}
    }
} finally {$rng.Dispose()}
$results|Format-Table -AutoSize
