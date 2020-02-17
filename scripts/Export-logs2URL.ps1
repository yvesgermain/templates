param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $environnement,
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("Gum", "AppsInterne")] 
    $Domaine,
    [Parameter(Mandatory = $True)]    
    [string]
    $DefaultWorkingDirectory
)
. $DefaultWorkingDirectory/DevOps/scripts/Functions.ps1;
if ($Domaine -like "AppsInterne") {
    $ResourceGroupName = "AppsInterne-rg-$environnement"; $webappnames = "Appsinterne-$environnement"
}
else { 
    $ResourceGroupName = "gumsite-rg-$environnement"; $webappnames = "Gum-$environnement", "Gummaster-$Environnement"
};

$kudupath = 'App_Data/Logs/' ; 
$localpath = "c:\temp\logskudu\"; 

if (! (Test-Path $localpath )) {mkdir $localpath}
Foreach ($webappname in $webappnames) {
    $Result = try { Get-FileFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $kuduPath } catch [System.SystemException] { }; 
    if ($Result) {
        $Result | ForEach-Object {
            $name = $_.name;
            if (!( Test-path "$localPath$webappname\" )) { mkdir "$localPath$webappname" }
            # Copying $name in $localPath$webappname
            Read-FilesFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $("$kuduPath$name") -localPath $("$localPath$webappname\$name") }
    }
    else { "Rien a sauver!" }
} 

$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
"Getting Azure Gumlogs key"
$key = (Get-AzureRmStorageAccountKey -Name gumlogs -ResourceGroupName Infrastructure )[0].value
# $context = Get-AzureRmStorageAccount -Name gumlogs -ResourceGroupName infrastructure
[string] $Container = "$webappname$(get-date -Format `"yyyy-MM-dd`")".ToLower()
# New-AzureRmStorageContainer -Context $context.context -Name $Container
remove-item $localpath -Recurse -Force -Confirm:$false

New-AzureRmStorageContainer -resourcegroupName Infrastructure -StorageAccountName gumlogs -Name $Container

& $AzCopyPath /Source:"$localPath$webappname" /Dest:"https://gumlogs.blob.core.windows.net/$Container" /DestKey:$key /S /Y

remove-item $localpath -Recurse -Force -Confirm:$false