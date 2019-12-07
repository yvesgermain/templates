
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement 
)


Write-output "Starting installation de lighthouse" ;
set-location "C:\Program Files\nodejs"

.\npm prefix -g

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

.\npm install lighthouse 
npm install lighthouse

.\npm list -g lighthouse --depth 0 >> c:\log.log

Write-output "Starting Crawler" ;
$dir = Get-ChildItem C:\crawler\*\ControleQualite.App.exe 
set-location $dir.DirectoryName
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-dev' , "gummaster-$environnement") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
.\ControleQualite.App.exe

"Done!"
get-process chromedriver | stop-process -Force