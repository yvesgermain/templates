param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement, 
    [string] $Account = "Sqlrw$environnement",
    [Parameter(Mandatory = $true)]
    [validateset("AppsInterne", "Gum")]
    [string] $resourcegroup
)

function Add-SQLAccount (
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement,
    [string] $Account = "Sqlrw$environnement",
    [Parameter(Mandatory = $true)]
    [string] $Database, 
    [string] $server
) {

    $password = (Get-AzureKeyVaultSecret -VaultName gumkeyvault -Name sqladmin$environnement).SecretValueText

    $cxnString = "Server=tcp:$server.database.windows.net,1433;Initial Catalog=$Database;Persist Security Info=False;User ID=sqladmin$environnement@gumqc.OnMicrosoft.com;Password=$password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=`"Active Directory Password`"";
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

if ($Resourcegroup -like "Gum") { 
    $server = "sqlgum-$Environnement" ; 
    $databases = "BDGUM-" + $environnement 
} else {
    $server = "sqlguminterne-$Environnement";  
    $databases = ("BdAppsinterne-" + $environnement), ("BdbVeille-" + $Environnement)
}

Foreach ( $Database in $databases) {
    "Ajout de SQLRW$Environnement dans la BD $Database"; 
    Add-SQLAccount -Environnement $Environnement -Database $Database -server $server -Account $account
}

