param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
)

# Creer le baseline pour les regles de firewall
$va2065 = @("AllowSoquij, 205.237.253.10, 205.237.253.10"; "AllowAllWindowsAzureIps, 0.0.0.0, 0.0.0.0")

Enable-AzureRmSqlServerAdvancedThreatProtection -ServerName "sqlgum-$Environnement" -ResourceGroupName "gumsql-rg-$environnement"
get-azurermsqldatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName "sqlgum-$environnement" | Where-Object { $_.databaseName -ne "master" } | Update-AzureRmSqlDatabaseVulnerabilityAssessmentSettings -StorageAccountName gumlogs -ScanResultsContainerName vulnerability-assessment -RecurringScansInterval Weekly -EmailAdmins $true -NotificationEmail "ygermain@soqui.qc.ca"
Get-AzureRmSqlDatabase -ResourceGroupName "gumsql-rg-$environnement" -ServerName sqlgum-$Environnement | where-object { $_.DatabaseName -ne "master" } | Set-AzureRmSqlDatabaseVulnerabilityAssessmentRuleBaseline  -RuleId "va2065" -BaselineResult $va2065
