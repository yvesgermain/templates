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
    $GumBackupContext = (get-azstorageaccount -name gumbackups -ResourceGroupName Infrastructure).context

    $date = get-date -Format "yyyy-MM-dd"

    if (!( get-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-$date" -ErrorAction SilentlyContinue) ) {
        New-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-$date" 
    }

    $newPath = "$storage-$Environnement-$date"


    $SourceKey = ( get-azureRMstorageaccountkey -Name "$storage$Environnement" -ResourceGroupName $ResourceGroupName | where-object { $_.keyname -eq "key1" }).value
    # $SourceContext = (get-azureRmstorageaccount -name "$storage$Environnement" -ResourceGroupName $ResourceGroupName ).context


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
            HelpMessage = "Donner la date du restore dans le format yyyy-MM-dd, sinon on prendra le dernier backup")]
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
    $GumBackupContext = (get-azstorageaccount -name gumbackups -ResourceGroupName Infrastructure).context

    $DestKey = (get-azureRMstorageaccountkey -Name "$storage$Environnement" -ResourceGroupName $ResourceGroupName | where-object { $_.keyname -eq "key1" }).value
    # $DestContext = (get-azureRmstorageaccount -name "$storage$Environnement" -ResourceGroupName $ResourceGroupName ).context

    if (!$date) {
        $date = ((get-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-*" | sort-object -Property LastModified -Descending)[0]).LastModified.localdatetime.ToShortDateString()
    }

    if (!( get-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-$date" -ErrorAction SilentlyContinue)) {
        write-warning "Le blob n'existe pas";
        break 
    }

    $newPath = "$storage-$Environnement-$date"

    . $AzCopyPath /source:https://gumbackups.blob.core.windows.net/$newPath/ /sourcekey:$GumBackupKey /dest:https://$storage$environnement.blob.core.windows.net/$container/ /s /y /destkey:$DestKey
}