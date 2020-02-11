param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
)
function Add-IpPermsFunc {
    <#
     .SYNOPSIS
        Ajoute les IP qui ont les permissions sur les sites Web
    
     .DESCRIPTION
        Modifie les access Resrictions dans l'onglet Networking des sites web avec toutes les addresses
    
     .EXAMPLE
        ./Add-IPPermsFunc.ps1 -WebSite AppsInterne -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
    
     .PARAMETER WebSite
        Le parametre WebSite est le site que l'on veut modifier en ajoutant les adresses IP 
    
     .PARAMETER Environnement
        Le parametre Environnement indique l'Environnement du site web a modifier
    
     .PARAMETER IPs
        Un identifiant pour la serie d'adresse ip 
    
     .PARAMETER Webip_name
        Le nom descriptif pour la regle a appliquer
    #>
        param(
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("AppsInterne", "Veille", "Gum", "GumMaster", "GumSolr")] 
        $WebSite,    
        
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Environnement,
    
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet( "AppsInterne", "logic_App" , "Gum", "GumMaster", "GumSolr")] 
        $IPs,
    
        [string] 
        [ValidateSet("Allow_Logic_App", "Allow_AppsInterne", "Allow_GUM", "Allow_GumMaster", "Allow_GumSolr")] 
        $Webip_Name
    )
    
    # Outbound IP addresses - Logic Apps service & managed connectors voir https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-limits-and-config#configuration  
    # CanadaCentral
    $IP_logic_Apps = "13.71.184.150", "13.71.186.1", "40.85.250.135", "40.85.250.212", "40.85.252.47", "52.233.29.92", "52.228.39.241", "52.228.39.244" 
    # CanadaEast: $IP_logic_Apps = "40.86.203.228", "40.86.216.241", "40.86.217.241", "40.86.226.149", "40.86.228.93", "52.229.120.45", "52.229.126.25", "52.232.128.155"
    
    switch ($WebSite) {
        "AppsInterne" { $resourceGroupName = "AppsInterne-rg-$environnement" }
        "Veille" { $resourceGroupName = "AppsInterne-rg-$environnement" }
        "Gum" { $resourceGroupName = "GumSite-rg-$environnement" }
        "GumMaster" { $resourceGroupName = "GumSite-rg-$environnement" }
        "GumSolr" { $resourceGroupName = "GumSite-rg-$environnement" }
    }
    
    switch ($IPs) {
        "Logic_App" {$IP = $IP_logic_Apps}
        "AppsInterne" {$IP = (Get-AzureRmwebapp -name ("$Ips-$environnement")).OutboundIpAddresses.split(",") }
        "Gum" { $IP = (Get-AzureRmwebapp -name ("$Ips-$environnement")).OutboundIpAddresses.split(",") }
        "GumMaster" { $IP = (Get-AzureRmwebapp -name ("$Ips-$environnement")).OutboundIpAddresses.split(",") }
        "GumSolr" { $IP = (Get-AzureRmwebapp -name ("$Ips-$environnement")).OutboundIpAddresses.split(",") }
    }
    
    $site = "$WebSite-$environnement"
    
    # Mettre les restrictions sur l'app de Veille
    
    $APIVersion = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
    $WebAppConfig = (Get-AzureRmResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName $resourceGroupName -ApiVersion $APIVersion)
    $priority = ($WebAppConfig.Properties.ipsecurityrestrictions.priority | Where-Object {$_ -lt 6500} | Sort-Object )[-1];
    
    [System.Collections.ArrayList]$ArrayList = $WebAppConfig.Properties.ipsecurityrestrictions;
    
    $IP | ForEach-Object { 
        $Ip = $_;
        if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
            $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
            $webip.ipAddress = $_ + '/32';  
            $webip.action = "Allow"; 
            $webip.name = $Webip_Name
            $priority = $priority + 20 ; 
            $webIP.priority = $priority;  
            $ArrayList.Add($webIP); 
            Remove-Variable webip
        }
    }
    $ArrayList | Format-Table -AutoSize
    $WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
    Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
    }
    
    Add-IpPermsFunc -WebSite Gum -Environnement $Environnement -Ips Gum -Webip_Name Allow_Gum
    Add-IpPermsFunc -WebSite Gum -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
    Add-IpPermsFunc -WebSite GumMaster -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
    Add-IpPermsFunc -WebSite GumMaster -Environnement $Environnement -Ips GumMaster -Webip_Name Allow_GumMaster
    Add-IpPermsFunc -WebSite GumSolr -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
    Add-IpPermsFunc -WebSite GumSolr -Environnement $Environnement -Ips GumMaster -Webip_Name Allow_GumMaster
    Add-IpPermsFunc -WebSite GumSolr -Environnement $Environnement -Ips Gum -Webip_Name Allow_Gum

# Creer le baseline pour les regles de firewall
$va2065 = @("AllowSoquij, 205.237.253.10, 205.237.253.10"; "AllowAllWindowsAzureIps, 0.0.0.0, 0.0.0.0")

$resourceGroupName = "GumSite-rg-$environnement"
Enable-AzureRmSqlServerAdvancedThreatProtection -ServerName "sqlgum-$Environnement" -ResourceGroupName "gumsql-rg-$environnement"
get-azurermsqldatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName "sqlgum-$environnement" | Where-Object { $_.databaseName -ne "master" } | Update-AzureRmSqlDatabaseVulnerabilityAssessmentSettings -StorageAccountName gumlogs -ScanResultsContainerName vulnerability-assessment -RecurringScansInterval Weekly -EmailAdmins $true -NotificationEmail "ygermain@soqui.qc.ca"
Get-AzureRmSqlDatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName sqlgum-$Environnement | where-object { $_.DatabaseName -ne "master" } | Set-AzureRmSqlDatabaseVulnerabilityAssessmentRuleBaseline  -RuleId "va2065" -BaselineResult $va2065

function Add-SQLAccount (
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement,
    [string] $Account = "Sqladmin",
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

Add-SQLAccount -Environnement $Environnement -BD BdGum

write-output "Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa"
$resourceGroupName = "GumSite-rg-$environnement" 

if ( $Environnement -eq "dev" -or $Environnement -eq "qa" -or $Environnement -eq "devops") {
    $QA = Get-AzureRmADGroup -SearchString "QA"
    if (!( get-AzureRmRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $qa.Id -RoleDefinitionName contributor)) {
        New-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName
    }
    $dev = Get-AzureRmADGroup -SearchString "dev"
    if (!( get-AzureRmRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $dev.Id -RoleDefinitionName owner)) {
        New-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner -ResourceGroupName $resourceGroupName
    }
}
