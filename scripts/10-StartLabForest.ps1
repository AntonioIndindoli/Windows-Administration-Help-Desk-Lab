#Requires -RunAsAdministrator
#Requires -Version 5.1
# Runs only inside freshly installed DC01. Generates a unique recovery secret locally.
$ErrorActionPreference='Stop'
if($env:COMPUTERNAME -ne 'DC01'){throw 'DC01 only'}
New-Item -ItemType Directory -Path C:\Lab,C:\LabEvidence,C:\LabSecrets -Force|Out-Null
& icacls.exe C:\LabSecrets /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if($LASTEXITCODE -ne 0){throw 'Cannot protect guest secrets directory'}
Copy-Item '\\VBOXSVR\LabPayload\scripts' C:\Lab -Recurse -Force
Copy-Item '\\VBOXSVR\LabPayload\data' C:\Lab -Recurse -Force
$recoveryFile='C:\LabSecrets\DSRM.password'
if(Test-Path $recoveryFile){throw 'Existing recovery password. Inspect promotion state before retrying.'}
$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
$bytes=New-Object byte[] 24
try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
$password='Aa1!'+[Convert]::ToBase64String($bytes)
[IO.File]::WriteAllText($recoveryFile,$password)
$secure=ConvertTo-SecureString $password -AsPlainText -Force
$password=$null
Start-Transcript -Path C:\LabEvidence\forest-promotion.txt -Force
try {
    $nic=@(Get-NetAdapter|Where-Object Status -eq 'Up')
    if($nic.Count -ne 1){throw 'Expected one active lab NIC'}
    & C:\Lab\scripts\01-NewForest.ps1 -InterfaceAlias $nic[0].Name -Gateway 10.77.0.1 -SafeModeAdministratorPassword $secure
} finally {Stop-Transcript}
