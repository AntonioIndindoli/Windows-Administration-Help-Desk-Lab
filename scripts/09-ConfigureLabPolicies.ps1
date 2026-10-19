#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
Install-WindowsFeature GPMC -IncludeManagementTools | Out-Null
Import-Module GroupPolicy
if($env:COMPUTERNAME -ne 'DC01' -or (Get-ADDomain).DNSRoot -ne 'corp.example.test'){throw 'Lab DC01 only.'}
$base=(Get-ADDomain).DistinguishedName
# Domain account policy is configured explicitly and its resultant state exported for verification.
Set-ADDefaultDomainPasswordPolicy -Identity corp.example.test -MinPasswordLength 14 -ComplexityEnabled $true -PasswordHistoryCount 24 -LockoutThreshold 5 -LockoutDuration (New-TimeSpan -Minutes 15) -LockoutObservationWindow (New-TimeSpan -Minutes 15)
$name='Lab-Workstation-Security'
$gpo=Get-GPO -Name $name -ErrorAction SilentlyContinue
if(-not $gpo){$gpo=New-GPO -Name $name}
$target="OU=Workstations,$base"
if((Get-GPInheritance -Target $target).GpoLinks.DisplayName -notcontains $name){New-GPLink -Guid $gpo.Id -Target $target|Out-Null}
Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ValueName InactivityTimeoutSecs -Type DWord -Value 900|Out-Null
Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile' -ValueName EnableFirewall -Type DWord -Value 1|Out-Null
Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile' -ValueName DefaultInboundAction -Type DWord -Value 1|Out-Null
Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile' -ValueName DefaultOutboundAction -Type DWord -Value 0|Out-Null
New-Item C:\LabEvidence -ItemType Directory -Force|Out-Null
Get-GPOReport -Guid $gpo.Id -ReportType Html -Path C:\LabEvidence\workstation-policy.html
Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength,ComplexityEnabled,PasswordHistoryCount,LockoutThreshold,LockoutDuration,LockoutObservationWindow | Export-Clixml C:\LabEvidence\account-policy.xml
Write-Host 'Workstation security GPO linked. Verify client resultant policy and separately complete user drive mapping preferences.'
