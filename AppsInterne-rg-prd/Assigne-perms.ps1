param(
     [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
 )

$resourceGroupName = "AppsInterne-rg-$environnement"

# Outbound IP addresses - Logic Apps service & managed connectors voir https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-limits-and-config#configuration  
if ( $resourceGroupLocation -eq "CanadaCentral" ) {
    $IP_logic_Apps = "13.71.184.150", "13.71.186.1", "40.85.250.135", "40.85.250.212", "40.85.252.47", "52.233.29.92", "52.228.39.241", "52.228.39.244" 
} else {
    $IP_logic_Apps = "40.86.203.228", "40.86.216.241", "40.86.217.241", "40.86.226.149", "40.86.228.93", "52.229.120.45", "52.229.126.25", "52.232.128.155"
}


# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa
if ( $Environnement -eq "dev" -or $Environnement -eq "qa") {
    $QA = Get-AzureRmADGroup -SearchString "QA"
    New-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName -AllowDelegation
    $dev = Get-AzureRmADGroup -SearchString "dev"
    New-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroupName -AllowDelegation
}
# Mettre les restrictions sur l'app de Veille
$site = "Veille-" + $Environnement

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
$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig -ApiVersion $APIVersion -Force

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
Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig -ApiVersion $APIVersion -Force
