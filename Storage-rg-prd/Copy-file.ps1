param(
 [Parameter(Mandatory=$True)]
 [string]
 [ValidateSet("dev", "qa", "prd", "devops")]
 $Environnement
)

$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
$resourceGroupName = "storage-rg-" + $Environnement
import-module azurerm.KeyVault
get-azureRmstorageaccount -resourcegroupName $resourceGroupName | where-object {$_.storageaccountname -like "storappsinterne*"} | foreach-object { 
    $name = $_.storageaccountname; 
    Get-azureRMStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $_.StorageAccountName } | where-object { $_.keyname -like "key1"} | ForEach-Object { 
        $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
        Set-azureKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
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

# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa

$resourceGroupName = "Storage-rg-$environnement"

# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa
if ( $Environnement -eq "dev" -or $Environnement -eq "qa") {
    $QA = Get-AzureRmADGroup -SearchString "QA"
    New-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName -AllowDelegation
    $dev = Get-AzureRmADGroup -SearchString "dev"
    New-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroupName -AllowDelegation
}