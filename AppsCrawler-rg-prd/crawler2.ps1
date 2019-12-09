Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement ,
    [string]
    $defaultpath

)

$chromepath2 = $defaultpath + '\DevOps\AppsCrawler-rg-prd\Install-chrome2.ps1'
$ResourceGroupName = "crawler-rg-$environnement"
$VMName = "VMcrawl-$environnement"

"Donne accès à l'adresse IP du crawler au site gummaster"

Invoke-AzureRMVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptPath $chromepath2 -Parameter @{"Environnement" = $Environnement }

"Retirer les droits sur le blob https://gumbackups.blob.core.windows.net/depot-tfs"
Get-AzureStorageContainer depot-tfs -Context $storageContext | set-AzurestorageContainerAcl -Permission  Off

