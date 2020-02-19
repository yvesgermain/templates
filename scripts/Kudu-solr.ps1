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
    [Parameter(Mandatory = $True)]    
    [string]
    $DefaultWorkingDirectory
)
if ($env:COMPUTERNAME -like "srvtfs01") { . "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1" }  else { . C:\templates\DevOps\scripts\Functions.ps1 }

# Debut du script
$resourceGroupName = "gumsite-rg-$environnement"
$webAppName = "gumsolr-$environnement"
$kuduPath = "server/solr/"
$kuduApiUrl = "https://gumsolr-$environnement.scm.azurewebsites.net/api/vfs/site/wwwroot/" + $kuduPath
$localPath = "C:\temp\solr_index_$Environnement\"

if (!(Test-Path $localPath)) { mkdir $localPath }
$kuduApiAuthorisationToken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName 

[array] $a = $kuduApiUrl; $Folders =  While ((compare-object ( $all | Sort-Object | get-unique ) ($a | Sort-Object | get-unique )) -notlike $null)  {$A = $all
    $A | ForEach-Object {
        $all += (Invoke-RestMethod -Uri $_ -Headers @{"Authorization" = $kuduApiAuthorisationToken; "If-Match" = "*" } -Method GET -ContentType "multipart/form-data" | ForEach-Object {
                $_ | where-object { $_.mime -like "inode/directory" } }).href ;
    }
    $all = $all | Sort-Object | get-unique ; $all
} 

$Folders = $folders | Where-Object { $_ -ne $null }
$Folders | foreach-object {
    $FolderPath = "C:\temp\logskudu\gumsolr" + "-" + $environnement + '\' + $_.replace( ("https://gumsolr-" + $Environnement + ".scm.azurewebsites.net/api/vfs/site/wwwroot/server/solr/") , "")
    if (!( Test-Path $FolderPath)) { mkdir $FolderPath -Force };
    $files = Invoke-RestMethod -Uri $_ `
        -Headers @{"Authorization" = $kuduApiAuthorisationToken; "If-Match" = "*" } `
        -Method get `
        -ContentType "multipart/form-data"
    $files | where-object { $_.mime -notlike "inode/directory" } | ForEach-Object {
        $FolderPath = "C:\temp\logskudu\gumsolr" + "-" + $environnement + '\' + $_.href.replace( ("https://gumsolr-" + $Environnement + ".scm.azurewebsites.net/api/vfs/site/wwwroot/server/solr/") , "").replace($_.name , "")
        $FilePath = $FolderPath + $_.name
        Invoke-RestMethod -Uri $_.href `
            -Headers @{"Authorization" = $kuduApiAuthorisationToken; "If-Match" = "*" } `
            -Method get `
            -OutFile $FilePath  `
            -ContentType "multipart/form-data" }
}
