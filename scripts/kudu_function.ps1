param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $environnement,
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("Gum", "AppsInterne")] 
    $Domaine,
    $DefaultWorkingDirectory
)
. $DefaultWorkingDirectory/DevOps/scripts/Functions.ps1;
if ($web -like "AppsInterne") {
    $ResourceGroupName = "AppsInterne-rg-$environnement"; $webappnames = "Appsinterne-$environnement"
} else { 
    $ResourceGroupName = "gumsite-rg-$environnement"; $webappnames = "Gum-$environnement", "Gummaster-$Environnement"
};

$kudupath = 'App_Data/Logs/' ; 
$localpath = "c:\temp\logskudu\"; 
Foreach ($webappname in $webappnames) {
    $Result = try { Get-FileFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $kuduPath } catch [System.SystemException] { }; 
    if ($Result) {
        $Result | ForEach-Object {
            $name = $_.name;
            if (!( Test-path "$localPath$webappname\" )) { mkdir "$localPath$webappname" }
            Read-FilesFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $("$kuduPath$name") -localPath $("$localPath$webappname\$name") }
    }
}