param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("Get", "Put")] 
    $Method,
    [string]
    [ValidateSet("GumSolr", "Gum" , "GumMaster" , "Veille", "Appsinterne")] 
    $SiteWeb = "GumSolr",
    $kuduPath = "server/solr/index/",
    $OutFile = "c:\temp\gumsolr-$environnement.zip",
    $InFile = "c:\temp\gumsolr-$environnement.zip",
    [Parameter(Mandatory = $True)]
    [string]
    $DefaultWorkingDirectory = "c:\templates"
)
. "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1"
Compress-kudufolder -Environnement prd -Method $method -SiteWeb GumSolr -kuduPath $kuduPath -DefaultWorkingDirectory $DefaultWorkingDirectory

$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
"Getting Azure Gumlogs key"
$key = (Get-AzStorageAccountKey -Name gumlogs -ResourceGroupName Infrastructure )[0].value

if ($method -eq "Get") {
    $Container = "$SiteWeb$(get-date -Format `"yyyy-MM-dd`")".ToLower()
    $dest = ("https://gumlogs.blob.core.windows.net/$Container/" + $infile.split('\')[-1])
    & $AzCopyPath /Source:$InFile /Dest:$Dest /DestKey:$key /Y
}

if ($method -eq "Put") {
    $context = get-Azstorageaccount -ResourceGroupName infrastructure -StorageAccountName Gumlogs
    $Container = (Get-AzStorageContainer -Context $Context.Context | Where-Object { $_.name -like "Gum*" } | Sort-Object -Property LastModifiedtime -Descending )[0].name
    $file = $InFile.split('\')[-1]
    & $AzCopyPath /Source:"https://gumlogs.blob.core.windows.net/$Container/$file" /SourceKey:$key /Dest:$outfile /Y
}
    
    