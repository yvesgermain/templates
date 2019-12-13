import-module vsteam
Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseBearerToken 'aeysyml9sQfogRSS+vQHfUoLEgpfRPOf4hQoPdjZYO4'
Set-VSTeamDefaultProject -Project GuichetUnique
whoami.exe 
$id = (Get-VSTeamReleaseDefinition -ProjectName GuichetUnique | where-object { $_.name -like "Infrastructure Azure Guichet Unique" }).id

# $Release = Add-VSTeamRelease -ArtifactAlias devops -ProjectName guichetUnique -BuildId $BuildId -DefinitionId $id
# Show-VSTeamRelease -ProjectName GuichetUnique -id $Release.id