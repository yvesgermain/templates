<#
.Synopsis
   Copy BdAppsInterne-xxx vers un autre serveur
.DESCRIPTION
   Copy BdAppsInterne-xxx de l'environnement $SourceEnv vers l'environnement $TargetEnv et redémarre le site web $TargetEnv
.EXAMPLE
   copy-database -SourceEnv prd -targetEnv dev

#>
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $SourceEnv = "prd",

    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $TargetEnv = "devops",

    [Parameter()]
    [validateset("BdAppsInterne", "BdVeille", "BdGum", {@('BdAppsInterne','BdVeille')}, {@('BDGum','BdAppsInterne','BdVeille')})]
    [array] 
    $BdArray = ("BDGum","BdAppsInterne", "BdVeille")
)
if ( get-module az.sql) { import-module az.sql, az.Websites } else { import-module azurerm.sql, azurerm.Websites } 

foreach ( $Bd in $Bdarray) {
    if ( $Bd -like "BdGum") {
        $databaseName = $Bd + "-" + $SourceEnv
        $serverName = "sqlgum-" + $SourceEnv
        $resourceGroupName = "GumSql-rg-" + $SourceEnv
        
        $TargetDatabaseName = $Bd + "-" + $TargetEnv
        $TargetServerName = "sqlgum-" + $TargetEnv
        $TargetResourceGroupName = "GumSql-rg-" + $TargetEnv
    }   else {
        $databaseName = $Bd + "-" + $SourceEnv
        $serverName = "sqlguminterne-" + $SourceEnv
        $resourceGroupName = "sqlapps-rg-" + $SourceEnv
        
        $TargetDatabaseName = $Bd + "-" + $TargetEnv
        $TargetServerName = "sqlguminterne-" + $TargetEnv
        $TargetResourceGroupName = "sqlapps-rg-" + $TargetEnv
    }

    "Removing database $TargetDatabaseName"
    if (get-azurermSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
        Remove-azurermSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
    }
    "Copying database  $databaseName  from server $servername to database $TargetDatabaseName on $TargetServerName"
    New-azurermSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
        -CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName

    "Redémarrer le site web AppsInterne-rg-$TargetEnv"
    switch ($Bd) { 
        "BdAppsInterne" { Restart-azurermWebApp -Name "Appsinterne-$TargetEnv" -ResourceGroupName "AppsInterne-rg-$TargetEnv" }
        "BdVeille" { Restart-azurermWebApp -Name "Veille-$TargetEnv" -ResourceGroupName "AppsInterne-rg-$TargetEnv" } ;
        "BdGum" { Restart-azurermWebApp -Name "Gum-$TargetEnv" -ResourceGroupName "GumSite-$TargetEnv"; Restart-azurermWebApp -Name "GumMaster-$TargetEnv" -ResourceGroupName "GumSite-$TargetEnv" }
    }
}