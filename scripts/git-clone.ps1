import-module vsteam
#Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseBearerToken 'aeysyml9sQfogRSS+vQHfUoLEgpfRPOf4hQoPdjZYO4' -verbose

Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -PersonalAccessToken 'rga4l26aavh7fkgsixbtwt3mhxshnjxlfzktlftlrcj4v4ikyu3q'
Set-VSTeamDefaultProject -Project GuichetUnique


$id = (Get-VSTeamReleaseDefinition | where-object { $_.name -like "Guichet Unique" } ).id

$d = (Get-VSTeamRelease -top -1 -definitionId $id | foreach-object {
    Get-VSTeamRelease -id $_.id | foreach-object {
        $def = $_; 
        $_.Environments | foreach-object { if ($_.name -like "qa" -and  $_.status -like "Succeeded" -and ($def.artifacts.definitionReference.branch |% { $_.name -like "*master"})) {
            $def}
        }
    }
}
)[0]

$Release = Add-VSTeamRelease -ArtifactAlias devops -BuildId $BuildId -DefinitionId $id
$LastMasterBuildId = (get-vsteambuild -Definitions 17 -ResultFilter "succeeded" -StatusFilter "completed"  | where {$_.sourceBranch -eq "refs/heads/master"})[0].id
