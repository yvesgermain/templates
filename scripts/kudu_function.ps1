param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $environnement, 
    $DefaultWorkingDirectory
)
. $DefaultWorkingDirectory/DevOps/scripts/Functions.ps1;
$resourcegroupname = "gumsite-rg-$environnement";
$webappname = "gum-$environnement";
$kudupath = 'App_Data/Logs/' ; 
$localpath = "c:\temp\logskudu\"; 
$a = Read-FilesFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $kuduPath; 
$a | ForEach-Object {$name = $_.name;  Get-FileFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $("$kuduPath$name") -localPath $("$localPath$name") }