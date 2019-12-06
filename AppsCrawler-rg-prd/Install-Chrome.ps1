
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement 
)

$LocalTempDir = $env:TEMP; 
Write-output  "Installation de nodejs"
$NODEJS_FILENAME="node-v13.2.0-x64.msi"
$NODEJS_URL= "https://nodejs.org/dist/v13.2.0/$NODEJS_FILENAME"
$NODEJS_DOWNLOAD_LOCATION= "C:\"

(New-Object Net.WebClient).DownloadFile($NODEJS_URL, "$NODEJS_DOWNLOAD_LOCATION$NODEJS_FILENAME"); 
msiexec /qn /l* C:\node-log.txt /i "$NODEJS_DOWNLOAD_LOCATION$NODEJS_FILENAME"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-output "Starting installation de lighthouse" ;
set-location "C:\Program Files\nodejs"
$a = .\npm install -g lighthouse --loglevel verbose


$a >> c:\log.log
whoami.exe >> c:\log.log
Write-output "Installation de Chrome"

$ChromeInstaller = "ChromeInstaller.exe"; 
(new-object    System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller");
& "$LocalTempDir\$ChromeInstaller" /silent /install;
Write-output "Downloading TriggerExecCrawler.zip"
(new-object System.Net.WebClient).DownloadFile('https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip', "$env:temp\TriggerExecCrawler.zip");

"Decompressing file TriggerExecCrawler.zip in c:\crawler"
Expand-Archive -LiteralPath "$env:temp\TriggerExecCrawler.zip" -DestinationPath C:\crawler
Get-ChildItem C:\crawler\*\ControleQualite.App.exe | foreach-object {set-location $_.DirectoryName}
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-dev' , "gummaster-$environnement") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
<#

.\ControleQualite.App.exe

Write-output "Done controleQualiteApp.exe !"
get-process chromedriver | stop-process -Force

#>