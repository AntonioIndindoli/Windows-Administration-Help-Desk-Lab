#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([string]$VMRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'VMs'))
$ErrorActionPreference = 'Stop'
$vbox = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path -LiteralPath $vbox)) { throw 'Install Oracle VirtualBox first.' }
function Invoke-VBox([string[]]$Arguments) {
    & $vbox @Arguments
    if ($LASTEXITCODE -ne 0) { throw "VirtualBox command failed: $($Arguments[0])" }
}
$existing = & $vbox list vms
if ($LASTEXITCODE -ne 0) { throw 'Cannot access VirtualBox VM registry.' }
$specs = @(
    @{Name='DC01';Type='Windows2025_64';RAM=4096;Disk=65536},
    @{Name='FS01';Type='Windows2025_64';RAM=4096;Disk=65536},
    @{Name='PC01';Type='Windows11_64';RAM=4096;Disk=81920},
    @{Name='PC02';Type='Windows11_64';RAM=4096;Disk=81920},
    @{Name='HD01';Type='Ubuntu_64';RAM=2048;Disk=32768}
)
foreach ($vm in $specs) {
    if ($existing | Where-Object { $_ -match ('^"' + [regex]::Escape($vm.Name) + '" ') }) { throw "Existing VM $($vm.Name); no changes made. Review inventory first." }
    if (Test-Path -LiteralPath (Join-Path $VMRoot $vm.Name)) { throw "Existing directory for $($vm.Name). Review before creation." }
}
foreach ($vm in $specs) {
    if (-not $PSCmdlet.ShouldProcess($vm.Name,'Create isolated lab VM shell; no operating system installed')) { continue }
    Invoke-VBox @('createvm','--name',$vm.Name,'--ostype',$vm.Type,'--basefolder',$VMRoot,'--register')
    $graphics = if ($vm.Name -eq 'HD01') {'vmsvga'} else {'vboxsvga'}
    # Host-specific backend workaround: three vCPUs for Linux, four for Windows.
    $cpus=if($vm.Name -eq 'HD01'){'3'}else{'4'}
    Invoke-VBox @('modifyvm',$vm.Name,'--memory',"$($vm.RAM)",'--cpus',$cpus,'--paravirt-provider','hyperv','--firmware','efi','--ioapic','on','--graphicscontroller',$graphics,'--vram','128','--nic1','intnet','--intnet1','HelpDeskLab','--cable-connected1','on','--nic2','none','--clipboard-mode','disabled','--drag-and-drop','disabled','--boot1','dvd','--boot2','disk','--boot3','none','--boot4','none')
    if ($vm.Name -ne 'HD01') {
        Invoke-VBox @('modifyvm',$vm.Name,'--tpm-type','2.0')
        Invoke-VBox @('modifynvram',$vm.Name,'inituefivarstore')
        Invoke-VBox @('modifynvram',$vm.Name,'enrollmssignatures')
        Invoke-VBox @('modifynvram',$vm.Name,'enrollorclpk')
        Invoke-VBox @('modifynvram',$vm.Name,'secureboot','--enable')
    }
    $disk = Join-Path (Join-Path $VMRoot $vm.Name) "$($vm.Name).vdi"
    Invoke-VBox @('createmedium','disk','--filename',$disk,'--size',"$($vm.Disk)",'--format','VDI','--variant','Standard')
    Invoke-VBox @('storagectl',$vm.Name,'--name','SATA','--add','sata','--controller','IntelAhci','--portcount','4')
    Invoke-VBox @('storageattach',$vm.Name,'--storagectl','SATA','--port','0','--device','0','--type','hdd','--medium',$disk)
    Invoke-VBox @('storageattach',$vm.Name,'--storagectl','SATA','--port','1','--device','0','--type','dvddrive','--medium','emptydrive')
}
Write-Host 'VM shells created. Attach verified media before installation. Do not start all VMs without checking free host RAM.'
