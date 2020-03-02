Param(
    [Parameter()]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement
)

import-module vsteam
#Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseBearerToken 'aeysyml9sQfogRSS+vQHfUoLEgpfRPOf4hQoPdjZYO4' -verbose

Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -PersonalAccessToken 'rga4l26aavh7fkgsixbtwt3mhxshnjxlfzktlftlrcj4v4ikyu3q'
Set-VSTeamDefaultProject -Project GuichetUnique
$environment = "dev"

$GuichetUniqueid = (Get-VSTeamReleaseDefinition | where-object { $_.name -like "Guichet Unique" } ).id

$d = (Get-VSTeamRelease -top -1 -definitionId $GuichetUniqueid | foreach-object {
    Get-VSTeamRelease -id $_.id | foreach-object {
        $def = $_; 
        $_.Environments | foreach-object { if ($_.name -like $environment -and  $_.status -like "Succeeded" -and ($def.artifacts.definitionReference.branch |% { $_.name -like "*master"})) {
            $def}
        }
    }
}
)[0]

$RestoreGumSiteId = (Get-VSTeamReleaseDefinition | where-object { $_.name -like "Restore-Gum-Site" } ).id
$BuildId = ($d.environments | where-object {$_.name -like $environment }).id
$Release = Add-VSTeamRelease -ArtifactAlias "Guichet unique - IC" -BuildId $BuildId -DefinitionId $RestoreGumSiteId
