<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
 [string]
 $resourceGroupLocation = "CanadaCentral",

 [Parameter()]
 [string]
 $deploymentName = (get-date -format "yyyy-MM-dd_hh-mm"),

 [string]
 $templateFilePath = "template.json",

 [Parameter(Mandatory=$True)]
 [string]
 [ValidateSet("dev", "qa", "prd", "devops")]
 $Environnement,

 [Parameter()]
 [String]
 $AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
)

$parametersFilePath = "parameters-" + $Environnement + ".json" 

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# sign in
Write-Host "Logging in...";
# connect-AzAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
# Select-AzSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.sql");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroupName = "Storage-rg-$environnement"
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Tag @{Environnement= $Environnement}
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $parametersFilePath) {
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
} else {
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile $templateFilePath;
}

get-azstorageaccount -resourcegroupName $resourceGroupName | where-object {$_.storageaccountname -like "storappsinterne*"} | foreach-object { 
    $name = $_.storageaccountname; 
    Get-AzStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $_.StorageAccountName } | where-object { $_.keyname -like "key1"} | ForEach-Object { 
        $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
        Set-AzKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
    }

get-azstorageaccount -resourcegroupName $resourceGroupName | where-object {$_.storageaccountname -like "storveillefunc*"} | foreach-object { 
    $name = $_.storageaccountname; 
    Get-AzStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $_.StorageAccountName } | where-object { $_.keyname -like "key1"} | ForEach-Object { 
        $Secret = ConvertTo-SecureString -String $_.value -AsPlainText -Force; 
        Set-AzKeyVaultSecret -VaultName 'gumkeyvault' -Name $name -SecretValue $Secret -ContentType "Storage key"
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

push-location
Set-Location (Get-ChildItem $AzCopyPath).directory.fullname

$SourceKey = (get-azstorageaccountkey -Name storappsinterneprd -ResourceGroupName storage-rg-prd | where-object {$_.keyname -eq "key1"}).value
$DestKey   = (get-azstorageaccountkey -Name storappsinterne$Environnement -ResourceGroupName storage-rg-$Environnement | where-object {$_.keyname -eq "key1"}).value

# . $AzCopyPath /source:https://storappsinterneprd.blob.core.windows.net/appsinterne/ /sourcekey:$SourceKey /dest:https://storappsinterne$Environnement.blob.core.windows.net/appsinterne/ /s /y /destkey:$destkey

pop-location

# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa
if ( $Environnement -eq "dev" -or $Environnement -eq "qa" -or $Environnement -eq "devops") {
    $QA = Get-AzADGroup -SearchString "QA"
    if (!( get-AzRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $qa.Id -RoleDefinitionName contributor)) {
        New-AzRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName
    }
    $dev = Get-AzADGroup -SearchString "dev"
    if (!( get-AzRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $dev.Id -RoleDefinitionName owner)) {
        New-AzRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner -ResourceGroupName $resourceGroupName
    }
}

