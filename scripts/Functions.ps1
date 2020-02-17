<#
.Synopsis
Pour charger les functions pour KUDU
.DESCRIPTION
Permet de garder dans un seul script tous les fonctions pour restAPI
.EXAMPLE
. .\functions.ps1 -environnement "dev"
#>

function Get-AzureRmWebAppPublishingCredentials($resourceGroupName, $webAppName, $slotName = $null) {
    if ([string]::IsNullOrWhiteSpace($slotName)) {
        $resourceType = "Microsoft.Web/sites/config"
        $resourceName = "$webAppName/publishingcredentials"
    }
    else {
        $resourceType = "Microsoft.Web/sites/slots/config"
        $resourceName = "$webAppName/$slotName/publishingcredentials"
    }
    $publishingCredentials = Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType $resourceType -ResourceName $resourceName -Action list -ApiVersion 2015-08-01 -Force
    return $publishingCredentials
}
function Get-KuduApiAuthorisationHeaderValue($resourceGroupName, $webAppName, $slotName = $null) {
    $publishingCredentials = Get-AzureRmWebAppPublishingCredentials $resourceGroupName $webAppName $slotName
    return ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $publishingCredentials.Properties.PublishingUserName, $publishingCredentials.Properties.PublishingPassword))))
}
function Get-FileFromWebApp($resourceGroupName, $webAppName, $slotName = "", $kuduPath, $localPath) {

    $kuduApiAuthorisationToken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName $slotName
    if ($slotName -eq "") {
        $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    else {
        $kuduApiUrl = "https://$webAppName`-$slotName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    $virtualPath = $kuduApiUrl.Replace(".scm.azurewebsites.", ".azurewebsites.").Replace("/api/vfs/site/wwwroot", "")
    Write-Host " Downloading File from WebApp. Source: '$virtualPath'. Target: '$localPath'..." -ForegroundColor DarkGray

    Invoke-RestMethod -Uri $kuduApiUrl `
        -Headers @{"Authorization" = $kuduApiAuthorisationToken; "If-Match" = "*" } `
        -Method GET `
        -OutFile $localPath `
        -ContentType "multipart/form-data"
}

function Read-FilesFromWebApp($resourceGroupName, $webAppName, $slotName = "", $kuduPath, $localPath) {

    $kuduApiAuthorisationToken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName $slotName
    if ($slotName -eq "") {
        $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    else {
        $kuduApiUrl = "https://$webAppName`-$slotName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    $virtualPath = $kuduApiUrl.Replace(".scm.azurewebsites.", ".azurewebsites.").Replace("/api/vfs/site/wwwroot", "")
    Write-Host " Downloading File from WebApp. Source: '$virtualPath'. Target: '$localPath'..." -ForegroundColor DarkGray

    Invoke-RestMethod -Uri $kuduApiUrl `
        -Headers @{"Authorization" = $kuduApiAuthorisationToken; "If-Match" = "*" } `
        -Method GET `
        -OutFile $localPath `
        -ContentType "multipart/form-data" 
}

function Push-FileToWebApp($resourceGroupName, $webAppName, $slotName = "", $localPath, $kuduPath) {
    $kuduApiAuthorisationToken = Get-KuduApiAuthorisationHeaderValue -resourceGroupName $resourceGroupName -WebAppName $webAppName -slotName $slotName
    if ($slotName -eq "") {
        $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    else {
        $kuduApiUrl = "https://$webAppName`-$slotName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    $virtualPath = $kuduApiUrl.Replace(".scm.azurewebsites.", ".azurewebsites.").Replace("/api/vfs/site/wwwroot", "")
    Write-Host " Uploading File to WebApp. Source: '$localPath'. Target: '$virtualPath'..."  -ForegroundColor DarkGray

    Invoke-RestMethod -Uri $kuduApiUrl `
        -Headers @{"Authorization" = $kuduApiAuthorisationToken; "If-Match" = "*" } `
        -Method PUT `
        -InFile $localPath `
        -ContentType "multipart/form-data"
}

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
        $Target_WebSite,    
        
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet("dev", "qa", "prd", "devops")] 
        $Environnement,
    
        [Parameter(Mandatory = $True)]
        [string]
        [ValidateSet( "AppsInterne", "logic_App" , "Gum", "GumMaster")] 
        $Source_WebSite,

        [Parameter(Mandatory = $True)]
        [string] 
        [ValidateSet("Allow_Logic_App", "Allow_AppsInterne", "Allow_GUM", "Allow_GumMaster")] 
        $Source_Name,
    
        [string] 
        [ValidateSet("stage", "hotfix")] 
        $Slot
    )
    
    # Outbound IP addresses - Logic Apps service & managed connectors voir https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-limits-and-config#configuration  
    # CanadaCentral
    $IP_logic_Apps = "13.71.184.150", "13.71.186.1", "40.85.250.135", "40.85.250.212", "40.85.252.47", "52.233.29.92", "52.228.39.241", "52.228.39.244" 
    
    # CanadaEast: $IP_logic_Apps = "40.86.203.228", "40.86.216.241", "40.86.217.241", "40.86.226.149", "40.86.228.93", "52.229.120.45", "52.229.126.25", "52.232.128.155"
    
    switch ($Target_WebSite) {
        "AppsInterne" { $Target_ResourceGroupName = "AppsInterne-rg-$environnement" }
        "Veille" { $Target_ResourceGroupName = "AppsInterne-rg-$environnement" }
        "Gum" { $Target_ResourceGroupName = "GumSite-rg-$environnement" }
        "GumMaster" { $Target_ResourceGroupName = "GumSite-rg-$environnement" }
        "GumSolr" { $Target_ResourceGroupName = "GumSite-rg-$environnement" }
    }
    
    switch ($Source_WebSite) {
        "Logic_App" { $IP = $IP_logic_Apps }
        "AppsInterne" { $IP = (Get-AzureRmwebapp -name ("$Source_WebSite-$environnement")).OutboundIpAddresses.split(","); $Source_ResourceGroupName = "AppsInterne-rg-$Environnement" }
        "Gum" { $IP = (Get-AzureRmwebapp -name ("$Source_WebSite-$environnement")).OutboundIpAddresses.split(",") ; $Source_ResourceGroupName = "GumSite-rg-$Environnement" }
        "GumMaster" { $IP = (Get-AzureRmwebapp -name ("$Source_WebSite-$environnement")).OutboundIpAddresses.split(","); $Source_ResourceGroupName = "GumSite-rg-$Environnement" }
    }

    $Target_site = "$Target_WebSite-$environnement"
    $Source_Site = "$Source_WebSite-$environnement"
    $Name = $Source_Name
    if ($slot) {
        $IP = (get-azurermwebappslot -Name $Source_Site -ResourceGroupName $Source_ResourceGroupName -slot $slot).OutboundIpAddresses.split(",") ; 
        $Name = $Source_Name + "_$Slot"
    }
    
    "Donner acces a $Target_site sur $Source_Site"
    
    [array] $APIVersion = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
    $WebAppConfig = (Get-AzureRmResource -ResourceType Microsoft.Web/sites/config -ResourceName $Target_site -ResourceGroupName $Target_ResourceGroupName -ApiVersion $APIVersion)
    $WebAppConfig.Properties.ipsecurityrestrictions
    [System.Collections.ArrayList]$ArrayList = $WebAppConfig.Properties.ipsecurityrestrictions;
    $priority = ($WebAppConfig.properties.ipsecurityrestrictions.priority | Where-Object { $_ -lt 6500 } | Sort-Object )[-1];

    $IP | ForEach-Object { 
        $Ip = $_;
        if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
            $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
            $webip.ipAddress = $_ + '/32';  
            $webip.action = "Allow"; 
            $webip.name = $Name
            $priority = $priority + 20 ; 
            $webIP.priority = $priority;  
            $ArrayList.Add($webIP); 
            Remove-Variable webip
        }
    }
    $ArrayList | Format-Table -AutoSize
    $WebAppConfig.properties.ipsecurityrestrictions = $ArrayList
    Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
}

