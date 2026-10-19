#Requires -RunAsAdministrator
[CmdletBinding()]
param([Parameter(Mandatory)][string]$InterfaceAlias,
      [Parameter(Mandatory)][ValidateSet('FS01','PC01','PC02')][string]$ComputerName,
      [Parameter(Mandatory)][ValidateSet('Servers','Workstations')][string]$TargetOU)
$ErrorActionPreference = 'Stop'
if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) { throw 'Already domain joined; review membership manually.' }
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses 10.77.0.10
Resolve-DnsName -Type SRV '_ldap._tcp.dc._msdcs.corp.example.test' -ErrorAction Stop | Out-Null
$credential = Get-Credential -Message 'Lab domain join credential (CORP\Administrator)'
Add-Computer -DomainName corp.example.test -NewName $ComputerName -OUPath "OU=$TargetOU,DC=corp,DC=example,DC=test" -Credential $credential -Restart -Force
