#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$CsvPath, [Parameter(Mandatory)][string]$CredentialOutputPath)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain
if ($domain.DNSRoot -ne 'corp.example.test') { throw 'Lab domain required.' }
$rows = @(Import-Csv -LiteralPath $CsvPath)
if ($rows.Count -ne 30) { throw 'Expected exactly 30 test accounts.' }
$seen = @{}
foreach ($row in $rows) {
    if ($row.SamAccountName -notmatch '^[a-z][a-z0-9.]{2,19}$' -or -not $row.GivenName -or -not $row.Surname) { throw 'Invalid account row.' }
    if ($seen.ContainsKey($row.SamAccountName)) { throw "Duplicate account: $($row.SamAccountName)" }
    $seen[$row.SamAccountName] = $true
    if ($row.Department -notin @('IT','HR','Finance','Sales','Operations')) { throw 'Unknown department.' }
    Get-ADGroup -Identity "GG_$($row.Department)" | Out-Null
}
$output = [IO.Path]::GetFullPath($CredentialOutputPath)
if ($output.StartsWith('\\')) { throw 'Use a local credential output path.' }
if (Test-Path -LiteralPath $output) { throw 'Credential output already exists; choose a new path to avoid losing credentials.' }
if ($WhatIfPreference) {
    foreach ($row in $rows) { [void]$PSCmdlet.ShouldProcess($row.SamAccountName,'Create if missing and add department membership') }
    return
}
$parent = Split-Path $output -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
# Restrict the credential file itself before writing any passwords.
New-Item -ItemType File -Path $output | Out-Null
$acl = New-Object System.Security.AccessControl.FileSecurity
$acl.SetAccessRuleProtection($true,$false)
foreach ($sid in 'S-1-5-18','S-1-5-32-544') {
    $identity = New-Object System.Security.Principal.SecurityIdentifier($sid)
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($identity,'FullControl','Allow')))
}
Set-Acl -LiteralPath $output -AclObject $acl
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
    foreach ($row in $rows) {
        $sam = $row.SamAccountName
        if (-not $PSCmdlet.ShouldProcess($sam,'Create if missing and add department membership')) { continue }
        $user = Get-ADUser -Filter "SamAccountName -eq '$sam'"
        if (-not $user) {
            $bytes = New-Object byte[] 24
            $rng.GetBytes($bytes)
            $password = 'Aa1!' + [Convert]::ToBase64String($bytes)
            $upn = "$sam@$($domain.DNSRoot)"
            # Persist recovery credentials first; a failed AD creation may leave an unused export row.
            [pscustomobject]@{SamAccountName=$sam;UserPrincipalName=$upn;InitialPassword=$password} | Export-Csv -LiteralPath $output -NoTypeInformation -Append
            New-ADUser -Name "$($row.GivenName) $($row.Surname)" -GivenName $row.GivenName -Surname $row.Surname -SamAccountName $sam -UserPrincipalName $upn -Department $row.Department -Path "OU=LabUsers,$($domain.DistinguishedName)" -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
            $password = $null
        }
        $group = "GG_$($row.Department)"
        if ((Get-ADGroupMember $group).SamAccountName -notcontains $sam) { Add-ADGroupMember $group $sam }
    }
} finally { $rng.Dispose() }
Write-Host "Provisioning complete. Secure credential export: $output"
