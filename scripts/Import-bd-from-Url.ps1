<#
.Synopsis
   Importe Bd d'un storage sur Azure
.DESCRIPTION
   Copy les Bds de 'https://gumbackups.blob.core.windows.net/sql-backup/' vers la Destination 
.EXAMPLE
   .\Import-bd-from-url -Destination dev 
.EXAMPLE
   .\Import-bd-from-Url.ps1 -Destination qa

#>
Param(
   [Parameter(Mandatory = $True)]
   [ValidateSet("dev", "qa", "prd", "devops")]
   [string]
   $Destination,

   [Parameter(Mandatory = $True)]
   [ValidateSet("Gum", "AppsInterne")]
   [string]
   $Site,

   [Parameter()]
   [string]
   $TargetUrl = 'https://gumbackups.blob.core.windows.net/sql-backup/'
)
if (get-module -ListAvailable AzureRm) { 
   import-module azureRM.sql, azureRM.keyvault, azureRM.Storage 
}
else {
   if (get-module -ListAvailable Az.sql) { import-module az.sql } 
}

if ( $site -eq "AppsInterne") {
   $server = "sqlguminterne-$Destination"
   $resourcegroup = "sqlapps-rg-$Destination"
   $Bds = "BdAppsInterne-$destination", "BdVeille-$destination"
}
else {
   $server = "sqlgum-$Destination"
   $resourcegroup = "Gumsql-rg-$Destination"
   $Bds = "BdGum-$destination"
}

Write-output " Le serveur = $server `n Resourcegroup = $resourcegroup `n Les Bds = $bds"

[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Destination
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Destination )).secretvalue

$gum = Get-AzureRmStorageAccount -StorageAccountname gumbackups -resourcegroupname infrastructure

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

