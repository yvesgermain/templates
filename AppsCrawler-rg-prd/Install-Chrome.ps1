$LocalTempDir = $env:TEMP; 
"Starting";
$ChromeInstaller = "ChromeInstaller.exe"; 
(new-object    System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller");
& "$LocalTempDir\$ChromeInstaller" /silent /install;
"Downloading TriggerExecCrawler.zip"
(new-object System.Net.WebClient).DownloadFile('https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip', "$env:temp\TriggerExecCrawler.zip");
"Decompressing file TriggerExecCrawler.zip in c:\crawler"
Expand-Archive -LiteralPath "$env:temp\TriggerExecCrawler.zip" -DestinationPath C:\crawler
Get-ChildItem C:\crawler\Content\C_C\agent\*\*\*\*\TriggerExecCrawler\obj\Release\netcoreapp2.1\PubTmp\Out\bin | set-location
(Get-Content ControleQualite.App.exe.config ).replace('gummaster-dev' , "gummaster-devops") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
.\ControleQualite.App.exe
"Done!";