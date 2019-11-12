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
    . $AzCopyPath /source:https://$storage$environnement.blob.core.windows.net/$container/ /sourcekey:$SourceKey /dest:https://gumbackups.blob.core.windows.net/$newPath/ /s /y /destkey:$GumBackupKey
}

# Restore storage  *************************************************

function restore-storage {
    param(
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Environnement,
    
        [Parameter(Mandatory = $false,
            HelpMessage = "Donner la date du restore dans le format yyyyMMdd, sinon on prendra le dernier backup")]
        [datetime]
        $date,

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

    $DestKey = (get-azureRMstorageaccountkey -Name "$storage$Environnement" -ResourceGroupName $ResourceGroupName | where-object { $_.keyname -eq "key1" }).value

    if (!$date) {
        $dateformat = ((get-AzureRmStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups | Where-Object {$_.name -like "$container-$Environnement-*"} | sort-object -Property LastModifiedtime -Descending)[0]).LastModifiedtime
        $date = "{0:yyyyMMdd}" -f $dateformat
    }


    if (!( get-AzureRmStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups -name "$container-$Environnement-$date" -ErrorAction SilentlyContinue)) {
        write-warning "Le backup $container-$Environnement-$date n'existe pas";
        break 
    }

    $newPath = "$container-$Environnement-$date"
    Write-Output "restore https://gumbackups.blob.core.windows.net/$newPath vers https://$storage$environnement.blob.core.windows.net/$container"
    . $AzCopyPath /source:https://gumbackups.blob.core.windows.net/$newPath/ /sourcekey:$GumBackupKey /dest:https://$storage$environnement.blob.core.windows.net/$container/ /s /y /destkey:$DestKey
}