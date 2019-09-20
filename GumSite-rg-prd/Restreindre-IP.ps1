<#
 .SYNOPSIS
    Restreint les addresses IP qui peuvent atteindre les sites web.

 .EXAMPLE
    ./restreindre-ip.ps1 -environnement devops

 .PARAMETER Environnement
    L'environnement affecté
#>

param(
    [Parameter(Mandatory=$True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
   )

$Sites = "Gum-$environnement", "gummaster-$environnement"
foreach ( $site in $sites) {
    $APIVersion = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
    $WebAppConfig = (Get-AzureRmResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName GumSite-rg-$Environnement -ApiVersion $APIVersion)
    $priority = 180;  
    $IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
    $IpSecurityRestrictions

    [System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

    (Get-AzureRmwebapp -name $site).OutboundIpAddresses.split(",") | ForEach-Object { 
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
    $WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
    $WebAppConfig | Set-AzureRmResource  -ApiVersion $APIVersion -Force -Verbose
    
}

