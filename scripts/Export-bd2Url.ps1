<#
.Synopsis
   Copy Bd dans un storage sur Azure
.DESCRIPTION
   Copy BdAppsInterne-xxx de l'environnement $SourceEnv vers l'environnement $TargetEnv et redémarre le site web $TargetEnv
.EXAMPLE
   .\Export-bd2url -SourceEnv prd 
.EXAMPLE
   .\Export-bd2Url.ps1 -SourceEnv prd -Bd BdAppsInterne- -BDserver sqlguminterne-

#>
Param(
        [Parameter()]
        [ValidateSet("dev", "qa", "prd", "devops")]
        [string]
        $SourceEnv = "prd",

        [Parameter()]
        [string]
        $TargetUrl = 'https://gumbackups.blob.core.windows.net/sql-backup/',

        [Parameter()]
        [ValidateSet("BdAppsInterne", "BdVeille")]
        [string] 
        $Bd = 'BdAppsInterne', 

        [Parameter()]
        [ValidateSet("sqlguminterne", "sqlgum")]
        [string] 
        $BDserver = 'sqlguminterne'
    )
import-module azureRM.sql, azureRM.keyvault, azureRM.Storage

$databaseName = $Bd + "-" + $SourceEnv
$serverName = $BDserver + "-" + $SourceEnv
$resourceGroupName = "SQLapps-rg-"  + $SourceEnv
[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey  = "StorageAccessKey"

$targetURI= $( $TargetUrl + $Bd + $SourceEnv  + $(get-date -Format "yyyy-MM-dd_hh-mm") + '.bacpac' )
$AdministratorLogin = "sqladmin" + $SourceEnv
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $SourceEnv)).secretvalue

"New-azureRMSqlDatabaseExport -DatabaseName $databaseName -ServerName $serverName –Storagekey $storageKey -StorageKeyType $StorageAccessKey -StorageUri $targetURI -AdministratorLogin $AdministratorLogin -AdministratorLoginPassword $pass -ResourceGroupName $resourceGroupName"

New-azureRMSqlDatabaseExport -DatabaseName $databaseName -ServerName $serverName –Storagekey $storageKey -StorageKeyType $StorageAccessKey -StorageUri $targetURI -AdministratorLogin $AdministratorLogin -AdministratorLoginPassword $pass -ResourceGroupName $resourceGroupName
