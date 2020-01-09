<#
.Synopsis
   Copy Bd dans un storage sql-backup sur Azure
.DESCRIPTION
   Copy BdAppsInterne-xxx de l'environnement $Environnement vers le stockage 'https://gumbackups.blob.core.windows.net/sql-backup/'
.EXAMPLE
   .\Export-bd2url -Environnement prd 
   .EXAMPLE
   .\Export-bd2url 
   Par défaut copie le BD de PRD
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

if (get-module -ListAvailable AzureRm) {import-module azureRM.sql, azureRM.keyvault, azureRM.Storage }

$servers = "sqlguminterne-$Environnement", "sqlgum-$Environnement"
[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Environnement
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Environnement )).secretvalue

$op = @();
foreach ( $server in $Servers ) {
    $databases = get-azureRMsqlserver | where-object {$_.ServerName -eq $server} | get-azureRMsqldatabase | where-object { $_.Databasename -notlike "master" } 
    $databases | ForEach-Object {$op += New-azureRMSqlDatabaseExport -ServerName $_.servername -DatabaseName $_.databasename -ResourceGroupName $_.ResourceGroupName -StorageKey $storageKey -StorageKeyType $StorageAccessKey -StorageUri $( $TargetUrl + $_.DatabaseName + "_" + $(get-date -Format "yyyy-MM-dd_HH-mm") + '.bacpac' ) -AdministratorLogin $AdministratorLogin -AdministratorLoginPassword $pass}
}
write-output "##vso[task.setvariable variable=op]$op"
# $op.operationstatuslink | ForEach-Object { do { $status = Get-AzurermSqlDatabaseImportExportStatus -OperationStatusLink $_ ; $status; "Sleep for 20 seconds" ; Start-Sleep -Seconds 20}  while ( $status.status -notlike "Succeeded")}

$env:op

$env:SYSTEM_TEAMFOUNDATIONSERVERURI                                                        
