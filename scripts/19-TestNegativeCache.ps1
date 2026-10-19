$ErrorActionPreference='Stop'
if($env:COMPUTERNAME -ne 'PC01'){throw 'PC01 only'}
# Keep the affected resolver process alive. A separate DC session creates the record.
$session=New-PSSession -ComputerName DC01
try{
 Invoke-Command -Session $session -ScriptBlock {if(Get-DnsServerResourceRecord -ZoneName corp.example.test -Name kbtest -ErrorAction SilentlyContinue){throw 'Unexpected existing kbtest'}}
 Clear-DnsClientCache
 $failure=$false
 try{Resolve-DnsName kbtest.corp.example.test -Type A -DnsOnly -ErrorAction Stop|Out-Null}catch{$failure=$true}
 if(-not $failure){throw 'Initial NXDOMAIN absent'}
 $cache=@(Get-DnsClientCache|Where-Object Entry -eq 'kbtest.corp.example.test'|Select Entry,Status,Type,TimeToLive)
 $authoritative=Invoke-Command -Session $session -ScriptBlock {Add-DnsServerResourceRecordA -ZoneName corp.example.test -Name kbtest -IPv4Address 10.77.0.30;Get-DnsServerResourceRecord -ZoneName corp.example.test -Name kbtest -RRType A|ForEach-Object {$_.RecordData.IPv4Address.IPAddressToString}}
 $stillFailed=$false
 try{Resolve-DnsName kbtest.corp.example.test -Type A -CacheOnly -ErrorAction Stop|Out-Null}catch{$stillFailed=$true}
 $r=[pscustomobject]@{exercise='T09';time=(Get-Date -Format o);initial_nxdomain=$failure;negative_cache=$cache;authoritative=@($authoritative);fault_observed=$stillFailed;fault_scope='Cache-only lookup; earlier ordinary application lookups refreshed automatically and did not reproduce a persistent outage.';repair_verified=$false;baseline_restored=$false}
 $r|ConvertTo-Json -Depth 6|Set-Content C:\LabEvidence\T09-observations.json
 if(-not $stillFailed){throw 'Negative-cache fault did not reproduce'}
 Clear-DnsClientCache
 $ip=@([Net.Dns]::GetHostAddresses('kbtest.corp.example.test')|ForEach-Object IPAddressToString)
 if($ip -notcontains '10.77.0.30'){throw 'Cache repair failed'}
 $cached=@(Resolve-DnsName kbtest.corp.example.test -Type A -CacheOnly -ErrorAction Stop|ForEach-Object IPAddress)
 if($cached -notcontains '10.77.0.30'){throw 'Positive cache retest failed'}
 $r|Add-Member positive_cache $cached
 $r.repair_verified=$true;$r|Add-Member restored_addresses $ip
}finally{
 Invoke-Command -Session $session -ScriptBlock {$r=Get-DnsServerResourceRecord -ZoneName corp.example.test -Name kbtest -ErrorAction SilentlyContinue;if($r){Remove-DnsServerResourceRecord -ZoneName corp.example.test -InputObject $r -Force}}
 Remove-PSSession $session
 Clear-DnsClientCache
 if($r -and $r.exercise -eq 'T09'){$r.baseline_restored=$true;$r|ConvertTo-Json -Depth 6|Set-Content C:\LabEvidence\T09-observations.json}
}
