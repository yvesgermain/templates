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
    if ($storage -eq "null") { Write-Output "Storage = null. Aucun storage à restaurer!"; return 0 }
    $AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Az\AzCopy\AzCopy.exe"

    if (!$Source ) { $source = $Destination }

    switch ($storage) {
        "storgum" { $ResourceGroupName = "gumstorage-rg-" + $Destination; $container = "guichetunique" }
        "storappsinterne" { $ResourceGroupName = "AppsStorage-rg-" + $Destination; $container = "appsinterne" }
    }

    $GumBackupKey = (get-Azstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value

    $DestKey = (get-Azstorageaccountkey -Name "$storage$Destination" -ResourceGroupName $ResourceGroupName | where-object { $_.keyname -eq "key1" }).value
    if (!( get-AzStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups | where-object { $_.name -like "$container-$Source-$date*" } -ErrorAction SilentlyContinue)) {
        write-warning "Le backup $container-$Source-$date n'existe pas";
        break 
    }

    if (!$date) {
        $dateformat = ((get-AzStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups | Where-Object { $_.name -like "$container-$Source-*" } | sort-object -Property LastModifiedtime -Descending)[0]).LastModifiedtime.ToLocalTime()
        $date = "{0:yyyyMMdd}" -f $dateformat
    }

    # Pour Rediriger les donnees vers un autre container.

    $newPath = "$container-$Source-$date" 
    
    Write-Output "restore https://gumbackups.blob.core.windows.net/$newPath vers https://$storage$Destination.blob.core.windows.net/$container"
    . $AzCopyPath /source:https://gumbackups.blob.core.windows.net/$newPath/ /sourcekey:$GumBackupKey /dest:https://$storage$Destination.blob.core.windows.net/$container/ /s /y /destkey:$DestKey /z:$( $env:temp + '\' + $newPath)
}

if (!$Source ) { $source = $Destination }
$params = @{'Destination' = $Destination }

if ($PSBoundParameters.ContainsKey('Date')) { $params.Add('Date', $Date) }
if ($PSBoundParameters.ContainsKey('Source')) { $params.Add('Source', $Source) }

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
        "storappsinterne" { $ResourceGroupName = "AppsStorage-rg-" + $Destination; $StorageAccounts = "storappsinterne" , "storveillefunc" }
    }
    foreach ($StorageAccount in $StorageAccounts) {
        get-Azstorageaccount -resourcegroupName $resourceGroupName | where-object { $_.storageaccountname -like "$StorageAccount*" } | foreach-object { 
            $name = $_.StorageAccountName;
            Get-AzStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $Name } | where-object { $_.keyname -like "key1" } | ForEach-Object {
            $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
            Set-AzKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
        }
    }
}

