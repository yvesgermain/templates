
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd")]
    [string]
    $Environnement 
)
set-location "C:\Program Files\nodejs"
.\npm install -g lighthouse >> c:\log.log
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") + ';C:\windows\system32\config\systemprofile\AppData\Roaming\npm;c:\program files\nodejs'

$dir = (Get-ChildItem C:\crawler\*\ControleQualite.App.exe ).directoryname
Set-Location $dir
(Get-Content ControleQualite.App.exe.config) -replace('gummaster-(dev|qa|prd)\.azure' , "gummaster-$environnement.azure") | set-content .\ControleQualite.App.exe.config -Encoding UTF8
(Get-Content ControleQualite.App.exe.config ).replace('value="head"','value="headless"') | set-content .\ControleQualite.App.exe.config -Encoding UTF8
.\ControleQualite.App.exe 

"Done!"
get-process chromedriver | stop-process -Force
