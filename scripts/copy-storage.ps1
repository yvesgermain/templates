param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,

    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("storgum", "storappsinterne", "All")] 
    $storage
)

function copy-storage {
    param(
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Environnement,

        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("storgum", "storappsinterne")] 
        $storage
    )

    $AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

    switch ($storage) {
        "storgum" { $ResourceGroupName = "gumstorage-rg-" + $environnement; $container = "guichetunique" }
        "storappsinterne" { $ResourceGroupName = "Storage-rg-" + $environnement; $container = "appsinterne" }
    }

    $GumBackupKey = (get-azureRMstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value

    $date = get-date -Format "yyyyMMdd"

    if (!( get-AzureRmStorageContainer -resourcegroupName Infrastructure -StorageAccountName gumbackups -name "$container-$Environnement-$date" -ErrorAction SilentlyContinue) ) {
        New-AzureRmStorageContainer -resourcegroupName Infrastructure -StorageAccountName gumbackups -Name "$container-$Environnement-$date" 
    }

    $newPath = "$container-$Environnement-$date"

    $SourceKey = ( Get-AzureRmStorageaccountkey -Name "$storage$Environnement" -ResourceGroupName $ResourceGroupName | where-object { $_.keyname -eq "key1" }).value

    Write-Output "copy https://$storage$environnement.blob.core.windows.net/$container vers https://gumbackups.blob.core.windows.net/$newPath"
    . $AzCopyPath /source:https://$storage$environnement.blob.core.windows.net/$container/ /sourcekey:$SourceKey /dest:https://gumbackups.blob.core.windows.net/$newPath/ /s /y /destkey:$GumBackupKey /z:$( $env:temp + '\' + $newPath)
}

$params = @{'Environnement' = $Environnement }

if ($storage -eq "All") {
    $store = "storgum", "storappsinterne";
}
foreach ($storage in $Store) {
    $params.add('Storage', $Storage)
    Copy-Storage @params
    $params.remove('Storage')
}

# Enlever les container de plus de 10 jours
foreach ($app in "appsinterne*", "guichetunique*" ) {
    Get-AzureRmStorageContainer -resourcegroupName Infrastructure -StorageAccountName gumbackups | where-object { $_.name -like "$app*" -and $_.LastModifiedTime -lt (get-date).adddays(-10) } | remove-AzureRmStorageContainer -force
}