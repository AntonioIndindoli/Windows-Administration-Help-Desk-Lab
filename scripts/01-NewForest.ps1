#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InterfaceAlias, [string]$Gateway,
      [Security.SecureString]$SafeModeAdministratorPassword)
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ne 'DC01') { throw 'Rename this dedicated lab VM to DC01 and restart first.' }
if ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4) { throw 'This machine is already a domain controller.' }
$adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
if ($adapter.Status -ne 'Up') { throw 'Selected adapter is not up.' }
$current = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($current | Where-Object { $_.PrefixOrigin -eq 'Manual' -and $_.IPAddress -ne '10.77.0.10' }) {
    throw 'An unexpected static IPv4 address exists. Review NIC settings manually before proceeding.'
}
Set-NetIPInterface -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Dhcp Disabled
if (-not ($current | Where-Object IPAddress -eq '10.77.0.10')) {
    $ip = @{ InterfaceAlias=$InterfaceAlias; IPAddress='10.77.0.10'; PrefixLength=24 }
    if ($Gateway) { $ip.DefaultGateway = $Gateway }
    New-NetIPAddress @ip | Out-Null
}
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses '10.77.0.10'
Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools | Out-Null
Import-Module ADDSDeployment
$dsrm = $SafeModeAdministratorPassword
if (-not $dsrm) { $dsrm = Read-Host 'Directory Services Restore Mode password' -AsSecureString }
Install-ADDSForest -DomainName 'corp.example.test' -DomainNetbiosName 'CORP' -InstallDNS -SafeModeAdministratorPassword $dsrm -Force
