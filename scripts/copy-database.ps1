<#
.Synopsis
   Copy BdAppsInterne-xxx vers un autre serveur
.DESCRIPTION
   Copy BdAppsInterne-xxx de l'environnement $SourceEnv vers l'environnement $TargetEnv et redémarre le site web $TargetEnv
.EXAMPLE
   copy-database -SourceEnv prd -targetEnv dev

#>
Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("dev", "qa", "prd", "devops")]
        [string]
        $SourceEnv = "prd",

        [Parameter(Mandatory=$true)]
        [ValidateSet("dev", "qa", "prd", "devops")]
        [string]
        $TargetEnv = "devops",

        [Parameter(Mandatory=$true)]
        [ValidateSet("BdAppsInterne-", "BdVeille-")]
        [string] 
        $Bd = "BdAppsInterne-"
    )
import-module azurerm.sql, AzureRm.Websites

$databaseName = $Bd + $SourceEnv
$serverName = "sqlguminterne-" + $SourceEnv
$resourceGroupName = "sqlapps-rg-" +  $SourceEnv

$TargetDatabaseName = $Bd + $TargetEnv
$TargetServerName = "sqlguminterne-" + $TargetEnv
$TargetResourceGroupName = "sqlapps-rg-" +  $TargetEnv

# removing database $TargetDatabaseName
if (get-azureRmSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
Remove-azureRmSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
}
New-azureRmSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
-CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName

Restart-azureRmWebApp -Name Appsinterne-$TargetEnv -ResourceGroupName AppsInterne-rg-$TargetEnv