#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('DC01','FS01','PC01','PC02')][string]$Name,
      [Parameter(Mandatory)][ValidateRange(1,20)][int]$ImageIndex)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$vbox='C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$isoName=if($Name -in 'DC01','FS01'){'WindowsServer2025.iso'}else{'Windows11Enterprise.iso'}
$iso=Join-Path $root "media\$isoName"
if(-not(Test-Path "$iso.sha256")){throw 'Complete and verify the media download first.'}
$secrets=Join-Path $root 'LabSecrets'
if(-not(Test-Path $secrets)){New-Item -ItemType Directory $secrets|Out-Null}
$current=[Security.Principal.WindowsIdentity]::GetCurrent().User
$allowed=@($current.Value,'S-1-5-18','S-1-5-32-544')
$acl=Get-Acl -LiteralPath $secrets
if(-not $acl.AreAccessRulesProtected){
    & icacls.exe $secrets /inheritance:r /grant:r "*$($current.Value):(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Could not restrict the credential directory.'}
}
$acl=Get-Acl -LiteralPath $secrets
$unexpected=@($acl.Access | Where-Object {$_.AccessControlType -eq 'Allow' -and $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $allowed})
if(-not $acl.AreAccessRulesProtected -or $unexpected.Count){throw 'Unexpected credential directory permissions. Review ACL before installing.'}
$passwordFile=Join-Path $secrets "$Name.password"
if(Test-Path $passwordFile){throw 'Existing installation credential found. Review guest state before retrying.'}
$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
$bytes=New-Object byte[] 24
try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
$password='Aa1!'+[Convert]::ToBase64String($bytes)
[IO.File]::WriteAllText($passwordFile,$password)
$password=$null
$aux=Join-Path $secrets "$Name-setup-"
$postCommand=@'
& net.exe user Administrator /active:yes
$key='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $key -Name AutoAdminLogon -Value '0'
Remove-ItemProperty -Path $key -Name DefaultPassword,ForceAutoLogon -ErrorAction SilentlyContinue
'@
$encodedPost=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($postCommand))
$post="powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedPost"
$installArgs=@('unattended','install',$Name,"--iso=$iso",'--user=LabAdmin',"--user-password-file=$passwordFile","--admin-password-file=$passwordFile",'--full-user-name=Lab Administrator','--install-additions','--locale=en_US','--country=US','--time-zone=America/Los_Angeles',"--hostname=$($Name.ToLower()).corp.example.test","--image-index=$ImageIndex","--auxiliary-base-path=$aux","--post-install-command=$post",'--start-vm=headless')
# Unattended output can contain installation details; keep it within the protected secret directory.
& $vbox @installArgs *> (Join-Path $secrets "$Name-install.log")
if($LASTEXITCODE -ne 0){throw "Unattended installation failed; inspect the protected $Name-install.log locally."}
Write-Host "Started $Name installation. Credentials and answer files remain in the restricted LabSecrets directory until installation cleanup."
