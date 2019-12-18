
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement 
)
<#
"Starting installation de lighthouse dans install-chrome2.ps1 " >> c:\log.log
Write-output "Starting installation de lighthouse dans install-chrome2.ps1 "  ;
set-location "C:\Program Files\nodejs"

.\npm prefix -g


.\npm install -g lighthouse >> c:\log.log
npm install -g lighthouse >> c:\log.log

.\npm list -g lighthouse --depth 0 >> c:\log.log

Write-output "Starting Crawler" ;

set-location "C:\Program Files\nodejs"
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-dev' , "gummaster-$environnement") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
#> 
# set-location "C:\Windows\System32\config\systemprofile\AppData\Roaming\npm"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")  + ";c:\program files\nodejs" 
$env:Path >> c:\log.log
where.exe node >> c:\log.log
Set-Location C:\crawler\b\
C:\crawler\b\ControleQualite.App.exe 

"Done!"
get-process chromedriver | stop-process -Force