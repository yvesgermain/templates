<#
.Synopsis
   Importe Bd d'un storage sur Azure
.DESCRIPTION
   Copy les Bds de 'https://gumbackups.blob.core.windows.net/sql-backup/' vers la Destination 
.EXAMPLE
   .\Restore-bd -Destination dev 
.EXAMPLE
   .\Restore-bd.ps1 -Destination qa

#>
Param(

    [ValidateSet("dev", "qa", "prd", "devops", "stage")]
    [string]
    $Source,

    [Parameter(Mandatory = $True)]
    [ValidateSet("dev", "qa", "prd", "devops", "stage")]
    [string]
    $Destination,

    [Parameter(Mandatory = $True)]
    [ValidateSet("Gum", "AppsInterne", "Veille", "null")]
    [string]
    $BD,

    [Parameter(Mandatory = $false,
        HelpMessage = "Donner la date du restore dans le format yyyyMMdd, sinon on prendra le dernier backup")]
     $date,

    [Parameter()]
    [string]
    $TargetUrl = 'https://gumbackups.blob.core.windows.net/sql-backup/'
)
if ($bd -eq "null") {Write-Output "Aucune BD à restaurer"; return 0}
If (!$Source) { $Source -eq $Destination }

if (get-module -ListAvailable AzureRm) { 
    import-module azureRM.sql, azureRM.keyvault, azureRM.Storage 
} else {
    if (get-module -ListAvailable Az.sql) { import-module az.sql } 
}

[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Destination
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Destination )).secretvalue

$Context = (Get-AzureRmStorageAccount -StorageAccountname gumbackups -resourcegroupname infrastructure).context

if ($date) {$date= "{0:####-##-##}" -f $date}
if (!$date) {
    $BDs = Get-AzureStorageBlob -Context $context -container sql-backup  | Where-object { $_.Name -like ("Bd" + $BD + "-" + $source + "_*") }
    if (!$BDs) { Write-Warning "$BD-$source n'existe pas" ; break }
    if ($BDs -is [array]) { $dateFormat = (($BDs| sort-object -Property LastModified -Descending)[0]).lastmodified }
    $date = "{0:yyyy-MM-dd}" -f $dateformat
}

switch ($BD) {
    "Gum" {
        $server = "sqlgum-$Destination"
        $resourcegroup = "Gumsql-rg-$Destination"
        $BdDest = "BdGum-$Destination"
        $BdSource = "BdGum-" + $Source + "_" + $date
    }
    "AppsInterne" {
        $server = "sqlguminterne-$Destination"
        $resourcegroup = "sqlapps-rg-$Destination"
        $BdDest = "BdAppsInterne-$Destination"
        $BdSource = "BdAppsInterne-" + $Source + "_" + $date
    }
    "Veille" {   
        $server = "sqlguminterne-$Destination"
        $resourcegroup = "sqlapps-rg-$Destination"
        $BdDest = "BdVeille-$Destination"
        $BdSource = "BdVeille-" + $Source + "_" + $date
    }
}

Write-output "Le serveur = $server `nResourcegroup = $resourcegroup `nBD source = $Bdsource`nBD destination = $BdDest"

[array] $Bdname = Get-AzureStorageBlob -Context $context -Container sql-backup | Where-Object { $_.name -like ($bdSource + "*") } ;
if ( !$Bdname ) { write-warning "$BdSource n'existe pas"; break} 
$Bdname = ($Bdname | Sort-Object -Descending LastModified )[0]
$databases = get-azureRMsqlserver -name $server -resourcegroupname $resourcegroup | get-azureRMsqldatabase | where-object { $BdDest -contains $_.Databasename } 
if ( $databases) { $databases | Remove-AzureRMsqldatabase }

$Restore = New-azureRMSqlDatabaseImport `
    -ServerName $server `
    -DatabaseName $BdDest `
    -ResourceGroupName $resourcegroup `
    -StorageKey $storageKey `
    -StorageKeyType $StorageAccessKey `
    -StorageUri ($TargetUrl + $BdName.name) `
    -AdministratorLogin $AdministratorLogin `
    -AdministratorLoginPassword $pass `
    -edition standard `
    -ServiceObjectiveName S0 `
    -DatabaseMaxSizeBytes 30gb ;

return $restore.OperationStatusLink
