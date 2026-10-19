# Host orchestrator. Mutates only named records in the isolated lab domain.
$ErrorActionPreference='Stop'
function Guest($Name,$Command){& "$PSScriptRoot\Invoke-LabGuest.ps1" -Name $Name -Domain CORP -Command $Command}
try{
 Guest DC01 '$r=Get-DnsServerResourceRecord -ZoneName corp.example.test -Name helpdesk -RRType A; if($r.RecordData.IPv4Address.IPAddressToString -ne "10.77.0.30"){throw "Unexpected DNS baseline"};$n=$r.Clone();$n.RecordData.IPv4Address=[ipaddress]"10.77.0.99";Set-DnsServerResourceRecord -ZoneName corp.example.test -OldInputObject $r -NewInputObject $n'
 Guest PC01 'Clear-DnsClientCache;$ips=@(Resolve-DnsName helpdesk.corp.example.test -Type A -DnsOnly|ForEach-Object IPAddress);if($ips -notcontains "10.77.0.99"){throw "T07 fault not reproduced"};[pscustomobject]@{exercise="T07";time=(Get-Date -Format o);wrong_addresses=$ips;fault_observed=$true}|ConvertTo-Json|Set-Content C:\LabEvidence\T07-observations.json'
}finally{
 Guest DC01 '$r=Get-DnsServerResourceRecord -ZoneName corp.example.test -Name helpdesk -RRType A;$n=$r.Clone();$n.RecordData.IPv4Address=[ipaddress]"10.77.0.30";Set-DnsServerResourceRecord -ZoneName corp.example.test -OldInputObject $r -NewInputObject $n'
}
Guest PC01 'Clear-DnsClientCache;$r=Get-Content C:\LabEvidence\T07-observations.json|ConvertFrom-Json;$ips=@(Resolve-DnsName helpdesk.corp.example.test -Type A -DnsOnly|ForEach-Object IPAddress);$status=(Invoke-WebRequest https://helpdesk.corp.example.test/ -UseBasicParsing -TimeoutSec 20).StatusCode;if($ips -notcontains "10.77.0.30" -or $status -ne 200){throw "T07 repair failed"};$r|Add-Member repair_verified $true;$r|Add-Member baseline_restored $true;$r|Add-Member restored_addresses $ips;$r|Add-Member https_status $status;$r|ConvertTo-Json -Depth 5|Set-Content C:\LabEvidence\T07-observations.json'
# The final cache test uses a retained client process and authenticated remoting.
# Ordinary lookups auto-refreshed on this Windows build; script 19 records that limit.
$root=Split-Path $PSScriptRoot -Parent
$vbox='C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
& $vbox guestcontrol PC01 copyto --username Administrator --domain CORP "--passwordfile=$root\LabSecrets\DC01.password" '--target-directory=C:\Lab\19-TestNegativeCache.ps1' "$PSScriptRoot\19-TestNegativeCache.ps1"
if($LASTEXITCODE -ne 0){throw 'Could not stage cache validation'}
Guest PC01 '& C:\Lab\19-TestNegativeCache.ps1'
