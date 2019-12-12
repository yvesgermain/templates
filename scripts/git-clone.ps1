
Param(
[Parameter(Mandatory = $True)]
[string]
$Build
)

if (! (test-path c:\templates\devops)) {mkdir c:\templates\devops -force}
set-location c:\templates\devops
git clone http://srvtfs01:8080/tfs/SOQUIJ/GuichetUnique/_git/DevOps c:\templates\devops

Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseWindowsAuthentication -verbose
Set-VSTeamDefaultProject -Project GuichetUnique
#$id = (Get-VSTeamReleaseDefinition -ProjectName GuichetUnique | where-object { $_.name -like "Infrastructure Azure Guichet Unique" }).id
$id = 37
$b = Get-VSTeamReleaseDefinition -ProjectName GuichetUnique -Id $id -Raw
$b.environments | foreach-object { if ($_.name -like $environnement) { $_.variables.build.value = $build} }

$body = $b | ConvertTo-Json -Depth 100
$body | Out-File -FilePath $env:TEMP\scrap.json -Encoding utf8
update-VSTeamReleaseDefinition -InFile $env:TEMP\scrap.json -ProjectName GuichetUnique -Verbose