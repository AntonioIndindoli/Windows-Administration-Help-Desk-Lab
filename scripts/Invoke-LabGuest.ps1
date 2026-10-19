[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('DC01','FS01','PC01','PC02')][string]$Name,
      [Parameter(Mandatory)][string]$Command,
      [string]$UserName='Administrator',
      [string]$Domain,
      [string]$CredentialFile,
      [int]$TimeoutMilliseconds=600000)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$vbox='C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$passwordFile=Join-Path $root "LabSecrets\$Name.password"
if($Domain -eq 'CORP'){$passwordFile=Join-Path $root 'LabSecrets\DC01.password'}
if($CredentialFile){$passwordFile=[IO.Path]::GetFullPath($CredentialFile)}
if(-not(Test-Path -LiteralPath $passwordFile)){throw 'Guest credential file missing.'}
$encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
$runArgs=@('guestcontrol',$Name,'run',"--username=$UserName","--passwordfile=$passwordFile",'--exe=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',"--timeout=$TimeoutMilliseconds",'--wait-stdout','--wait-stderr')
if($Domain){$runArgs+="--domain=$Domain"}
$runArgs+=@('--','powershell.exe','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
& $vbox @runArgs
if($LASTEXITCODE -ne 0){throw "Guest command returned $LASTEXITCODE. Review its output; a requested reboot can interrupt the connection."}
