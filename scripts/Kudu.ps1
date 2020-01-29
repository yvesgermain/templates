param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
)

$resourceGroupName = "gumsite-rg-$environnement"
$webAppName = "gummaster-$environnement"
$kuduPath = "/config/imageprocessor/security.config"
$localPath = "C:\temp\security.config.$Environnement"
function Get-KuduApiAuthorisationHeaderValue($resourceGroupName, $webAppName, $slotName = $null){
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

function Push-FileToWebApp($resourceGroupName, $webAppName, $slotName = "", $localPath, $kuduPath) {

    $kuduApiAuthorisationToken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName $slotName
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

Get-FileFromWebApp -resourceGroupName $resourceGroupName -webAppName  $webAppName -kuduPath $kuduPath -localPath $localPath

(get-content $localPath ).replace("umbracomediaateamdev","storgum$Environnement") | set-content -Path $localPath

Push-FileToWebApp -resourceGroupName $resourceGroupName -webAppName  $webAppName -kuduPath $kuduPath -localPath $localPath
