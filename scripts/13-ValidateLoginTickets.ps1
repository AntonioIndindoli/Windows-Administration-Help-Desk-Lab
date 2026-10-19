#Requires -RunAsAdministrator
#Requires -Version 5.1
# Live domain authentication tests. No results are emitted until fault and repair assertions pass.
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
if($env:COMPUTERNAME -ne 'DC01' -or (Get-ADDomain).DNSRoot -ne 'corp.example.test'){throw 'Lab DC01 only'}
$credentialPath='C:\LabSecrets\working-users.csv'
$credentials=@(Import-Csv $credentialPath)
$policy=Get-ADDefaultDomainPasswordPolicy
if($policy.LockoutThreshold -ne 5){throw 'Expected verified five-attempt lockout policy'}
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class LabAuth {
 [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)]
 public static extern bool LogonUser(string user,string domain,string password,int type,int provider,out IntPtr token);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
 [DllImport("netapi32.dll",CharSet=CharSet.Unicode)]
 public static extern uint NetUserChangePassword(string domain,string user,string oldpassword,string newpassword);
}
'@
function Authenticate([string]$User,[string]$Password){
    $token=[IntPtr]::Zero
    $ok=[LabAuth]::LogonUser($User,'CORP',$Password,3,0,[ref]$token)
    $code=if($ok){0}else{[Runtime.InteropServices.Marshal]::GetLastWin32Error()}
    if($token -ne [IntPtr]::Zero){[void][LabAuth]::CloseHandle($token)}
    [pscustomobject]@{Success=$ok;Win32Error=$code}
}
function Get-Password([string]$User){($credentials|Where-Object SamAccountName -eq $User).Password}
function New-Password {
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create();$bytes=New-Object byte[] 24
    try{$rng.GetBytes($bytes);'Aa1!'+[Convert]::ToBase64String($bytes)}finally{$rng.Dispose()}
}
$results=@()
$raw=@()
function Save-Result($Result,$Observation){
    $script:results+= $Result
    $script:raw+= $Observation
    $script:results|ConvertTo-Json -Depth 6|Set-Content C:\LabEvidence\login-ticket-results.json
    $script:raw|ConvertTo-Json -Depth 6|Set-Content C:\LabEvidence\login-ticket-observations.json
}
$user='it01';$pw=Get-Password $user
if(-not(Authenticate $user $pw).Success){throw 'it01 baseline authentication failed'}
$attempts=@();for($i=0;$i -lt 5;$i++){$attempts+=Authenticate $user 'Intentionally-Wrong-Lab-Password!'}
$locked=(Get-ADUser $user -Properties LockedOut).LockedOut
if(-not $locked){throw 'T01 fault was not reproduced'}
Unlock-ADAccount $user
$retest=Authenticate $user $pw
if(-not $retest.Success -or (Get-ADUser $user -Properties LockedOut).LockedOut){throw 'T01 repair failed'}
Save-Result ([pscustomobject]@{exercise='T01';fault_observed=$true;repair_verified=$true;baseline_restored=$true;symptom='Correct domain credentials rejected after five failed authentication attempts.';cause='The configured account-lockout threshold was reached.';resolution='Verified the test identity and account state, unlocked it01, then authenticated with the correct credential.';verification='LockedOut changed from true to false and Windows network logon returned success.';evidence='evidence/login-ticket-observations.json';client_guidance='Stop retrying old passwords and ask the help desk for verified assistance.'}) ([pscustomobject]@{exercise='T01';time=(Get-Date -Format o);user=$user;failed_attempts=$attempts;locked_before_repair=$locked;retest=$retest})

$user='hr01';$old=Get-Password $user
if(-not(Authenticate $user $old).Success){throw 'hr01 baseline failed'}
$temporary=New-Password;$final=New-Password
Set-ADAccountPassword $user -Reset -NewPassword (ConvertTo-SecureString $temporary -AsPlainText -Force)
Set-ADUser $user -ChangePasswordAtLogon $true
$failure=Authenticate $user $old
if($failure.Success){throw 'T02 old credential unexpectedly worked'}
# Preserve the replacement secret in protected storage before its authenticated change.
($credentials|Where-Object SamAccountName -eq $user).Password=$final
$credentials|Export-Csv $credentialPath -NoTypeInformation
$change=[LabAuth]::NetUserChangePassword('corp.example.test',$user,$temporary,$final)
$retest=Authenticate $user $final
if($change -ne 0 -or -not $retest.Success){throw "T02 password change/retest failed: $change"}
Save-Result ([pscustomobject]@{exercise='T02';fault_observed=$true;repair_verified=$true;baseline_restored=$true;symptom='The requester could not authenticate with the old credential.';cause='The submitted credential no longer matched the account password.';resolution='Reset to a unique temporary credential with change required, then completed an authenticated user password change.';verification='Old credential failed, NetUserChangePassword returned zero and the replacement credential authenticated successfully.';evidence='evidence/login-ticket-observations.json';client_guidance='Request a verified reset and keep passwords out of support tickets.'}) ([pscustomobject]@{exercise='T02';time=(Get-Date -Format o);user=$user;old_credential_rejected=$failure;password_change_status=$change;retest=$retest})

$user='finance01';$pw=Get-Password $user
if(-not(Authenticate $user $pw).Success){throw 'finance01 baseline failed'}
try{Disable-ADAccount $user;$failure=Authenticate $user $pw;$disabled=-not(Get-ADUser $user).Enabled;if($failure.Success -or -not $disabled){throw 'T03 fault not reproduced'}}finally{Enable-ADAccount $user}
$retest=Authenticate $user $pw
if(-not $retest.Success -or -not(Get-ADUser $user).Enabled){throw 'T03 repair failed'}
Save-Result ([pscustomobject]@{exercise='T03';fault_observed=$true;repair_verified=$true;baseline_restored=$true;symptom='Domain authentication failed for an otherwise correct credential.';cause='The test account was disabled.';resolution='Checked the approved lab account state and enabled finance01.';verification='Disabled account authentication failed; after enabling, the same credential succeeded.';evidence='evidence/login-ticket-observations.json';client_guidance='Disabled accounts require an account-lifecycle review by the help desk.'}) ([pscustomobject]@{exercise='T03';time=(Get-Date -Format o);user=$user;disabled_before_repair=$disabled;failure=$failure;retest=$retest})

$user='sales01';$pw=Get-Password $user
if(-not(Authenticate $user $pw).Success){throw 'sales01 baseline failed'}
try{Set-ADAccountExpiration $user -DateTime (Get-Date).AddDays(-1);$failure=Authenticate $user $pw;$expired=(Get-ADUser $user -Properties AccountExpirationDate).AccountExpirationDate -lt (Get-Date);if($failure.Success -or -not $expired){throw 'T04 fault not reproduced'}}finally{Clear-ADAccountExpiration $user}
$retest=Authenticate $user $pw
if(-not $retest.Success -or (Get-ADUser $user -Properties AccountExpirationDate).AccountExpirationDate){throw 'T04 repair failed'}
Save-Result ([pscustomobject]@{exercise='T04';fault_observed=$true;repair_verified=$true;baseline_restored=$true;symptom='Domain authentication failed after the account expiration date.';cause='The lab account expiration was in the past.';resolution='Reviewed expiration and cleared it for this permanent test account.';verification='Expired account rejected authentication; cleared expiration and successful network logon confirmed recovery.';evidence='evidence/login-ticket-observations.json';client_guidance='Provide the relevant access authorization when requesting an account extension.'}) ([pscustomobject]@{exercise='T04';time=(Get-Date -Format o);user=$user;expired_before_repair=$expired;failure=$failure;retest=$retest})
$results|Select-Object exercise,fault_observed,repair_verified,baseline_restored|Format-Table
