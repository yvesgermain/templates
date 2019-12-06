
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement 
)


Write-output "Starting installation de lighthouse" ;
set-location "C:\Program Files\nodejs"
.\npm install -g lighthouse --loglevel verbose >> c:\log.log

Write-output "Starting Crawler" ;
Get-ChildItem C:\crawler\*\ControleQualite.App.exe | foreach-object {set-location $_.DirectoryName}
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-dev' , "gummaster-$environnement") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
.\ControleQualite.App.exe

"Done!"
get-process chromedriver | stop-process -Force