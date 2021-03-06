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
 $Environnement
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
$resourceGroupName = "SQLApps-rg-$environnement"
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
# Set-AzSqlServerActiveDirectoryAdministrator -ResourceGroupName sqlapps-rg-prd -ServerName sqlguminterne-prd -DisplayName sqladminprd@gumqc.OnMicrosoft.com

# $cred = get-credential -UserName sqladminprd@sqlguminterne-prd.database.windows.net -message SQLadmin
import-module az.sql 

$username = "sqladmin$environnement@sqlguminterne-$environnement.database.windows.net"
$password = (Get-AzKeyVaultSecret -VaultName gumkeyvault -Name sqladmin$environnement  ).SecretValue
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)

# invoke-sqlcmd -ServerInstance sqlguminterne-devops.database.windows.net -Database BdAppsInterne-devops -Query "select @@version" -Credential $cred

<# invoke-sqlcmd -ServerInstance sqlguminterne-$environnement.database.windows.net -Database BdAppsInterne-$environnement -InputFile c:\soquij\SQL\Install\createV8.sql -Credential $cred

$SourceEnv = "prd"
$TargetEnv = $Environnement
$BdArray = ("BdAppsInterne-","BdVeille-")
foreach( $Bd in $Bdarray) {
    $databaseName = $Bd + $SourceEnv
    $serverName = "sqlguminterne-" + $SourceEnv
    $resourceGroupName = "sqlapps-rg-" +  $SourceEnv

    $TargetDatabaseName = $Bd + $TargetEnv
    $TargetServerName = "sqlguminterne-" + $TargetEnv
    $TargetResourceGroupName = "sqlapps-rg-" +  $TargetEnv

    "Removing database $TargetDatabaseName"
    if (get-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue)
{
    Remove-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
    }
    "Copying database $databaseName from server $servername to database $TargetDatabaseName on $TargetServerName"
    New-azSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
    -CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName
 }
#>
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
