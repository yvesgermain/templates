import-module vsteam
#Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseBearerToken 'aeysyml9sQfogRSS+vQHfUoLEgpfRPOf4hQoPdjZYO4' -verbose

Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -PersonalAccessToken 'g7a2s2abfc4rf7p4uxnp22lbqvo2xqbqb4cexw3dgy5zwkaojveq' -verbose
Set-VSTeamDefaultProject -Project GuichetUnique
whoami.exe 
Get-VSTeamReleaseDefinition -ProjectName GuichetUnique -verbose | where-object { $_.name -like "Infrastructure Azure Guichet Unique" } 

# $Release = Add-VSTeamRelease -ArtifactAlias devops -ProjectName guichetUnique -BuildId $BuildId -DefinitionId $id
# Show-VSTeamRelease -ProjectName GuichetUnique -id $Release.id