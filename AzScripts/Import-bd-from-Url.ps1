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
   
   [string]
   [ValidateSet("dev", "qa", "prd", "devops")]
   $Source,

   [Parameter(Mandatory = $True)]
   [ValidateSet("Gum", "AppsInterne")]
   [string]
   $Site,

   [Parameter()]
   [string]
   $TargetUrl = 'https://gumbackups.blob.core.windows.net/sql-backup/'
)

if (get-module -ListAvailable Az) { 
   import-module Az.sql, Az.keyvault, Az.Storage 
} else {
   if (get-module -ListAvailable Az.sql) { import-module az.sql } 
}

if (!$Source) {$source = $destination}
if ( $site -eq "AppsInterne") {
   $server = "sqlguminterne-$Destination"
   $resourcegroup = "sqlapps-rg-$Destination"
   $Bds = "BdAppsInterne-$destination", "BdVeille-$destination"
} else {
   $server = "sqlgum-$Destination"
   $resourcegroup = "Gumsql-rg-$Destination"
   $Bds = "BdGum-$destination"
}

Write-output "Le serveur = $server `nResourcegroup = $resourcegroup `nLes Bds = $bds"

[string] $Storagekey = (Get-AzStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Destination
$pass = (Get-AzKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Destination )).secretvalue

$gum = Get-AzStorageAccount -StorageAccountname gumbackups -resourcegroupname infrastructure

$databases = get-Azsqlserver -name $server -resourcegroupname $resourcegroup | get-Azsqldatabase | where-object { $BDs -contains $_.Databasename } 
$databases | Remove-Azsqldatabase

$op = @();
$BDs | ForEach-Object { 
   $database = $_;
   $sourceBD = $_.split("-")[0] + "-" + $Source
   $Dbname = (Get-AzStorageBlob -Context $gum.context -Container sql-backup | Where-Object { $_.name -like "$SourceBD*"} | Sort-Object -Descending LastModified  )[0];
   $op += New-AzSqlDatabaseImport `
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

}

# $op.operationstatuslink | ForEach-Object { do { $status = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $_ ; $status; "Sleep for 20 seconds" ; Start-Sleep -Seconds 20}  while ( $status.status -notlike "Succeeded")}

Write-Output "Exporte variable Op vers C:\temp\Import-$Destination.xml"
$op | Export-Clixml -Path ( "C:\temp\Import-" + $site + '-' + $Destination + ".xml")
$op