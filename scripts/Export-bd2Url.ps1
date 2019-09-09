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
    $Environnement = "prd",

    [Parameter()]
    [string]
    $TargetUrl = 'https://gumbackups.blob.core.windows.net/sql-backup/'
)
import-module azureRM.sql, azureRM.keyvault, azureRM.Storage

$servers = "sqlguminterne-$Environnement", "sqlgum-$Environnement"
[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Environnement
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Environnement )).secretvalue

foreach ( $server in $Servers ) {
    $databases = get-azureRMsqlserver | where-object {$_.ServerName -eq $server} | get-azureRMsqldatabase | where-object { $_.Databasename -notlike "master" } 
    $databases | ForEach-Object { New-azureRMSqlDatabaseExport -ServerName $_.servername -DatabaseName $_.databasename -ResourceGroupName $_.ResourceGroupName -StorageKey $storageKey -StorageKeyType $StorageAccessKey -StorageUri $( $TargetUrl + $_.DatabaseName + "_" + $(get-date -Format "yyyy-MM-dd_hh-mm") + '.bacpac' ) -AdministratorLogin $AdministratorLogin -AdministratorLoginPassword $pass}
}
