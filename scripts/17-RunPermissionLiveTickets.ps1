$ErrorActionPreference='Stop'
function Guest($Name,$Command){& "$PSScriptRoot\Invoke-LabGuest.ps1" -Name $Name -Domain CORP -Command $Command}
try{
 Guest DC01 'if((Get-ADGroupMember GG_HR).SamAccountName -notcontains "hr04"){throw "Unexpected T16 baseline"};Remove-ADGroupMember GG_HR hr04 -Confirm:$false'
 Guest PC01 '& C:\Lab\15-TestShareAsUser.ps1 -User hr04 -Share HR -Expected Denied -Label T16-fault'
}finally{Guest DC01 'if((Get-ADGroupMember GG_HR).SamAccountName -notcontains "hr04"){Add-ADGroupMember GG_HR hr04}'}
Guest PC01 '& C:\Lab\15-TestShareAsUser.ps1 -User hr04 -Share HR -Expected Modify -Label T16-repair; & C:\Lab\15-TestShareAsUser.ps1 -User hr04 -Share Finance -Expected Denied -Label T16-negative'
try{
 Guest FS01 '$path="C:\LabShares\Finance";$acl=Get-Acl $path;$acl.Sddl|Set-Content C:\LabEvidence\T17-baseline-sddl.txt;$rules=@($acl.Access|Where-Object {$_.IdentityReference.Value -eq "CORP\DL_Finance_Modify"});if($rules.Count -eq 0){throw "Expected Finance ACL missing"};foreach($r in $rules){[void]$acl.RemoveAccessRuleAll($r)};Set-Acl $path $acl;Get-SmbShareAccess Finance|Select AccountName,AccessRight|ConvertTo-Json|Set-Content C:\LabEvidence\T17-share-unchanged.json'
 Guest PC01 '& C:\Lab\15-TestShareAsUser.ps1 -User finance04 -Share Finance -Expected Denied -Label T17-fault'
}finally{Guest FS01 '$path="C:\LabShares\Finance";$acl=Get-Acl $path;$acl.SetSecurityDescriptorSddlForm((Get-Content C:\LabEvidence\T17-baseline-sddl.txt -Raw).Trim());Set-Acl $path $acl;if((Get-Acl $path).Sddl -ne (Get-Content C:\LabEvidence\T17-baseline-sddl.txt -Raw).Trim()){throw "T17 ACL restore mismatch"}'}
Guest PC01 '& C:\Lab\15-TestShareAsUser.ps1 -User finance04 -Share Finance -Expected Modify -Label T17-repair; & C:\Lab\15-TestShareAsUser.ps1 -User finance04 -Share HR -Expected Denied -Label T17-negative'
try{
 Guest FS01 'Get-SmbShareAccess Sales|Select AccountName,AccessControlType,AccessRight|ConvertTo-Json|Set-Content C:\LabEvidence\T18-share-baseline.json;(Get-Acl C:\LabShares\Sales).Sddl|Set-Content C:\LabEvidence\T18-ntfs-baseline.txt;Revoke-SmbShareAccess -Name Sales -AccountName "CORP\DL_Sales_Modify" -Force -Confirm:$false|Out-Null'
 Guest PC01 '& C:\Lab\15-TestShareAsUser.ps1 -User sales04 -Share Sales -Expected Denied -Label T18-fault'
}finally{Guest FS01 'Grant-SmbShareAccess -Name Sales -AccountName "CORP\DL_Sales_Modify" -AccessRight Change -Force -Confirm:$false|Out-Null;if((Get-Acl C:\LabShares\Sales).Sddl -ne (Get-Content C:\LabEvidence\T18-ntfs-baseline.txt -Raw).Trim()){throw "T18 NTFS changed unexpectedly"}'}
Guest PC01 '& C:\Lab\15-TestShareAsUser.ps1 -User sales04 -Share Sales -Expected Modify -Label T18-repair; & C:\Lab\15-TestShareAsUser.ps1 -User sales04 -Share HR -Expected Denied -Label T18-negative'
