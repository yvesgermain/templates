<#
.Synopsis
Corriger le fichier dans les apps service par l<interface KUDU
.DESCRIPTION
On s'authentifie et on download le fichier security.config que l'on modifie et upload par restAPI
.EXAMPLE
.\kudu.ps1 -environnement "dev"
#>
param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [string]
    [ValidateSet("GUM", "AppsInterne")] 
    $Domaine
)

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

# Debut du script
if ($domaine -like "GUM") {
$resourceGroupName = "gumsite-rg-$environnement"
$webAppNames = "gummaster-$environnement", "gum-$environnement"
} else {
$resourceGroupName = "AppsInterne-rg-$environnement"
$webAppNames = "AppsInterne-$environnement"
}
$kuduPath = "config/imageprocessor/security.config"
$localPath = "C:\temp\security.config.$Environnement"

foreach ( $webAppName in $webAppNames) { 
    Get-FileFromWebApp -resourceGroupName $resourceGroupName -webAppName  $webAppName -kuduPath $kuduPath -localPath $localPath
    (get-content $localPath ).replace("umbracomediaateamdev", "storgum$Environnement") | set-content -Path $localPath -Encoding utf8
    Push-FileToWebApp -resourceGroupName $resourceGroupName -webAppName  $webAppName -kuduPath $kuduPath -localPath $localPath
}