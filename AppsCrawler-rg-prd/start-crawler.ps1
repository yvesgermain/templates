$ResourceGroupName = "VmCrawler-rg"
$VMName = "VMcrawl"
$PublicIPAddressName = "PIP-crawler"
get-azureRMvm -name $vmname -ResourceGroupName $ResourceGroupName | start-azureRmvm

"Donne accès à l'adresse IP du crawler au site Gum et gummaster"
$VmIP = (Get-AzureRMPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPAddressName).ipaddress
$VmIP
$APIVersion = ((Get-AzureRMResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]

$Environnements = "dev", "qa", "prd"
$Sites = "gummaster", "gum"

foreach ($Environnement in $Environnements) {
    foreach ($site in $sites) {
        $WebAppConfig = (Get-AzureRMResource -ResourceType Microsoft.Web/sites/config -ResourceName "$site-$Environnement" -ResourceGroupName GumSite-rg-$Environnement -ApiVersion $APIVersion)
        Remove-Variable -Name "WebAppConfig$site" -ErrorAction SilentlyContinue
        New-Variable -Name "WebAppConfig$site" -Value $webAppConfig
        $priority = 500;  
        Remove-Variable -Name "IpSecurityRestrictions$site" -ErrorAction SilentlyContinue
        New-Variable -Name "IpSecurityRestrictions$site" -value $WebAppConfig.Properties.ipsecurityrestrictions; 
        $IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 

        [System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

        if ($arrayList.ipAddress -notcontains ($VmIP + '/32')) {
            $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
            $webip.ipAddress = $Vmip + '/32';  
            $webip.action = "Allow"; 
            $webip.name = "Allow_Crawler"
            $priority = $priority + 20 ; 
            $webIP.priority = $priority;  
            $ArrayList.Add($webIP); 
            Remove-Variable webip
        }

        $WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
        Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
    }

    "Run lighthouse remotely"
    Invoke-AzureRMVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptPath .\Run-lighthouse.ps1 -Parameter @{"Environnement" = $Environnement }

    "Retire accès à l'adresse IP du crawler au site Gum et gummaster"

    foreach ($site in $sites) {
        $WebAppConfig = (Get-Variable -Name "WebAppConfig$site").value
        $WebAppConfig.properties.ipSecurityRestrictions = (get-variable -name "IpSecurityRestrictions$site").value
        Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
    }
}

get-azureRMvm -name $vmname -ResourceGroupName $ResourceGroupName | stop-azureRMvm -Force