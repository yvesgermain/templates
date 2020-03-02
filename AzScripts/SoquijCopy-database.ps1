<#$serverName ='appsinterne-devbdserver'
$resourceGroupName = "apps_satellites-DEV"
$databaseName = "AppsInternebddev"

$TargetEnv = "prd"
$bd = "BdAppsInterne-"
$TargetDatabaseName = $Bd + $TargetEnv
$TargetServerName = "sqlguminterne-" + $TargetEnv
$TargetResourceGroupName = "sqlapps-rg-" +  $TargetEnv

if (get-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
Remove-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
}
"Copying database  $databaseName  from server $servername to database $TargetDatabaseName on $TargetServerName"
New-azSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
-CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName

#>
 
$databaseName = "tbl_VeilleDeContenuExterne"
$servername   = "soquijVeilleDeContenusqlserver"
$resourceGroupName = "apps_satellites-DEV"

$bd = "BdVeille-"

$TargetDatabaseName = $Bd + $TargetEnv
$TargetServerName = "sqlguminterne-" + $TargetEnv
$TargetResourceGroupName = "sqlapps-rg-" +  $TargetEnv


if (get-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
Remove-azSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
}
"Copying database $databaseName from server $servername to database $TargetDatabaseName on $TargetServerName"
New-azSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
-CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName
