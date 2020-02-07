Param(
    [Parameter()]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement
)
$a = @{ }
$b = @()
$a["server"] = "sqlgum-$Environnement"
$a["database"] = "BdGum-$Environnement"
$b += $a
$a = @{ }
$a["server"] = "sqlguminterne-$Environnement"
$a["database"] = "BdAppsInterne-$Environnement", "BdVeille-$Environnement"
$b += $a
$password = (Get-AzureKeyVaultSecret -VaultName gumkeyvault -Name sqladmin$environnement).SecretValueText

foreach ($Item in $b) {
    foreach ($database in $Item.database ) {
        foreach ($server in $Item.server ) {
            $cxnString = "Server=tcp:$server.database.windows.net,1433;Initial Catalog=$database;Persist Security Info=False;User ID=sqladmin$environnement@gumqc.OnMicrosoft.com;Password=$password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=`"Active Directory Password`"";
            $querys = 'CREATE USER [sqladmin@GUMQC.OnMicrosoft.com] FROM EXTERNAL PROVIDER',
            'ALTER ROLE DB_datareader ADD MEMBER [sqladmin@GUMQC.OnMicrosoft.com]', 
            'ALTER ROLE DB_datawriter ADD MEMBER [sqladmin@GUMQC.OnMicrosoft.com]'

            $cxn = New-Object System.Data.SqlClient.SqlConnection($cxnString)
            $cxn.Open()

            $query = "if ((SELECT count(*) FROM sysusers where name like 'SQLadmin@GUMQC.OnMicrosoft.com') > 0 ) select 0 AS Violation else select 1 AS Violation"
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
    }
}
