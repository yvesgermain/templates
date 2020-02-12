param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement, 
    [string] $Account = "Sqlrw$environnement",
    [Parameter(Mandatory = $true)]
    [validateset("BdAppsInterne", "BdVeille", "BdGum", "All" )]
    [string] $BD
)

function Add-SQLAccount (
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement,
    [string] $Account = "Sqlrw$environnement",
    [Parameter(Mandatory = $true)]
    [validateset("BdAppsInterne", "BdVeille", "BdGum")]
    [string] $BD
) {

    if ($BD -like "BdGum") { $server = "sqlgum-$Environnement" } else { $server = "sqlguminterne-$Environnement" }
    $database = $BD + '-' + $environnement
    $password = (Get-AzureKeyVaultSecret -VaultName gumkeyvault -Name sqladmin$environnement).SecretValueText

    $cxnString = "Server=tcp:$server.database.windows.net,1433;Initial Catalog=$database;Persist Security Info=False;User ID=sqladmin$environnement@gumqc.OnMicrosoft.com;Password=$password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=`"Active Directory Password`"";
    $querys = "CREATE USER [$account@GUMQC.OnMicrosoft.com] FROM EXTERNAL PROVIDER",
    "ALTER ROLE DB_datareader ADD MEMBER [$account@GUMQC.OnMicrosoft.com]", 
    "ALTER ROLE DB_datawriter ADD MEMBER [$Account@GUMQC.OnMicrosoft.com]"

    $cxn = New-Object System.Data.SqlClient.SqlConnection($cxnString)
    $cxn.Open()

    $query = "if ((SELECT count(*) FROM sysusers where name like '$Account@GUMQC.OnMicrosoft.com') > 0 ) select 0 AS Violation else select 1 AS Violation"
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $cxn)

    if ( $cmd.ExecuteScalar()) {
        foreach ( $query in $querys) {
            $query 
            $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $cxn)
            $cmd.CommandTimeout = 120
            $cmd.ExecuteScalar()
        }
    }
    $cxn.Close()
}

if ($BD -ne "ALL") {
    "Ajout de SQLRW dans la BD $BD"; 
    Add-SQLAccount -Environnement $Environnement -bd $BD -Account $account} else {
        "BdAppsInterne", "BdVeille", "BdGum" | foreach-object  {
            "Ajout de SQLRW dans la BD $_"; 
            Add-SQLAccount -Environnement $Environnement -bd $_ -Account $account }
        }