#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding()]
param([string]$Gateway)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain
if ($domain.DNSRoot -ne 'corp.example.test' -or $env:COMPUTERNAME -ne 'DC01') { throw 'Run on lab DC01 in corp.example.test.' }
$base = $domain.DistinguishedName
foreach ($ou in 'LabUsers','Workstations','Servers','LabGroups') {
    $dn = "OU=$ou,$base"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'")) {
        New-ADOrganizationalUnit -Name $ou -Path $base -ProtectedFromAccidentalDeletion $true
    }
}
foreach ($dept in 'IT','HR','Finance','Sales','Operations') {
    foreach ($spec in @(@("GG_$dept",'Global'),@("DL_${dept}_Modify",'DomainLocal'))) {
        if (-not (Get-ADGroup -Filter "SamAccountName -eq '$($spec[0])'")) {
            New-ADGroup -Name $spec[0] -GroupScope $spec[1] -GroupCategory Security -Path "OU=LabGroups,$base"
        }
    }
    $resource = "DL_${dept}_Modify"
    if ((Get-ADGroupMember $resource).SamAccountName -notcontains "GG_$dept") { Add-ADGroupMember $resource "GG_$dept" }
}
if((Get-WindowsFeature DHCP).InstallState -ne 'Installed') {
    Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null
}
Import-Module DhcpServer
# Creates DHCP Administrators / DHCP Users local security groups if absent.
& netsh dhcp add securitygroups
if ($LASTEXITCODE -ne 0) { Write-Warning 'Review netsh output; groups may already exist.' }
Restart-Service DHCPServer
if (-not (Get-DhcpServerInDC | Where-Object IPAddress -eq '10.77.0.10')) {
    Add-DhcpServerInDC -DnsName 'DC01.corp.example.test' -IPAddress '10.77.0.10'
}
if (-not (Get-DhcpServerv4Scope | Where-Object ScopeId -eq '10.77.0.0')) {
    Add-DhcpServerv4Scope -Name HelpDeskLab -StartRange 10.77.0.100 -EndRange 10.77.0.199 -SubnetMask 255.255.255.0 -State Active
}
Set-DhcpServerv4OptionValue -ScopeId 10.77.0.0 -DnsServer 10.77.0.10 -DnsDomain 'corp.example.test'
if ($Gateway) { Set-DhcpServerv4OptionValue -ScopeId 10.77.0.0 -Router $Gateway }
Write-Host 'Domain OUs, security groups and DHCP configured. Verify the scope/options before connecting clients.'
