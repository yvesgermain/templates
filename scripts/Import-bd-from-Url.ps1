<#
.Synopsis
   Importe Bd d'un storage sur Azure
.DESCRIPTION
   Copy BdAppsInterne-xxx de l'Destination $SourceEnv vers l'Destination $TargetEnv et redémarre le site web $TargetEnv
.EXAMPLE
   .\Import-bd-from-url -Destination dev 
.EXAMPLE
   .\Import-bd-from-Url.ps1 -Destination qa

#>
Param(
   [Parameter()]
   [ValidateSet("dev", "qa", "prd", "devops")]
   [string]
   $Destination,

   [ValidateSet("dev", "qa", "prd", "devops")]
   [string]
   $source = "prd",

   [Parameter()]
   [string]
   $TargetUrl = 'https://gumbackups.blob.core.windows.net/sql-backup/'
)
import-module azureRM.sql, azureRM.keyvault, azureRM.Storage

$server = "sqlguminterne-$Destination"
[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Destination
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Destination )).secretvalue

$gum = Get-AzureStorageAccount -StorageAccountname gumbackups -resourcegroupname infrastructure

$DBName = (Get-AzureStorageBlob -Context $gum.context -Container sql-backup | Where-Object { $_.name -like "BdAppsInterne-$source*" } | Sort-Object LastModified -Descending)[0] | Select-Object name
$database = get-azureRMsqlserver | where-object { $_.ServerName -eq $server } | get-azureRMsqldatabase | where-object { $_.Databasename -like "BdAppsInterne-*" } 
$database | Remove-AzureRMsqldatabase
$Restore = $database | ForEach-Object { New-azureRMSqlDatabaseImport `
      -ServerName $_.servername `
      -DatabaseName $_.databasename `
      -ResourceGroupName $_.ResourceGroupName `
      -StorageKey $storageKey `
      -StorageKeyType $StorageAccessKey `
      -StorageUri $($TargetUrl + $DBName.name) `
      -AdministratorLogin $AdministratorLogin `
      -AdministratorLoginPassword $pass `
      -edition $_.edition `
      -ServiceObjectiveName S0 `
      -DatabaseMaxSizeBytes 30gb 
}

While ( (Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $Restore.OperationStatusLink).status -ne "Succeeded") {
   Start-sleep -Seconds 20;
   (Get-AzureRMSqlDatabaseImportExportStatus -OperationStatusLink $Restore.OperationStatusLink)
}