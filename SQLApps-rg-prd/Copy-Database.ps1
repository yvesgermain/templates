param(
 [ValidateSet("dev", "qa", "prd", "devops")] 
  $SourceEnv = "prd",
  $Environnement
)

$environnement = $resourceGroupName.split("-")[-1]
$username = "sqladmin$environnement@sqlguminterne-$environnement.database.windows.net"
$password = (Get-AzureKeyVaultSecret -VaultName gumkeyvault -Name sqladmin$environnement  ).SecretValue
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)

# invoke-sqlcmd -ServerInstance sqlguminterne-devops.database.windows.net -Database BdAppsInterne-devops -Query "select @@version" -Credential $cred

invoke-sqlcmd -ServerInstance sqlguminterne-$environnement.database.windows.net -Database BdAppsInterne-$environnement -InputFile c:\soquij\SQL\Install\createV8.sql -Credential $cred

$BdArray = ("BdAppsInterne-","BdVeille-")
foreach( $Bd in $Bdarray) {
    $databaseName = $Bd + $SourceEnv
    $serverName = "sqlguminterne-" + $SourceEnv
    $resourceGroupName = "sqlapps-rg-" +  $SourceEnv

    $TargetDatabaseName = $Bd + $Environnement
    $TargetServerName = "sqlguminterne-" + $Environnement
    $TargetResourceGroupName = "sqlapps-rg-" +  $Environnement

    "Removing database $TargetDatabaseName"
    if (get-azurermDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue)
{
    Remove-azurermSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
    }
    "Copying database $databaseName from server $servername to database $TargetDatabaseName on $TargetServerName"
    New-azureRmSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
    -CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName
 }

