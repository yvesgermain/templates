<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .EXAMPLE
    ./deploy.ps1 -subscription "Azure Subscription" -resourceGroupName myresourcegroup -resourceGroupLocation centralus

 .PARAMETER Subscription
    The subscription name or id where the template will be deployed.

 .PARAMETER ResourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER ResourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER TemplateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER ParametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(

    [string]
    $ResourceGroupLocation = "CanadaCentral",

    [string]
    $TemplateFilePath = "template.json",

    [string]
    $ParametersFilePath = "parameters.json",

    [Parameter(Mandatory = $True)]
    [string]
    $environnement,

    [Parameter()]
    [String]
    $AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
)

$AzModuleVersion = "2.0.0"

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

# Verify that the Az module is installed 
if (!(Get-InstalledModule -Name Az -MinimumVersion $AzModuleVersion -ErrorAction SilentlyContinue)) {
    Write-Host "This script requires to have Az Module version $AzModuleVersion installed..
It was not found, please install from: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps"
    exit
} 

# sign in
Write-Host "Logging in...";
# Connect-AzAccount; 

# select subscription
Write-Host "Selecting subscription '$Subscription'";
# Select-AzSubscription -Subscription $Subscription;

# Register RPs
$resourceProviders = @("microsoft.sql", "microsoft.storage", "microsoft.web");
if ($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach ($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$ResourceGroupName = "gumstorage-rg-" + $environnement
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (!$resourceGroup) {
    if (!$ResourceGroupLocation) {
        Write-Host "Resource group '$ResourceGroupName' does not exist. To create a new resource group, please enter a location.";
        $resourceGroupLocation = Read-Host "ResourceGroupLocation";
    }
    Write-Host "Creating resource group '$ResourceGroupName' in location '$ResourceGroupLocation'";
    New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation
}
else {
    Write-Host "Using existing resource group '$ResourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if (Test-Path $ParametersFilePath) {
    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -TemplateParameterFile $ParametersFilePath;
}
else {
    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath;
}

get-azstorageaccount -resourcegroupName $resourceGroupName | where-object { $_.storageaccountname -like "gumstor*" } | foreach-object { 
    $name = $_.storageaccountname; 
    Get-AzStorageAccountKey -ResourceGroupName $_.resourcegroupname -Name $_.StorageAccountName } | where-object { $_.keyname -like "key1" } | ForEach-Object {
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

$SourceKey = (get-azstorageaccountkey -Name soquijgummediastoragedev -ResourceGroupName SoquijGUM-DEV | where-object {$_.keyname -eq "key1"}).value
$DestKey   = (get-azstorageaccountkey -Name storgum$Environnement -ResourceGroupName gumstorage-rg-$Environnement | where-object {$_.keyname -eq "key1"}).value

. $AzCopyPath /source:https://soquijgummediastoragedev.blob.core.windows.net/guichetunique/ /sourcekey:$SourceKey /dest:https://storgum$Environnement.blob.core.windows.net/guichetunique/ /s /y /destkey:$destkey