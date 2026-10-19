#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$OutputPath='.\baseline.csv')
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Import-Module DhcpServer
$results = @()
function Check([string]$Name,[scriptblock]$Test) {
    try { $ok = [bool](& $Test); [pscustomobject]@{Time=(Get-Date -Format o);Check=$Name;Passed=$ok;Error=''} }
    catch { [pscustomobject]@{Time=(Get-Date -Format o);Check=$Name;Passed=$false;Error=$_.Exception.Message} }
}
$results += Check 'Lab domain' { (Get-ADDomain).DNSRoot -eq 'corp.example.test' }
$results += Check '30 lab users' { @(Get-ADUser -Filter * -SearchBase 'OU=LabUsers,DC=corp,DC=example,DC=test').Count -eq 30 }
$results += Check 'LDAP SRV record' { @(Resolve-DnsName -Type SRV '_ldap._tcp.dc._msdcs.corp.example.test' -Server 10.77.0.10).Count -gt 0 }
$results += Check 'DHCP authorization' { @(Get-DhcpServerInDC | Where-Object IPAddress -eq '10.77.0.10').Count -eq 1 }
$results += Check 'DHCP scope active' { (Get-DhcpServerv4Scope -ScopeId 10.77.0.0).State -eq 'Active' }
$results += Check 'DHCP DNS points only to DC01' {
    $dns=@((Get-DhcpServerv4OptionValue -ScopeId 10.77.0.0 -OptionId 6).Value)
    $dns.Count -eq 1 -and $dns[0] -eq '10.77.0.10'
}
foreach($dept in 'IT','HR','Finance','Sales','Operations') {
    $results += Check "Department $dept has six users" {
        @(Get-ADGroupMember "GG_$dept" | Where-Object ObjectClass -eq 'user').Count -eq 6
    }
    $results += Check "Department $dept resource nesting" {
        (Get-ADGroupMember "DL_${dept}_Modify").SamAccountName -contains "GG_$dept"
    }
}
foreach ($machine in 'FS01','PC01','PC02') {
    $results += Check "AD computer $machine" { [bool](Get-ADComputer -Identity $machine) }
}
$results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation
$results | Format-Table -AutoSize
if ($results.Passed -contains $false) { throw 'One or more baseline checks failed. See CSV.' }
