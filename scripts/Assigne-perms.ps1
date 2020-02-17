param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
)


if ($env:COMPUTERNAME -like "srvtfs01") { . $DefaultWorkingDirectory/DevOps/scripts/Functions.ps1 }  else { . C:\templates\DevOps\scripts\Functions.ps1 }

$resourceGroupName = "AppsInterne-rg-$environnement"
    
# Add-IpPermsFunc -WebSite AppsInterne -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
Add-IpPermsFunc -Target_WebSite AppsInterne -Environnement $Environnement -Source_WebSite logic_App -Source_Name Allow_Logic_App
#Add-IpPermsFunc -WebSite AppsInterne -Environnement $Environnement -Ips AppsInterne -Webip_Name Allow_AppsInterne
Add-IpPermsFunc -Target_WebSite AppsInterne -Environnement $Environnement -Source_WebSite AppsInterne -Source_Name Allow_AppsInterne
#Add-IpPermsFunc -WebSite Veille -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
Add-IpPermsFunc -Target_WebSite Veille -Environnement $Environnement -Source_WebSite logic_App -Source_Name Allow_Logic_App
#Add-IpPermsFunc -WebSite GumMaster -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
Add-IpPermsFunc -Target_WebSite GumMaster -Environnement $Environnement -Source_WebSite logic_App -Source_Name Allow_Logic_App
#Add-IpPermsFunc -WebSite GumSolr -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
Add-IpPermsFunc -Target_WebSite GumSolr -Environnement $Environnement -Source_WebSite logic_App -Source_Name Allow_Logic_App
#Add-IpPermsFunc -WebSite Gum -Environnement $Environnement -Ips logic_App -Webip_Name Allow_Logic_App
Add-IpPermsFunc -Target_WebSite Gum -Environnement $Environnement -Source_WebSite logic_App -Source_Name Allow_Logic_App
#Add-IpPermsFunc -WebSite Veille -Environnement $Environnement -Ips AppsInterne -Webip_Name Allow_AppsInterne
Add-IpPermsFunc -Target_WebSite Veille -Environnement $Environnement -Source_WebSite AppsInterne -Source_Name Allow_AppsInterne
#Add-IpPermsFunc -WebSite Veille -Environnement $Environnement -Ips GumMaster -Webip_Name Allow_GumMaster
Add-IpPermsFunc -Target_WebSite Veille -Environnement $Environnement -Source_WebSite GumMaster -Source_Name Allow_GumMaster

"La connection Strings ne se configure pas dans Appinterne-rg-prd\template.json"
Write-Output "Mettre la Connection String dans l'App Function"
$connectionStrings = @{ }
$passw = (Get-AzureKeyVaultSecret -VaultName gumkeyvault -name "sqladmin$environnement").secretvaluetext
$connectionStrings['bd_VeilleContenuExterneEntities'] = @{Type = "SQLServer"; Value = 'Server=sqlguminterne-' + $environnement + '.database.windows.net,1433;Initial Catalog=BdVeille-' + $environnement + ';Persist Security Info=False;User ID=sqladmin' + $environnement + ';Password=' + $passw + ';MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;App=EntityFramework' }
Set-AzureRmWebApp -ResourceGroupName "appsinterne-rg-$environnement" -name "veille-func-$Environnement" -ConnectionStrings $connectionStrings

# Creer le baseline pour les regles de firewall
$va2065 = @("AllowSoquij, 205.237.253.10, 205.237.253.10"; "AllowAllWindowsAzureIps, 0.0.0.0, 0.0.0.0")
"Enable Azure Advanced Threat protection"
Get-AzureRmSqlServer -name "sqlguminterne-$Environnement" -ResourceGroupName "sqlApps-rg-$Environnement" | Enable-AzureRmSqlServerAdvancedThreatProtection
"Update Azure SQL Database Vulnerability Assessment Settings to weekly"

Get-azurermsqldatabase -ResourceGroupName "SQLApps-rg-$environnement" -ServerName "sqlguminterne-$environnement" | Where-Object { $_.databaseName -ne "master" } | Update-AzureRmSqlDatabaseVulnerabilityAssessmentSettings -StorageAccountName gumlogs -ScanResultsContainerName vulnerability-assessment -RecurringScansInterval Weekly -EmailAdmins $true -NotificationEmail "ygermain@soquij.qc.ca"
"Set Azure SQL Database Vulnerability Assessment for Firewall baseline"
Get-AzureRmSqlDatabase -ResourceGroupName "SQLApps-rg-$environnement" -ServerName "sqlguminterne-$Environnement" | where-object { $_.DatabaseName -ne "master" } | Set-AzureRmSqlDatabaseVulnerabilityAssessmentRuleBaseline  -RuleId "va2065" -BaselineResult $va2065

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
