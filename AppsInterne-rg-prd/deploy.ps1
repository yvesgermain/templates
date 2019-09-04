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

    [string]
    $parametersFilePath = "parameters.json",
 
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
 
)

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
# Connect-AzAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
# Select-AzSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.insights", "microsoft.storage", "microsoft.web");
if ($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach ($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group

$resourceGroupName = "AppsInterne-rg-$environnement"
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (!$resourceGroup) {
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if (!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Tag @{Environnement = $Environnement }
}
else {
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if (Test-Path $parametersFilePath) {
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
}
else {
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile $templateFilePath;
}

<#
$APIVersion = ((Get-AzResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]

$WebAppConfig = (Get-AzResource -ResourceType Microsoft.Web/sites/config -ResourceName Appsinterne-$Environnement -ResourceGroupName Appsinterne-rg-$Environnement -ApiVersion $APIVersion)

$priority = 180;  
$IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
[System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;
(Get-azwebapp -name Appsinterne-$Environnement).PossibleOutboundIpAddresses.split(",") | ForEach-Object { 
    $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
    $webip.ipAddress = $_ + '/32';  
    $webip.action = "Allow"; 
    $priority = $priority + 20 ; 
    $webIP.priority = $priority;  
    $ArrayList.Add($webIP); 
    Remove-Variable webip
}

$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
$WebAppConfig | Set-AzResource  -ApiVersion $APIVersion -Force -Verbose

$SourceEnv = "prd"
$TargetEnv = $Environnement
$BdArray = ("BdAppsInterne-","BdVeille-")
import-module az.sql, az.Websites

foreach( $Bd in $Bdarray) {
   $databaseName = $Bd + $SourceEnv
   $serverName = "sqlguminterne-" + $SourceEnv
   $resourceGroupName = "sqlapps-rg-" +  $SourceEnv

   $TargetDatabaseName = $Bd + $TargetEnv
   $TargetServerName = "sqlguminterne-" + $TargetEnv
   $TargetResourceGroupName = "sqlapps-rg-" +  $TargetEnv

   "Removing database $TargetDatabaseName"
   if (get-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
   Remove-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
   }
   "Copying database  $databaseName  from server $servername to database $TargetDatabaseName on $TargetServerName"
   New-azSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
   -CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName
}
#>