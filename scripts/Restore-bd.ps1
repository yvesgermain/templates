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

    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Source,

    [Parameter(Mandatory = $True)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Destination,

    [Parameter(Mandatory = $True)]
    [ValidateSet("Gum", "AppsInterne", "Veille")]
    [string]
    $BD,

    [Parameter()]
    [string]
    $TargetUrl = 'https://gumbackups.blob.core.windows.net/sql-backup/'
)
If (!$Source) { $Source -eq $Destination }

if (get-module -ListAvailable AzureRm) { 
    import-module azureRM.sql, azureRM.keyvault, azureRM.Storage 
} else {
    if (get-module -ListAvailable Az.sql) { import-module az.sql } 
}

switch ($BD) {
    "Gum" {
        $server = "sqlgum-$Destination"
        $resourcegroup = "Gumsql-rg-$Destination"
        $BdDest = "BdGum-$destination"
        $BdSource = "BdGum-$Source"
    }
    "AppsInterne" {
        $server = "sqlguminterne-$Destination"
        $resourcegroup = "sqlapps-rg-$Destination"
        $BdDest = "BdAppsInterne-$destination"
        $BdSource = "BdAppsInterne-$Source_"
    }
    "Veille" {   
        $server = "sqlguminterne-$Destination"
        $resourcegroup = "sqlapps-rg-$Destination"
        $BdDest = "BdVeille-$destination"
        $BdSource = "BdVeille-$Source"
    }
}

Write-output " Le serveur = $server `n Resourcegroup = $resourcegroup `nBD source = $Bdsource`nBD destination = $BdDest"

[string] $Storagekey = (Get-azureRMStorageAccountKey -ResourceGroupName infrastructure -Name gumbackups ).value[0]
$StorageAccessKey = [Microsoft.Azure.Commands.Sql.ImportExport.Model.StorageKeyType]::StorageAccessKey

$AdministratorLogin = "sqladmin" + $Destination
$pass = (Get-azureKeyVaultSecret -VaultName gumkeyvault -name $("sqladmin" + $Destination )).secretvalue

$gum = Get-AzureRmStorageAccount -StorageAccountname gumbackups -resourcegroupname infrastructure

$databases = get-azureRMsqlserver -name $server -resourcegroupname $resourcegroup | get-azureRMsqldatabase | where-object { $BdDest -contains $_.Databasename } 
$databases | Remove-AzureRMsqldatabase 

$Bdname = (Get-AzureStorageBlob -Context $gum.context -Container sql-backup | Where-Object { $_.name -like ($bdSource + "*") } | Sort-Object -Descending LastModified  )[0];
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

$restore


