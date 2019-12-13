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
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,

    [string]
    $ResourceGroupLocation = "CanadaCentral",

    [Parameter()]
    [string]
    $deploymentName = (get-date -format "yyyy-MM-dd_hh-mm"),

    [string]
    $TemplateFilePath = "template.json"
)

$AzModuleVersion = "2.0.0"
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
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#*******************************************************************************
# Script body
# Execution begins here
#*******************************************************************************
$ErrorActionPreference = "Stop"

# sign in
Write-Host "Logging in...";
# Connect-AzAccount; 

# select subscription
Write-Host "Selecting subscription  '$Subscription'";
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
$ResourceGroupName = "GumSQL-rg-" + $Environnement
$resourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (!$resourceGroup) {
    if (!$ResourceGroupLocation) {
        Write-Host "Resource group '$ResourceGroupName' does not exist. To create a new resource group, please enter a location.";
        $resourceGroupLocation = Read-Host "ResourceGroupLocation";
    }
    Write-Host "Creating resource group '$ResourceGroupName' in location '$ResourceGroupLocation'";
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Tag @{Environnement = $Environnement }
}
else {
    Write-Host "Using existing resource group '$ResourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if (Test-Path $ParametersFilePath) {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -TemplateParameterFile $ParametersFilePath;
}
else {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath;
}

if ( $Environnement -eq "prd") { write-warning "Il faut copier la BD manuellement" } else {

    $databaseName = "BdGum-prd"
    $serverName = "SqlGum-prd"
    $resourceGroupName = "GumSQL-rg-prd"

    $TargetDatabaseName = "BdGum-" + $Environnement
    $TargetServerName = "SqlGum-" + $Environnement
    $TargetResourceGroupName = "GumSQL-rg-" + $Environnement

    "Removing database $TargetDatabaseName"
    if (get-AzureRmSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
        Remove-AzureRmSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
    }
    "Copying database $databaseName from server $servername to database $TargetDatabaseName on $TargetServerName"
    New-AzureRmSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
        -CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName

}

# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa
if ( $Environnement -eq "dev" -or $Environnement -eq "qa" -or $Environnement -eq "devops") {
    $QA = Get-AzureRmADGroup -SearchString "QA"
    if (!( get-AzureRmRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $qa.Id -RoleDefinitionName contributor)) {
        New-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName
    }
    $dev = Get-AzureRmADGroup -SearchString "dev"
    if (!( get-AzureRmRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $dev.Id -RoleDefinitionName owner)) {
        New-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner -ResourceGroupName $resourceGroupName
    }
}
