param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $environnement,
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("Gum","gummaster", "AppsInterne")] 
    $web,
    $DefaultWorkingDirectory
)
. $DefaultWorkingDirectory/DevOps/scripts/Functions.ps1;
if ($web -like "AppsInterne") {$ResourceGroupName = "AppsInterne-rg-$environnement"} else { $ResourceGroupName = "gumsite-rg-$environnement"};
$webappname = "$web-$environnement";
$kudupath = 'App_Data/Logs/' ; 
$localpath = "c:\temp\logskudu\"; 
$Result = try { Read-FilesFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $kuduPath } catch [System.SystemException] { }; 
if (!$Result) {
    $Result | ForEach-Object {
        $name = $_.name;
        if (!( Test-path "$localPath$webappname\" )) {mkdir "$localPath$webappname"}
        Read-FilesFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $("$kuduPath$name") -localPath $("$localPath$webappname\$name") }
}