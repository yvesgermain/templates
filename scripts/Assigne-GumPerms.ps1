param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
)

$IP_logic_Apps = "13.71.184.150", "13.71.186.1", "40.85.250.135", "40.85.250.212", "40.85.252.47", "52.233.29.92", "52.228.39.241", "52.228.39.244" 
$resourceGroupName = "GumSite-rg-$environnement"
$Sites = "Gum-$environnement", "gummaster-$environnement"
foreach ( $site in $sites) {
    $APIVersion = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
    $WebAppConfig = (Get-AzureRmResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName $resourceGroupName -ApiVersion $APIVersion)
    $priority = 180;  
    $IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
    $IpSecurityRestrictions

    [System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

    (Get-AzureRmwebapp -name $site).PossibleOutboundIpAddresses.split(",") | ForEach-Object { 
        $Ip = $_;
        if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
            $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
            $webip.ipAddress = $_ + '/32';  
            $webip.action = "Allow"; 
            $webip.name = "Allow_Address_Interne"
            $priority = $priority + 20 ; 
            $webIP.priority = $priority;  
            $ArrayList.Add($webIP); 
            Remove-Variable webip
        }
    }
    # Permettre le Logic App 
    $IP_logic_Apps | ForEach-Object { 
        $Ip = $_;
        if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
            $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
            $webip.ipAddress = $_ + '/32';  
            $webip.action = "Allow"; 
            $webip.name = "Allow_Logic_App"
            $priority = $priority + 20 ; 
            $webIP.priority = $priority;  
            $ArrayList.Add($webIP); 
            $webIP
            Remove-Variable webip
        }
    }

    $WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
    Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
}

# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa

$resourceGroupNames = "GumSite-rg-$environnement", "Gumsql-rg-$environnement", "Gumstorage-rg-$environnement"
foreach ($resourceGroupName in $resourceGroupNames) {
    write-output "Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa"
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
}

# Creer le baseline pour les regles de firewall
$va2065 = @("AllowSoquij, 205.237.253.10, 205.237.253.10"; "AllowAllWindowsAzureIps, 0.0.0.0, 0.0.0.0")

$resourceGroupName = "GumSite-rg-$environnement"
Enable-AzureRmSqlServerAdvancedThreatProtection -ServerName "sqlgum-$Environnement" -ResourceGroupName "gumsql-rg-$environnement"
get-azurermsqldatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName "sqlgum-$environnement" | Where-Object { $_.databaseName -ne "master" } | Update-AzureRmSqlDatabaseVulnerabilityAssessmentSettings -StorageAccountName gumlogs -ScanResultsContainerName vulnerability-assessment -RecurringScansInterval Weekly -EmailAdmins $true -NotificationEmail "ygermain@soqui.qc.ca"
Get-AzureRmSqlDatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName sqlgum-$Environnement | where-object { $_.DatabaseName -ne "master" } | Set-AzureRmSqlDatabaseVulnerabilityAssessmentRuleBaseline  -RuleId "va2065" -BaselineResult $va2065

write-output "Restriction des adresses IP sur Solr"

$site = "GumSolr-" + $Environnement

$APIVersion = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
$WebAppConfig = (Get-AzureRmResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName "GumSite-rg-$environnement" -ApiVersion $APIVersion)
$IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
$priority = 180;  
$IpSecurityRestrictions

[System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

$SourceSite = "gummaster-$environnement"
(Get-azureRmwebapp -name $Sourcesite).OutboundIpAddresses.split(",") | ForEach-Object { 
    $Ip = $_;
    if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
        $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
        $webip.ipAddress = $_ + '/32';  
        $webip.action = "Allow"; 
        $webip.name = "Allow_GumMaster"
        $priority = $priority + 20 ; 
        $webIP.priority = $priority;  
        $ArrayList.Add($webIP); 
        $webIP
        Remove-Variable webip
    }
}
# Permettre le Logic App 
$IP_logic_Apps | ForEach-Object { 
    $Ip = $_;
    if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
        $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
        $webip.ipAddress = $_ + '/32';  
        $webip.action = "Allow"; 
        $webip.name = "Allow_Logic_App"
        $priority = $priority + 20 ; 
        $webIP.priority = $priority;  
        $ArrayList.Add($webIP); 
        $webIP
        Remove-Variable webip
    }
}

$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
