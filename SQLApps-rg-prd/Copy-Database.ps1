param(
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $SourceEnv = "prd",
    $Environnement
)

# $username = "sqladmin$environnement@sqlguminterne-$environnement.database.windows.net"
# $password = (Get-AzureKeyVaultSecret -VaultName gumkeyvault -Name sqladmin$environnement  ).SecretValue
# $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
# $resourceGroupName = "sqlapps-rg-$environnement"

# invoke-sqlcmd -ServerInstance sqlguminterne-devops.database.windows.net -Database BdAppsInterne-devops -Query "select @@version" -Credential $cred

# invoke-sqlcmd -ServerInstance sqlguminterne-$environnement.database.windows.net -Database BdAppsInterne-$environnement -InputFile c:\soquij\SQL\Install\createV8.sql -Credential $cred


$BdArray = ("BdAppsInterne-", "BdVeille-")
foreach ( $Bd in $Bdarray) {
    $databaseName = $Bd + $SourceEnv
    $serverName = "sqlguminterne-" + $SourceEnv
    $resourceGroupName = "sqlapps-rg-" + $SourceEnv

    $TargetDatabaseName = $Bd + $Environnement
    $TargetServerName = "sqlguminterne-" + $Environnement
    $TargetResourceGroupName = "sqlapps-rg-" + $Environnement

    "Removing database $TargetDatabaseName"
    if (get-azurermSQLDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue) {
        Remove-azurermSqlDatabase -DatabaseName $TargetDatabaseName -ServerName $TargetServerName -ResourceGroupName $TargetResourceGroupName
    }
    "Copying database $databaseName from server $servername to database $TargetDatabaseName on $TargetServerName"
    New-azureRmSqlDatabaseCopy -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName `
        -CopyResourceGroupName $TargetResourceGroupName -CopyServerName $TargetServerName -CopyDatabaseName $TargetDatabaseName
}

# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa
if ( $Environnement -eq "dev" -or $Environnement -eq "qa") {
    $QA = Get-AzureRmADGroup -SearchString "QA"
    if (!(Get-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName)) {
        New-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName -AllowDelegation
    }
    $dev = Get-AzureRmADGroup -SearchString "dev"
    if (!(Get-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner -ResourceGroupName $resourceGroupName)) {
        New-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroupName -AllowDelegation
    }
}