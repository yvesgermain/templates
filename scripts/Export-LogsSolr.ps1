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
    $DefaultWorkingDirectory
)
. "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1" } 
Compress-kudufolder -Environnement prd -Method $method -SiteWeb GumSolr -kuduPath "server/solr/"
