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
if (!( Get-PSDrive -name z -ErrorAction SilentlyContinue)) {new-azdrive}
$WebappName = "$webapp-$Environnement"
$resourceGroupName = (get-azureRmwebapp -name $webAppName ).resourcegroup
$ZipFilePath = ($ZipFolder + ":\" + $environnement + "\" + $webAppName + (get-date -Format "yyyy-MM-dd") +  ".zip") 

Compress-KuduFolderToZipFile -Environnement $environnement -resourceGroupName $resourceGroupName -webAppName $webAppName -ZipFilePath $ZipFilePath -kuduPath $kuduPath 
Get-ChildItem ($ZipFolder + ":\" + $environnement) | Where-Object {$_.LastWriteTime -lt (get-date).adddays(-10)} | remove-item
remove-psdrive -name $ZipFolder