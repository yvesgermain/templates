<#
.Synopsis
   Importe Bd et stockage d'un storage sur Azure
.DESCRIPTION
   Copy les Bds de 'https://gumbackups.blob.core.windows.net/sql-backup/' vers la Destination 
.EXAMPLE
   .\Restore-bdStockage.ps1 -Source prd -Destination dev -storage Gum
#>
Param(

    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Source,

    [Parameter(Mandatory = $True)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Destination,

    [Parameter(Mandatory = $True)]
    [ValidateSet("Gum", "AppsInterne", "Veille", "null")]
    [string]
    $BD,

    [Parameter(Mandatory = $True,
    HelpMessage = "Si null, aucune restauration de données")]
    [string]
    [ValidateSet("storgum", "storappsinterne", "null")] 
    $storage,

    [Parameter(Mandatory = $false,
        HelpMessage = "Donner la date du restore dans le format yyyyMMdd, sinon on prendra le dernier backup")]
    $date
)

if ((Get-ExecutionPolicy ).value -gt 1 ) { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force }

Set-PSRepository -InstallationPolicy Trusted -Name psgallery
if (!(Test-Path $profile)) {New-item –type file –force $profile }

if (!( get-module -ListAvailable vsteam)) {
    install-module vsteam
    $file = 'C:\Program Files\WindowsPowerShell\Modules\VSTeam\6.4.1\vsteam.classes.ps1'
    (get-content $file ).replace('      $this.isDeleted = $obj.isDeleted','#     $this.isDeleted = $obj.isDeleted') | set-content $file
}

Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseWindowsAuthentication -verbose
Set-VSTeamDefaultProject -Project GuichetUnique
$id = (Get-VSTeamReleaseDefinition -ProjectName GuichetUnique | where-object { $_.name -like "Restore BD et Stockage" }).id
$b = Get-VSTeamReleaseDefinition -ProjectName GuichetUnique -Id $id -Raw
$b.environments.variables.Destination.value = $Destination
$b.environments.variables.Storage.value = $storage
$b.environments.variables.Source.value = $Source
$b.environments.variables.BD.value = $BD
$b.environments.variables.date.value = $date
$body = $b | ConvertTo-Json -Depth 100
$body | Out-File -FilePath $env:TEMP\scrap.json -Encoding utf8
update-VSTeamReleaseDefinition -InFile $env:TEMP\scrap.json -ProjectName GuichetUnique -Verbose
if (![System.IO.directory]::Exists( "C:\templates\DevOps")) {
    mkdir C:\templates\DevOps
    git clone http://srvtfs01:8080/tfs/SOQUIJ/GuichetUnique/_git/DevOps c:\templates\devops
    $removedevops = 1
} else {
    Set-Location c:\templates\DevOps
    git pull
}
Push-Location 
Set-Location c:\templates\DevOps
$BuildId = (git log --pretty=oneline -n1 c:\templates\devops ).Substring(0, 8)
$Release = Add-VSTeamRelease -ArtifactAlias devops -ProjectName guichetUnique -BuildId $BuildId -DefinitionId $id
Show-VSTeamRelease -ProjectName GuichetUnique -id $Release.id
Pop-Location
if ( $removedevops -eq 1) { Remove-Item c:\templates\devops -Recurse -Force }
