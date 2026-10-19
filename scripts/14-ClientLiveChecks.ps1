#Requires -RunAsAdministrator
[CmdletBinding()]
param([ValidateSet('Baseline','T05','T06','T08','T10','T12','T13','T14','T15')][string]$Exercise='Baseline')
$ErrorActionPreference='Stop'
if($env:COMPUTERNAME -ne 'PC01'){throw 'PC01 only'}
New-Item C:\LabEvidence -ItemType Directory -Force|Out-Null
$nic=Get-NetAdapter|Where-Object Name -eq Ethernet|Select-Object -First 1
if(-not $nic){throw 'Expected lab Ethernet adapter'}
function Assert($condition,$message){if(-not $condition){throw $message}}
function Tcp([string]$Address,[int]$Port){$c=New-Object Net.Sockets.TcpClient;try{$t=$c.ConnectAsync($Address,$Port);[bool]($t.Wait(4000)-and $c.Connected)}catch{$false}finally{$c.Dispose()}}
function Dns([string]$Name){try{@(Resolve-DnsName $Name -DnsOnly -QuickTimeout -ErrorAction Stop|Where-Object Type -eq A|Select-Object -ExpandProperty IPAddress)}catch{@()}}
function Restore-Network {
 Enable-NetAdapter -Name $nic.Name -Confirm:$false -ErrorAction SilentlyContinue
 Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue|Where-Object PrefixOrigin -eq Manual|Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
 Get-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue|Where-Object Protocol -eq NetMgmt|Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
 Set-NetIPInterface -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -Dhcp Enabled
 Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ResetServerAddresses
 ipconfig /renew|Out-Null; Clear-DnsClientCache
}
$raw=[ordered]@{exercise=$Exercise;time=(Get-Date -Format o);computer=$env:COMPUTERNAME}
$fault=$false;$repair=$false;$restored=$false
switch($Exercise){
 'Baseline' {
  $raw.domain=Get-CimInstance Win32_ComputerSystem|Select-Object Name,Domain,PartOfDomain
  $raw.secure_channel=Test-ComputerSecureChannel
  $raw.addresses=@(Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4|Select-Object IPAddress,PrefixLength,PrefixOrigin)
  $raw.dns=@(Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4|Select-Object -ExpandProperty ServerAddresses)
  $raw.fs_tcp445=Tcp 'FS01.corp.example.test' 445
  $raw.helpdesk_tcp443=Tcp 'helpdesk.corp.example.test' 443
  $raw.external_tcp443=Tcp '1.1.1.1' 443
  $raw|ConvertTo-Json -Depth 7|Set-Content C:\LabEvidence\pc01-live-baseline.json
  $raw|ConvertTo-Json -Depth 7;return
 }
 'T05' {
  Add-Type @'
using System; using System.Runtime.InteropServices;
public static class ClientAuth {
 [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)] public static extern bool LogonUser(string u,string d,string p,int t,int r,out IntPtr h);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
'@
  $u=Import-Csv C:\LabSecrets\working-users.csv|Where-Object SamAccountName -eq operations01
  Assert ($null -ne $u) 'Missing protected test credential'
  $h=[IntPtr]::Zero;$bad=[ClientAuth]::LogonUser($u.SamAccountName,$env:COMPUTERNAME,$u.Password,2,0,[ref]$h)
  $raw.local_error=[Runtime.InteropServices.Marshal]::GetLastWin32Error();if($h -ne [IntPtr]::Zero){[void][ClientAuth]::CloseHandle($h)}
  $fault=-not $bad;Assert $fault 'Local namespace fault did not reproduce'
  $h=[IntPtr]::Zero;$good=[ClientAuth]::LogonUser($u.SamAccountName,'CORP',$u.Password,2,0,[ref]$h)
  Assert $good 'Domain logon failed'
  try{$id=New-Object Security.Principal.WindowsIdentity($h);$raw.identity=$id.Name;$id.Dispose()}finally{[void][ClientAuth]::CloseHandle($h)}
  $repair=$raw.identity -eq 'CORP\operations01';$restored=$true
 }
 'T06' {
  Assert ((Dns 'dc01.corp.example.test') -contains '10.77.0.10') 'DNS baseline failed'
  try{
   Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 10.77.0.99;Clear-DnsClientCache
   $raw.wrong_dns_result=@(Dns 'dc01.corp.example.test');$fault=$raw.wrong_dns_result.Count -eq 0
   Assert $fault 'Wrong DNS fault did not reproduce'
  }finally{Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ResetServerAddresses;Clear-DnsClientCache}
  $raw.retest=@(Dns 'dc01.corp.example.test');$repair=$raw.retest -contains '10.77.0.10';$restored=$repair
 }
 'T08' {
  $path='C:\Windows\System32\drivers\etc\hosts';$backup=[IO.File]::ReadAllBytes($path)
  Assert ((Dns 'helpdesk.corp.example.test') -contains '10.77.0.30') 'Helpdesk baseline failed'
  try{
   [IO.File]::AppendAllText($path,"`r`n10.77.0.99 helpdesk.corp.example.test # Lab-T08`r`n");Clear-DnsClientCache
   $raw.application_addresses=@([Net.Dns]::GetHostAddresses('helpdesk.corp.example.test')|ForEach-Object IPAddressToString)
   $raw.authoritative=@(Resolve-DnsName helpdesk.corp.example.test -Server 10.77.0.10 -NoHostsFile -DnsOnly|Where-Object Type -eq A|ForEach-Object IPAddress)
   $fault=($raw.application_addresses -contains '10.77.0.99') -and ($raw.authoritative -contains '10.77.0.30');Assert $fault 'Hosts override did not reproduce'
  }finally{[IO.File]::WriteAllBytes($path,$backup);Clear-DnsClientCache}
  $raw.retest=@([Net.Dns]::GetHostAddresses('helpdesk.corp.example.test')|ForEach-Object IPAddressToString)
  $repair=($raw.retest -contains '10.77.0.30') -and (Tcp 'helpdesk.corp.example.test' 443)
  $restored=[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -eq [Convert]::ToBase64String($backup)
 }
 'T10' {
  $settings=Get-DnsClientGlobalSetting;$suffix=@($settings.SuffixSearchList)
  try{
   Set-DnsClientGlobalSetting -SuffixSearchList @('invalid.test');Clear-DnsClientCache
   $raw.short=(& cmd.exe /d /c 'nslookup -type=A FS01 2>&1'|Out-String);$raw.fqdn=@(Dns 'FS01.corp.example.test')
   $fault=$raw.short -notmatch '10\.77\.0\.20' -and $raw.fqdn -contains '10.77.0.20';Assert $fault 'Suffix fault did not reproduce; do not close T10'
  }finally{Set-DnsClientGlobalSetting -SuffixSearchList $suffix;Clear-DnsClientCache}
  $raw.retest=(& cmd.exe /d /c 'nslookup -type=A FS01 2>&1'|Out-String)
  $repair=$raw.retest -match '10\.77\.0\.20';$restored=(@((Get-DnsClientGlobalSetting).SuffixSearchList)-join ',') -eq ($suffix-join ',')
 }
 'T12' {
  try{
   Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4|Remove-NetIPAddress -Confirm:$false
   New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 10.77.0.250 -PrefixLength 30|Out-Null
   Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 10.77.0.10
   $raw.wrong_prefix=30;$raw.dc_tcp389=Tcp '10.77.0.10' 389;$fault=-not $raw.dc_tcp389;Assert $fault 'Mask fault did not reproduce'
  }finally{Restore-Network}
  $raw.retest=Tcp '10.77.0.10' 389;$raw.addresses=@(Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4|Select-Object IPAddress,PrefixLength,PrefixOrigin)
  $repair=$raw.retest;$restored=@($raw.addresses|Where-Object {$_.PrefixLength -eq 24 -and $_.PrefixOrigin -eq 'Dhcp'}).Count -gt 0
 }
 'T13' {
  try{Disable-NetAdapter -Name $nic.Name -Confirm:$false;$raw.status=(Get-NetAdapter -Name $nic.Name).Status;$raw.failed_connection=Tcp '10.77.0.20' 445;$fault=$raw.status -eq 'Disabled' -and -not $raw.failed_connection;Assert $fault 'Adapter fault did not reproduce'}finally{Restore-Network}
  $repair=Tcp '10.77.0.20' 445;$restored=(Get-NetAdapter -Name $nic.Name).Status -eq 'Up'
 }
 'T14' {
  Assert (Tcp '10.77.0.20' 445) 'SMB baseline failed'
  Assert (-not(Get-NetFirewallRule -Name Lab-T14 -ErrorAction SilentlyContinue)) 'Existing rule would be overwritten'
  try{New-NetFirewallRule -Name Lab-T14 -DisplayName 'Lab T14 temporary SMB block' -Direction Outbound -Action Block -Protocol TCP -RemotePort 445 -RemoteAddress 10.77.0.20|Out-Null;$raw.dns=@(Dns 'FS01.corp.example.test');$raw.smb=Tcp '10.77.0.20' 445;$fault=(-not $raw.smb)-and($raw.dns -contains '10.77.0.20');Assert $fault 'Firewall fault did not reproduce'}finally{Remove-NetFirewallRule -Name Lab-T14 -ErrorAction SilentlyContinue}
  $repair=Tcp '10.77.0.20' 445;$restored=-not(Get-NetFirewallRule -Name Lab-T14 -ErrorAction SilentlyContinue)
 }
 'T15' {
  Assert (Tcp '1.1.1.1' 443) 'External routed baseline failed'
  try{
   Get-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0'|Remove-NetRoute -Confirm:$false
   New-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -NextHop 10.77.0.254|Out-Null
   $raw.internal=Tcp '10.77.0.20' 445;$raw.external=Tcp '1.1.1.1' 443;$fault=$raw.internal -and -not $raw.external;Assert $fault 'Gateway fault did not reproduce'
  }finally{Restore-Network}
  $repair=Tcp '1.1.1.1' 443;$restored=@(Get-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0'|Where-Object NextHop -eq '10.77.0.1').Count -gt 0
 }
}
$raw.fault_observed=$fault;$raw.repair_verified=$repair;$raw.baseline_restored=$restored
$raw|ConvertTo-Json -Depth 7|Set-Content "C:\LabEvidence\$Exercise-observations.json"
Assert ($fault -and $repair -and $restored) "$Exercise repair or baseline restoration failed"
$raw|ConvertTo-Json -Depth 7
