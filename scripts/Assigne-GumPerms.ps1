param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
)

"$env:Default.WorkingDirectory\DevOps\scripts\Functions.ps1"
if ($env:COMPUTERNAME -like "srvtfs01") {. "$env:Default.WorkingDirectory\DevOps\scripts\Functions.ps1"}  else {. C:\templates\DevOps\scripts\Functions.ps1}

"Ajout des addresses ip sur Allow_Gum sur Environnement $Environnement pour site Gum-$Environnement"
# Add-IpPermsFunc -WebSite Gum -Environnement $Environnement -Ips Gum -Webip_Name Allow_Gum
Add-IpPermsFunc -Target_WebSite Gum -Environnement $Environnement -Source_WebSite Gum -Source_Name Allow_GUM
"Ajout des addresses ip sur Allow_GumMaster sur Environnement $Environnement pour site GumMaster-$Environnement"
# Add-IpPermsFunc -WebSite GumMaster -Environnement $Environnement -Ips GumMaster -Webip_Name Allow_GumMaster
Add-IpPermsFunc -Target_WebSite GumMaster -Environnement $Environnement -Source_WebSite GumMaster -Source_Name Allow_GumMaster

# Add-IpPermsFunc -WebSite GumSolr -Environnement $Environnement -Ips GumMaster -Webip_Name Allow_GumMaster
Add-IpPermsFunc -Target_WebSite GumSolr -Environnement $Environnement -Source_WebSite GumMaster -Source_Name Allow_GumMaster

# Add-IpPermsFunc -WebSite GumSolr -Environnement $Environnement -Ips Gum -Webip_Name Allow_Gum
Add-IpPermsFunc -Target_WebSite GumSolr -Environnement $Environnement -Source_WebSite Gum -Source_Name Allow_GUM

# Creer le baseline pour les regles de firewall
$va2065 = @("AllowSoquij, 205.237.253.10, 205.237.253.10"; "AllowAllWindowsAzureIps, 0.0.0.0, 0.0.0.0")

$resourceGroupName = "GumSite-rg-$environnement"
Enable-AzureRmSqlServerAdvancedThreatProtection -ServerName "sqlgum-$Environnement" -ResourceGroupName "gumsql-rg-$environnement"
get-azurermsqldatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName "sqlgum-$environnement" | Where-Object { $_.databaseName -ne "master" } | Update-AzureRmSqlDatabaseVulnerabilityAssessmentSettings -StorageAccountName gumlogs -ScanResultsContainerName vulnerability-assessment -RecurringScansInterval Weekly -EmailAdmins $true -NotificationEmail "ygermain@soqui.qc.ca"
Get-AzureRmSqlDatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName sqlgum-$Environnement | where-object { $_.DatabaseName -ne "master" } | Set-AzureRmSqlDatabaseVulnerabilityAssessmentRuleBaseline  -RuleId "va2065" -BaselineResult $va2065

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
