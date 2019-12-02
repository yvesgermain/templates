param(
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Source,

    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Destination,

    [Parameter(Mandatory = $false,
        HelpMessage = "Donner la date du restore dans le format yyyyMMdd, sinon on prendra le dernier backup")]
    $date,

    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("storgum", "storappsinterne", "All", "null")] 
    $storage

)
function restore-storage {
    param(
        
        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Source,

        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Destination,
    
        [Parameter(Mandatory = $false,
            HelpMessage = "Donner la date du restore dans le format yyyyMMdd, sinon on prendra le dernier backup")]
        $date,

        [Parameter(Mandatory = $True,
        HelpMessage = "Si null, aucune restauration de données")]
        [string]
        [ValidateSet("storgum", "storappsinterne", "null")] 
        $storage
    )
    if ($storage -eq "null") {Write-Output "Storage = null. Aucun storage à restaurer!"; return 0}
    $AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

    if (!$Source ) {$source = $Destination}

    switch ($storage) {
        "storgum" { $ResourceGroupName = "gumstorage-rg-" + $Destination; $container = "guichetunique" }
        "storappsinterne" { $ResourceGroupName = "Storage-rg-" + $Destination; $container = "appsinterne" }
    }

    $GumBackupKey = (get-azureRMstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value

    $DestKey = (get-azureRMstorageaccountkey -Name "$storage$Destination" -ResourceGroupName $ResourceGroupName | where-object { $_.keyname -eq "key1" }).value

    if (!( get-AzureRmStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups -name "$container-$Source-$date" -ErrorAction SilentlyContinue)) {
        write-warning "Le backup $container-$Source-$date n'existe pas";
        break 
    }

    if (!$date) {
        $dateformat = ((get-AzureRmStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups | Where-Object { $_.name -like "$container-$Source-*" } | sort-object -Property LastModifiedtime -Descending)[0]).LastModifiedtime
        $date = "{0:yyyyMMdd}" -f $dateformat
    }

    # Pour Rediriger les donnees vers un autre container.

    $newPath = "$container-$Source-$date" 
    
    Write-Output "restore https://gumbackups.blob.core.windows.net/$newPath vers https://$storage$Destination.blob.core.windows.net/$container"
    . $AzCopyPath /source:https://gumbackups.blob.core.windows.net/$newPath/ /sourcekey:$GumBackupKey /dest:https://$storage$Destination.blob.core.windows.net/$container/ /s /y /destkey:$DestKey
}

$params = @{'Destination' = $Destination }

if ($PSBoundParameters.ContainsKey('Date')) { $params.Add('Date', $Date) }
if ($PSBoundParameters.ContainsKey('$Source')) { $params.Add('$Source', $Source) }

if ($storage -eq "All") {
    $storage = "storgum", "storappsinterne";
}
foreach ($store in $Storage) {
    $params.add('Storage', $Store)
    Restore-Storage @params
    $params.remove('Storage')

    Write-output "Copier la clef du Storage Account dans Gum Key Vault"
    switch ($store) {
        "storgum" { $ResourceGroupName = "gumstorage-rg-" + $Destination; $StorageAccounts = "storgum" }
        "storappsinterne" { $ResourceGroupName = "Storage-rg-" + $Destination; $StorageAccounts = "storappsinterne" , "storveillefunc" }
    }
    foreach ($StorageAccount in $StorageAccounts) {
        get-azureRmstorageaccount -resourcegroupName $resourceGroupName | where-object { $_.storageaccountname -like "$StorageAccount*" } | foreach-object { 
            $name = $_.StorageAccountName;
            Get-AzureRmStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $Name } | where-object { $_.keyname -like "key1" } | ForEach-Object {
            $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
            Set-AzureKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
        }
    }
}

