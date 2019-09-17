param(
 [Parameter(Mandatory=$True)]
 [string]
 [ValidateSet("dev", "qa", "prd", "devops")]
 $Environnement
)

$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
$resourceGroupName = "Storage-rg-$environnement"
import-module azurerm
get-azureRmstorageaccount -resourcegroupName $resourceGroupName | where-object {$_.storageaccountname -like "storappsinterne*"} | foreach-object { 
    $name = $_.storageaccountname; 
    Get-azureRMStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $_.StorageAccountName } | where-object { $_.keyname -like "key1"} | ForEach-Object { 
        $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
        Set-azureRmKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
    }

get-azureRmstorageaccount -resourcegroupName $resourceGroupName | where-object {$_.storageaccountname -like "storveillefunc*"} | foreach-object { 
    $name = $_.storageaccountname; 
    get-azureRMStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $_.StorageAccountName } | where-object { $_.keyname -like "key1"} | ForEach-Object { 
        $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
        Set-azureKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
    }
    

$SourceKey = (get-azureRMStorageAccountKey -Name storappsinterneprd -ResourceGroupName storage-rg-prd | where-object {$_.keyname -eq "key1"}).value
$DestKey   = (get-azureRMStorageAccountKey -Name storappsinterne$Environnement -ResourceGroupName $resourceGroupName | where-object {$_.keyname -eq "key1"}).value

. $AzCopyPath /source:https://storappsinterneprd.blob.core.windows.net/appsinterne/ /sourcekey:$SourceKey /dest:https://storappsinterne$Environnement.blob.core.windows.net/appsinterne/ /s /y /destkey:$destkey
