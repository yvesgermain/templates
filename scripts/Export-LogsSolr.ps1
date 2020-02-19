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
    $kuduPath = "server/solr/",
    $OutFile = "c:\temp\gumsolr-$environnement.zip",
    $InFile = "c:\temp\gumsolr-$environnement.zip",
    [Parameter(Mandatory = $True)]
    [string]
    $DefaultWorkingDirectory = "c:\templates"
)
. "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1"
Compress-kudufolder -Environnement prd -Method $method -SiteWeb GumSolr -kuduPath "server/solr/" -DefaultWorkingDirectory $DefaultWorkingDirectory

$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
"Getting Azure Gumlogs key"
$key = (Get-AzureRmStorageAccountKey -Name gumlogs -ResourceGroupName Infrastructure )[0].value

if ($method = "Get") {
$Container = "$SiteWeb$(get-date -Format `"yyyy-MM-dd`")".ToLower()
& $AzCopyPath /Source:$InFile /Dest:"https://gumlogs.blob.core.windows.net/$Container/$infile" /DestKey:$key /Y
}

