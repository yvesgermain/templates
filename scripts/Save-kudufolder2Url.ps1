param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $environnement,
    [string]
    $DefaultWorkingDirectory,
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("Gum", "GumSolr", "Veille", "AppsInterne")] 
    [string]
    $WebApp,
    [string] 
    $SlotName = "",
    [string] 
    [ValidateSet("x","y","z")] 
    $ZipFolder = "Z"
)

# Declaration de variables:
if ($env:COMPUTERNAME -like "srvtfs01") { . "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1" }  else { . C:\templates\DevOps\scripts\Functions.ps1 }
if ($webApp -like "Gumsolr") { $kuduPath = "server/solr/" } Else {$kuduPath = "app_data/logs/"} 
$WebappName = "$webapp-$Environnement"
$resourceGroupName = (get-azwebapp -name $webAppName ).resourcegroup
$ZipFilePath = ($ZipFolder + ":\" + $environnement + "\" + $webAppName + (get-date -Format "yyyy-MM-dd") +  ".zip") 

# Creation du psdrive vers \\Gumbackups.file.core.windows.net\dev

# if (!( Get-PSDrive -name $ZipFolder -ErrorAction SilentlyContinue)) {new-azdrive}
Compress-KuduFolderToZipFile -Environnement $environnement -resourceGroupName $resourceGroupName -webAppName $webAppName -ZipFilePath $ZipFilePath -kuduPath $kuduPath 
remove-psdrive -name $ZipFolder