$VmIP = (Get-AzureRMPublicIpAddress -ResourceGroupNane "crawler-rg-dev" -Name PIP-dev).ipaddress

$Environnements = "dev", "qa", "prd"
$Sites = "gummaster", "gum"
$APIVersion = ((Get-AzureRMResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]

foreach ($Environnement in $Environnements) {
    foreach ($site in $sites) {
        $WebAppConfig = (Get-AzureRMResource -ResourceType Microsoft.Web/sites/config -ResourceName "$site-$Environnement" -ResourceGroupName GumSite-rg-$Environnement -ApiVersion $APIVersion)
        New-Variable -Name "WebAppConfig$site$Environnement" -Value $webAppConfig
        $priority = 500;  
        New-Variable -Name "IpSecurityRestrictions$site$Environnement" -value $WebAppConfig.Properties.ipsecurityrestrictions; 
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
}

dir c:\crawler -Directory | remove-item -Force -Recurse
Write-output "Downloading TriggerExecCrawler.zip"
(new-object System.Net.WebClient).DownloadFile('https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip', "$env:temp\TriggerExecCrawler.zip");
"Decompressing file TriggerExecCrawler.zip in c:\crawler"
Expand-Archive -LiteralPath "$env:temp\TriggerExecCrawler.zip" -DestinationPath C:\crawler
$dir = Get-ChildItem C:\crawler\*\ControleQualite.App.exe 

cd $dir.directory
.\controlequalite.app.exe
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-dev' , "gummaster-qa") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
.\controlequalite.app.exe
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-qa' , "gummaster-prd") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
.\controlequalite.app.exe
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-prd' , "gummaster-dev") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
.\controlequalite.app.exe

"Retire accès à l'adresse IP du crawler au site Gum et gummaster"

foreach ($Environnement in $Environnements) {
    foreach ($site in $sites) {
        $WebAppConfig = (Get-Variable -Name "WebAppConfig$site$Environnement").value
        $WebAppConfig.properties.ipSecurityRestrictions = (get-variable -name "IpSecurityRestrictions$site").value
        Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
    }
}