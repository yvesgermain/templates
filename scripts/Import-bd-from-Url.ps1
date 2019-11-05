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
$resourcegroup = ("sqlapps-rg-" + $Destination)
$bds = "BdAppsInterne-$destination", "BdVeille-$destination"

[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Destination
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Destination )).secretvalue

$gum = Get-AzureRmStorageAccount -StorageAccountname gumbackups -resourcegroupname infrastructure

# $DBName = (Get-AzureStorageBlob -Context $gum.context -Container sql-backup | Where-Object { $_.name -like "BdAppsInterne-$source*" } | Sort-Object LastModified -Descending)[0] | Select-Object name
$databases = get-azureRMsqlserver -name $server -resourcegroupname $resourcegroup | get-azureRMsqldatabase | where-object { $BDs -contains $_.Databasename } 
$databases | Remove-AzureRMsqldatabase

$Bds | ForEach-Object { 
   $database = $_;   
   $Dbname = (Get-AzureStorageBlob -Context $gum.context -Container sql-backup | Where-Object { $_.name -like ($database.split("-")[0] + "*") } | Sort-Object -Descending LastModified  )[0];
   $Restore = New-azureRMSqlDatabaseImport `
      -ServerName $server `
      -DatabaseName $database `
      -ResourceGroupName $resourcegroup `
      -StorageKey $storageKey `
      -StorageKeyType $StorageAccessKey `
      -StorageUri ($TargetUrl + $DBName.name) `
      -AdministratorLogin $AdministratorLogin `
      -AdministratorLoginPassword $pass `
      -edition standard `
      -ServiceObjectiveName S0 `
      -DatabaseMaxSizeBytes 30gb ;

   $restore
}

