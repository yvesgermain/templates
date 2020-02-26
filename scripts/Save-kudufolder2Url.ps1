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
    [ValidateSet("x", "y", "z")] 
    $ZipFolder = "Z"
)

# Declaration de variables:
if ($env:COMPUTERNAME -like "srvtfs01") { . "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1" }  else { . C:\templates\DevOps\scripts\Functions.ps1 }
if ($webApp -like "Gumsolr") { $kuduPath = "server/solr/index/" } Else { $kuduPath = "App_Data/Logs/" } 
if (!( Get-PSDrive -name z -ErrorAction SilentlyContinue)) { new-azdrive }
$WebappName = "$webapp-$Environnement"
$resourceGroupName = (get-azureRmwebapp -name $webAppName ).resourcegroup
$ZipFilePath = ("c:\temp\" + $environnement + "\" + $webAppName + (get-date -Format "yyyy-MM-dd") + ".zip") 
$Destination = ($ZipFolder + ":\" + $environnement + "\" + $webAppName + (get-date -Format "yyyy-MM-dd") + ".zip") 

$scrap = Compress-KuduFolderToZipFile -Environnement $environnement -resourceGroupName $resourceGroupName -webAppName $webAppName -ZipFilePath $ZipFilePath -kuduPath $kuduPath
if ($scrap -notlike "false") {
    copy-item -Path $ZipFilePath  -Destination $Destination
    Get-ChildItem ($ZipFolder + ":\" + $environnement) | Where-Object { $_.LastWriteTime -lt (get-date).adddays(-10) } | remove-item
    remove-psdrive -name $ZipFolder
    Remove-Item -path $ZipFilePath -Confirm:$false
} else { "Le folder $kuduPath n'existe pas!"}