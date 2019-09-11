<#
 .SYNOPSIS
    Update the files in a storage account

 .DESCRIPTION
    Copies the files 

 .PARAMETER ResourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.
#>

<#
.SYNOPSIS
    Registers RPs
#>

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"
$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
# Register RPs

#Create or check for existing resource group
$ResourceGroupName = "gumstorage-rg-" + $environnement
$resourceGroup = Get-AzureRMResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

get-azureRMstorageaccount -resourcegroupName $resourceGroupName | where-object { $_.storageaccountname -like "storgum*" } | foreach-object { 
    $name = $_.storageaccountname; 
    Get-AzureRMStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $_.StorageAccountName } | where-object { $_.keyname -like "key1" } | ForEach-Object {
    $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
    Set-AzureKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
}

if( (Get-Item $AzCopyPath).Exists)
{
   $FileItemVersion = (Get-Item $AzCopyPath).VersionInfo
   $FilePath = ("{0}.{1}.{2}.{3}" -f  $FileItemVersion.FileMajorPart,  $FileItemVersion.FileMinorPart,  $FileItemVersion.FileBuildPart,  $FileItemVersion.FilePrivatePart)

   # only netcore version AzCopy.exe has version 0.0.0.0, and all netcore version AzCopy works in this script 
   if(([version] $FilePath -lt "7.0.0.2") -and ([version] $FilePath -ne "0.0.0.0"))
   {
       $AzCopyPath = Read-Host "Version of AzCopy found at default install directory is of a lower, unsupported version. Please input the full filePath of the AzCopy.exe that is version 7.0.0.2 or higher, e.g.: C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
   }
}
elseIf( (Get-Item $AzCopyPath).Exists -eq $false)
{
   $AzCopyPath = Read-Host "Input the full filePath of the AzCopy.exe, e.g.: C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
}

Set-Location (Get-ChildItem $AzCopyPath).directory.fullname

$SourceKey = (get-azureRMstorageaccountkey -Name storgumprd -ResourceGroupName gumstorage-rg-prd | where-object {$_.keyname -eq "key1"}).value
$DestKey   = (get-azureRMstorageaccountkey -Name storgum$Environnement -ResourceGroupName gumstorage-rg-$Environnement | where-object {$_.keyname -eq "key1"}).value

. $AzCopyPath /source:https://storgumprd.blob.core.windows.net/guichetunique/ /sourcekey:$SourceKey /dest:https://storgum$Environnement.blob.core.windows.net/guichetunique/ /s /y /destkey:$destkey

