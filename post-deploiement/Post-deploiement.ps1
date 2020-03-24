$stockage = @(
    @{Storage = "storgum"        ; ResourceGroupName = "GumStorage-rg-" ; Account = "storgum"        ; container = "guichetunique" }
    @{Storage = "storappsinterne"; ResourceGroupName = "AppsStorage-rg-"; Account = "storappsinterne"; container = "appsinterne" }
    @{Storage = "storveillefunc" ; ResourceGroupName = "AppsStorage-rg-"; Account = "storveillefunc" ; Container = "storveillefunc" }
)
$SQL = @(
    @{Serveur = "sqlgum-"        ; ResourceGroupName = "GumSql-rg-" ; BD = "BdGum-" }
    @{Serveur = "sqlguminterne-" ; ResourceGroupName = "SQLApps-rg-"; BD = "BdAppsInterne-" }
    @{Serveur = "sqlguminterne-" ; ResourceGroupName = "SQLApps-rg-"; BD = "BdVeille-" }
)
function Test-azstorageaccount (
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [Parameter(Mandatory = $True)]
    [string]
    $Storage,
    $ResourceGroupName,
    $Account,
    $container
){
    $Context = get-azstorageaccount -resourcegroupName $ResourceGroupName$Environnement -name $Account$Environnement -ErrorAction SilentlyContinue
    if ( $null -ne $Context) { $true } else { $false }
}
function Test-azstorageContainer (
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [Parameter(Mandatory = $True)]
    [string]
    $Storage,
    $ResourceGroupName,
    $Account,
    $container
) {    
    $Context = get-azstorageaccount -resourcegroupName $ResourceGroupName$Environnement -name $Account$Environnement -ErrorAction SilentlyContinue
    if ( get-AzStorageContainer -context $Context.context -container $container -ErrorAction SilentlyContinue) { $true } else { $false }
}

function Test-azStorageBlob (
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [Parameter(Mandatory = $True)]
    [string]
    $Storage,
    $ResourceGroupName,
    $Account,
    $container
) {    
    "get-azstorageaccount -resourcegroupName ($ResourceGroupName + $Environnement) -name $Account"
    $Context = get-azstorageaccount -resourcegroupName $ResourceGroupName$Environnement -name $Account$Environnement -ErrorAction SilentlyContinue
    if ( get-AzStorageBlob -context $Context.context -container $Container -ErrorAction SilentlyContinue) { $true } else { $false }
}

function Test-azSqlTables(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement, 
    $Serveur, 
    $ResourceGroupName, 
    $BD
) {
    $password = (Get-AzKeyVaultSecret -VaultName gumkeyvault -Name "sqladmin$environnement").SecretValueText
    $query = "set nocount on; SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"                           
    SQLCMD.EXE -S "$Serveur.database.windows.net" -d $BD -G -U "sqladmin$Environnement@gumqc.OnMicrosoft.com" -P $password -Q $Query -h -1
}