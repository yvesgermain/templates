<#
.Synopsis
   Description sommaire
.DESCRIPTION
   Description détaillée
.EXAMPLE
   Exemple d’usage de cette applet de commande
.EXAMPLE
   Autre exemple de l’usage de cette applet de commande
.INPUTS
   Entrées de cette applet de commande (le cas échéant)
.OUTPUTS
   Sortie de cette applet de commande (le cas échéant)
.NOTES
   Remarques générales
.COMPONENT
   Composant auquel cette applet de commande appartient
.ROLE
   Rôle auquel cette applet de commande appartient
.FUNCTIONALITY
   Fonctionnalité qui décrit le mieux cette applet de commande
#>
Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateSet("dev", "qa", "prd", "devops")]
        [string]
        $SourceEnv = "prd",

        [Parameter(Mandatory=$true)]
        [ValidateSet("dev", "qa", "prd", "devops")]
        [string]
        $TargetEnv= "devops"
    )
import-module az.sql, Az.Websites

$databaseName = "BdAppsInterne-" + $SourceEnv
$serverName = "sqlguminterne-" + $SourceEnv
$resourceGroupName = "sqlapps-rg-" +  $SourceEnv

$TargetDatabaseName = "BdAppsInterne-" + $TargetEnv
$TargetServerName = "sqlguminterne-" + $TargetEnv
$TargetResourceGroupName = "sqlapps-rg-" +  $TargetEnv

Remove-AzSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName

New-AzSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
-CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName

Restart-AzWebApp -Name Appsinterne-$TargetEnv -ResourceGroupName AppsInterne-rg-$TargetEnv