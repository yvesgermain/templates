param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,

    [Parameter(Mandatory = $false,
        HelpMessage = "Donner la date du restore dans le format yyyyMMdd, sinon on prendra le dernier backup")]
    $date,

    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("storgum", "storappsinterne", "All")] 
    $storage,

    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Redirect_To
)
function restore-storage {
    param(
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Environnement,
    
        [Parameter(Mandatory = $false,
            HelpMessage = "Donner la date du restore dans le format yyyyMMdd, sinon on prendra le dernier backup")]
        $date,

        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("storgum", "storappsinterne")] 
        $storage,

        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Redirect_To
    )

    $AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

    switch ($storage) {
        "storgum" { $ResourceGroupName = "gumstorage-rg-" + $environnement; $container = "guichetunique" }
        "storappsinterne" { $ResourceGroupName = "Storage-rg-" + $environnement; $container = "appsinterne" }
    }

    $GumBackupKey = (get-azureRMstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value

    $DestKey = (get-azureRMstorageaccountkey -Name "$storage$Environnement" -ResourceGroupName $ResourceGroupName | where-object { $_.keyname -eq "key1" }).value

    if (!$date) {
        $dateformat = ((get-AzureRmStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups | Where-Object { $_.name -like "$container-$Environnement-*" } | sort-object -Property LastModifiedtime -Descending)[0]).LastModifiedtime
        $date = "{0:yyyyMMdd}" -f $dateformat
    }

    if (!( get-AzureRmStorageContainer -ResourceGroupName infrastructure -StorageAccountName gumbackups -name "$container-$Environnement-$date" -ErrorAction SilentlyContinue)) {
        write-warning "Le backup $container-$Environnement-$date n'existe pas";
        break 
    }
    # Pour Rediriger les données vers un autre container.

    if (!$Redirect_To ) {
        $newPath = "$container-$Environnement-$date"
    }
    else {
        $newPath = "$container-$Redirect_To-$date" 
    }
    
    Write-Output "restore https://gumbackups.blob.core.windows.net/$newPath vers https://$storage$environnement.blob.core.windows.net/$container"
    . $AzCopyPath /source:https://gumbackups.blob.core.windows.net/$newPath/ /sourcekey:$GumBackupKey /dest:https://$storage$environnement.blob.core.windows.net/$container/ /s /y /destkey:$DestKey
}

$params = @{'Environnement' = $Environnement }

if ($PSBoundParameters.ContainsKey('Date')) { $params.Add('Date', $Date) }
if ($PSBoundParameters.ContainsKey('Redirect_To')) { $params.Add('Redirect_To', $Redirect_To) }

if ($storage -eq "All") {
    $storage = "storgum", "storappsinterne";
}
foreach ($store in $Storage) {
    $params.add('Storage', $Store)
    Restore-Storage @params
    $params.remove('Storage')

    Write-output "Copier la clef du Storage Account dans Gum Key Vault"
    switch ($store) {
        "storgum" { $ResourceGroupName = "gumstorage-rg-" + $environnement; $StorageAccounts = "storgum" }
        "storappsinterne" { $ResourceGroupName = "Storage-rg-" + $environnement; $StorageAccounts = "storappsinterne" , "storveillefunc" }
    }
    foreach ($StorageAccounts in $StorageAccounts) {
        get-azureRmstorageaccount -resourcegroupName $resourceGroupName | where-object { $_.storageaccountname -like "$StorageAccountname*" } | foreach-object { 
            $name = $_.StorageAccountName;
            Get-AzureRmStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $Name } | where-object { $_.keyname -like "key1" } | ForEach-Object {
            $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
            Set-AzureKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
        }
    }
}

