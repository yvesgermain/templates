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
$WebApp = @(
    @{App = "Gum-"        ; ResourceGroupName = "GumSite-rg-"; Kind = "App" }
    @{App = "GumMaster-"  ; ResourceGroupName = "GumSite-rg-"; Kind = "App"}
    @{App = "GumSolr-"    ; ResourceGroupName = "GumSite-rg-"; Kind = "App"}
    @{App = "AppsInterne-"; ResourceGroupName = "AppsInterne-rg-"; Kind = "App" }
    @{App = "Veille-"     ; ResourceGroupName = "AppsInterne-rg-"; Kind = "App" }
    @{App = "Veille-func-"; ResourceGroupName = "AppsInterne-rg-"; Kind = "AppFunction" }
)
function Test-azstorageaccount (
    [string]
    $Storage,
    $ResourceGroupName,
    $Account,
    $container
){
    $Context = get-azstorageaccount -resourcegroupName $ResourceGroupName -name $Account -ErrorAction SilentlyContinue
    if ( $null -ne $Context) { $true } else { $false }
}
function Test-azstorageContainer (
    [string]
    $Storage,
    $ResourceGroupName,
    $Account,
    $container
) {    
    $Context = get-azstorageaccount -resourcegroupName $ResourceGroupName -name $Account -ErrorAction SilentlyContinue
    if ( get-AzStorageContainer -context $Context.context -container $container -ErrorAction SilentlyContinue) { $true } else { $false }
}

function Test-azStorageBlob (
    [string]
    $Environnement, 
    $Storage,
    $ResourceGroupName,
    $Account,
    $container
) {    
    "get-azstorageaccount -resourcegroupName $ResourceGroupName -name $Account"
    $Context = get-azstorageaccount -resourcegroupName $ResourceGroupName -name $Account -ErrorAction SilentlyContinue
    if ( get-AzStorageBlob -context $Context.context -container $Container -ErrorAction SilentlyContinue) { $true } else { $false }
}

function Test-azSqlTables(
    [string]
    $Environnement, 
    $Serveur, 
    $ResourceGroupName, 
    $BD
) {
    $password = (Get-AzKeyVaultSecret -VaultName gumkeyvault -Name "sqladmin$environnement").SecretValueText
    $query = "set nocount on; SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"                           
    SQLCMD.EXE -S "$Serveur.database.windows.net" -d $BD -G -U "sqladmin$Environnement@gumqc.OnMicrosoft.com" -P $password -Q $Query -h -1
}