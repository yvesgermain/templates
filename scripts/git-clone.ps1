import-module vsteam

if (test-path c:\templates\devops) {remove-item d:\templates\devops -force -recurse };
if (! (test-path c:\templates\devops)) {mkdir d:\templates\devops -force;
    git clone http://srvtfs01:8080/tfs/SOQUIJ/GuichetUnique/_git/DevOps d:\templates\devops;
}
set-location d:\templates\devops;

Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseWindowsAuthentication -verbose
Set-VSTeamDefaultProject -Project GuichetUnique

$id = (Get-VSTeamReleaseDefinition -ProjectName GuichetUnique | where-object { $_.name -like "Infrastructure Azure AppsInterne" }).id
$BuildId = (git log --pretty=oneline -n1 c:\templates\devops ).Substring(0, 8)
$Release = Add-VSTeamRelease -ArtifactAlias devops -ProjectName guichetUnique -BuildId $BuildId -DefinitionId $id
Show-VSTeamRelease -ProjectName GuichetUnique -id $Release.id