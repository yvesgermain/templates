param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $environnement,
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("Get", "Put")] 
    $Method,
    [Parameter(Mandatory = $True)]    
    [string]
    $DefaultWorkingDirectory
)
if ($env:COMPUTERNAME -like "srvtfs01") { . "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1" }  else { . C:\templates\DevOps\scripts\Functions.ps1 }
Compress-kudufolder -Environnement prd -Method $method -SiteWeb GumSolr -kuduPath "server/solr/"
