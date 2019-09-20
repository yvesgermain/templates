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
param(
[Parameter(Mandatory = $True)]
[string]
[ValidateSet("dev", "qa", "prd", "devops")] 
$environnement
)

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# Register RPs

#Create or check for existing resource group

if ( $Environnement -eq "prd") { write-warning "Il faut copier la BD manuellement" } else {

    $databaseName = "BdGum-prd"
    $serverName = "sqlgum-prd"
    $resourceGroupName = "GumSQL-rg-prd"

    $TargetDatabaseName = "BdGum-" + $Environnement
    $TargetServerName = "sqlgum-" + $Environnement
    $TargetResourceGroupName = "GumSQL-rg-" + $Environnement

    "Removing database $TargetDatabaseName"
    if (get-azureRMSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
        Remove-azureRMSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
    }
    "Copying database $databaseName from server $servername to database $TargetDatabaseName on $TargetServerName"
    New-azureRMSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
        -CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName

}
$resourceGroupName = $TargetResourceGroupName
# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa
if ( $Environnement -eq "dev" -or $Environnement -eq "qa") {
    $QA = Get-AzureRmADGroup -SearchString "QA"
    New-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName -AllowDelegation
    $dev = Get-AzureRmADGroup -SearchString "dev"
    New-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroupName -AllowDelegation
}