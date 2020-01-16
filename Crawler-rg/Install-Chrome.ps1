
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

Write-output "Installation de Chrome"

$ChromeInstaller = "ChromeInstaller.exe"; 
Write-output "Downloading chromeinstaller.exe"
(new-object System.Net.WebClient).DownloadFile('https://gumbackups.blob.core.windows.net/depot-tfs/ChromeStandaloneSetup64.exe', "$env:temp\$ChromeInstaller");
& "$LocalTempDir\$ChromeInstaller" /silent /install;
<#
(new-object System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller");
& "$LocalTempDir\$ChromeInstaller" /silent /install;
#>

Write-output "Downloading TriggerExecCrawler.zip"
(new-object System.Net.WebClient).DownloadFile('https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip', "$env:temp\TriggerExecCrawler.zip");
"Decompressing file TriggerExecCrawler.zip in c:\crawler"
Expand-Archive -LiteralPath "$env:temp\TriggerExecCrawler.zip" -DestinationPath C:\crawler
$dir = (Get-ChildItem C:\crawler\*\ControleQualite.App.exe ).directoryname

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") + ';C:\windows\system32\config\systemprofile\AppData\Roaming\npm;c:\program files\nodejs'

"Installation de lighthouse dans install-chrome.ps1" >> c:\log.log
Write-output "Starting installation de lighthouse" ;
set-location "C:\Program Files\nodejs"
.\npm install -g lighthouse >> c:\log.log
"npm install -g lighthouse" >> c:\log.log
npm install -g lighthouse >> c:\log.log
.\npm prefix -g

set-location $dir

(Get-Content ControleQualite.App.exe.config) -replace('gummaster-(dev|qa|prd)\.azure' , "gummaster-$environnement.azure") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
(Get-Content ControleQualite.App.exe.config ).replace('value="head"','value="headless"') | set-content .\ControleQualite.App.exe.config -Encoding UTF8
# C:\crawler\b\ControleQualite.App.exe 
$PSVersionTable >> c:\log.log
where.exe node >> c:\log.log
get-process chromedriver | stop-process -Force
