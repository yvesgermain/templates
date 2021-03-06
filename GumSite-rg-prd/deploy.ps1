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
    [Parameter(Mandatory=$True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
   
    [string]
    $ResourceGroupLocation = "CanadaCentral",
   
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
$resourceProviders = @("microsoft.sql","microsoft.storage","microsoft.web");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$ResourceGroupName  = "GumSite-rg-" + $Environnement
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    if(!$ResourceGroupLocation) {
        Write-Host "Resource group '$ResourceGroupName' does not exist. To create a new resource group, please enter a location.";
        $resourceGroupLocation = Read-Host "ResourceGroupLocation";
    }
    Write-Host "Creating resource group '$ResourceGroupName' in location '$ResourceGroupLocation'";
    New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Tag @{Environnement = $Environnement }
}
else{
    Write-Host "Using existing resource group '$ResourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $ParametersFilePath) {
    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -TemplateParameterFile $ParametersFilePath;
} else {
    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath;
}

$Sites = "Gum-$environnement", "gummaster-$environnement"
foreach ( $site in $sites) {
    $APIVersion = ((Get-AzResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
    $WebAppConfig = (Get-AzResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName GumSite-rg-$Environnement -ApiVersion $APIVersion)
    $priority = 180;  
    $IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
    $IpSecurityRestrictions

    [System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

    (Get-azwebapp -name $site).PossibleOutboundIpAddresses.split(",") | ForEach-Object { 
        $Ip = $_;
        if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
            $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
            $webip.ipAddress = $_ + '/32';  
            $webip.action = "Allow"; 
            $webip.name = "Allow_Address_Interne"
            $priority = $priority + 20 ; 
            $webIP.priority = $priority;  
            $ArrayList.Add($webIP); 
            Remove-Variable webip
        }
    }
    $WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
    Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
    
}

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
