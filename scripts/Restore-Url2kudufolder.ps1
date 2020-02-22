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
if ($webApp -like "Gumsolr") { $kuduPath = "server/solr/index/" } Else { $kuduPath = "app_data/logs/" } 
$WebappName = "$webapp-$Environnement"
$resourceGroupName = (get-azureRmwebapp -name $webAppName ).resourcegroup

if (!(Read-FilesFromWebApp -resourceGroupName gumsite-rg-prd -webAppName gumsolr-prd -kuduPath server/solr/index/)) {
    if (!( Get-PSDrive -name z -ErrorAction SilentlyContinue)) { new-azdrive }
    $Source = (Get-ChildItem ($ZipFolder + ":\" + $Environnement + "\" + $WebApp + "*.zip") | Sort-Object -property lastwritetime)[-1]
    copy-item -Path $source -Destination ("c:\temp\" + $environnement + "\")
    $ZipFilePath = "C:\temp\$environnement\" + $Source.name
    Restore-KuduFolderFromZipFile -Environnement $environnement -resourceGroupName $resourceGroupName -webAppName $webAppName -ZipFilePath $ZipFilePath -kuduPath $kuduPath 

    Get-ChildItem ($ZipFolder + ":\" + $environnement) | Where-Object { $_.LastWriteTime -lt (get-date).adddays(-10) } | remove-item
    remove-psdrive -name $ZipFolder
    Remove-Item -path $ZipFilePath -Confirm:$false
}