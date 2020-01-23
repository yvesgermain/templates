param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
)

$resourceGroupName = "AppsInterne-rg-$environnement"

# Outbound IP addresses - Logic Apps service & managed connectors voir https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-limits-and-config#configuration  
# CanadaCentral
    $IP_logic_Apps = "13.71.184.150", "13.71.186.1", "40.85.250.135", "40.85.250.212", "40.85.252.47", "52.233.29.92", "52.228.39.241", "52.228.39.244" 

# CanadaEast: $IP_logic_Apps = "40.86.203.228", "40.86.216.241", "40.86.217.241", "40.86.226.149", "40.86.228.93", "52.229.120.45", "52.229.126.25", "52.232.128.155"


# Mettre les restrictions sur l'app de Veille
$site = "Veille-" + $Environnement

$APIVersion = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
$WebAppConfig = (Get-AzureRmResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName $resourceGroupName -ApiVersion $APIVersion)
$priority = 180;  
$IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
$IpSecurityRestrictions

[System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

(Get-AzureRmwebapp -name ("AppsInterne-" + $Environnement )).OutboundIpAddresses.split(",") | ForEach-Object { 
    $Ip = $_;
    if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
        $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
        $webip.ipAddress = $_ + '/32';  
        $webip.action = "Allow"; 
        $webip.name = "Allow_AppsInterne"
        $priority = $priority + 20 ; 
        $webIP.priority = $priority;  
        $ArrayList.Add($webIP); 
        Remove-Variable webip
    }
}
$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force

# Mettre les restrictions sur AppsInterne

$site = "AppsInterne-" + $Environnement
 
$APIVersion = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
$WebAppConfig = (Get-AzureRmResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName $resourceGroupName -ApiVersion $APIVersion)
$priority = 180;  
$IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
$IpSecurityRestrictions

[System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

(Get-azureRmwebapp -name ("AppsInterne-" + $Environnement )).OutboundIpAddresses.split(",") | ForEach-Object { 
    $Ip = $_;
    if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
        $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
        $webip.ipAddress = $_ + '/32';  
        $webip.action = "Allow"; 
        $webip.name = "Allow_AppsInterne"
        $priority = $priority + 20 ; 
        $webIP.priority = $priority;  
        $ArrayList.Add($webIP); 
        Remove-Variable webip
    }
}
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
        Remove-Variable webip
    }
}
$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force

<# 
Write-Output "Mettre la Connection String dans l'App Function"
$connectionStrings = @{}
$passw = (Get-AzureKeyVaultSecret -VaultName gumkeyvault -name "sqladmin$environnement").secretvaluetext
$connectionStrings['bd_VeilleContenuExterneEntities'] = @{Type= "SQLServer"; Value= 'Source=sqlguminterne-' + $environnement + '.database.windows.net,1433;Initial Catalog=Veille-'+ $environnement + ';Persist Security Info=False;UserID=sqladmin' + $environnement + ';Password=' + $passw + ';MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;ConnectionTimeout=30;App=EntityFramework'}
Set-AzureRmWebApp -ResourceGroupName "appsinterne-rg-$environnement" -name "veille-func-$Environnement" -ConnectionStrings $connectionStrings
#>
# Creer le baseline pour les regles de firewall
$va2065 = @("AllowSoquij, 205.237.253.10, 205.237.253.10"; "AllowAllWindowsAzureIps, 0.0.0.0, 0.0.0.0")
"Enable Azure Advanced Threat protection"
Enable-AzureRmSqlServerAdvancedThreatProtection -ServerName "sqlguminterne-$Environnement" -ResourceGroupName "SQLApps-rg-$environnement"
"Update Azure SQL Database Vulnerability Assessment Settings to weekly"
Get-azurermsqldatabase -ResourceGroupName "SQLApps-rg-$environnement" -ServerName "sqlguminterne-$environnement" | Where-Object {$_.databaseName -ne "master"} | Update-AzureRmSqlDatabaseVulnerabilityAssessmentSettings -StorageAccountName gumlogs -ScanResultsContainerName vulnerability-assessment -RecurringScansInterval Weekly -EmailAdmins $true -NotificationEmail "ygermain@soquij.qc.ca"
"Set Azure SQL Database Vulnerability Assessment for Firewall baseline"
Get-AzureRmSqlDatabase -ResourceGroupName "SQLApps-rg-$environnement" -ServerName "sqlguminterne-$Environnement" | where-object {$_.DatabaseName -ne "master"} | Set-AzureRmSqlDatabaseVulnerabilityAssessmentRuleBaseline  -RuleId "va2065" -BaselineResult $va2065


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