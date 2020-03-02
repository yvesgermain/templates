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
if ($env:COMPUTERNAME -like "srvtfs01") { . "$DefaultWorkingDirectory\DevOps\scripts\Functions.ps1" }  else { . C:\templates\DevOps\scripts\Functions.ps1 }
if ($Domaine -like "AppsInterne") {
    $ResourceGroupName = "AppsInterne-rg-$environnement"; $webappnames = "Appsinterne-$environnement"
} else { 
    $ResourceGroupName = "gumsite-rg-$environnement"; $webappnames = "Gum-$environnement", "Gummaster-$Environnement"
};

$kudupath = 'App_Data/Logs/' ; 
$localpath = "c:\temp\logskudu\"; 
if ( Test-path $localpath) { remove-item $localpath -Recurse -Force -Confirm:$false }
mkdir $localpath
$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
$context = get-Azstorageaccount -ResourceGroupName infrastructure -StorageAccountName Gumlogs
"Getting Azure Gumlogs key"
$key = (Get-AzureRmStorageAccountKey -Name gumlogs -ResourceGroupName Infrastructure )[0].value

Foreach ($webappname in $webappnames) {
    $Result = try { Get-FileFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $kuduPath } catch [System.SystemException] { }; 
    if ($Result) {
        $Result | ForEach-Object {
            $name = $_.name;
            if (!( Test-path "$localPath$webappname\" )) { mkdir "$localPath$webappname" }
            # Copying $name in $localPath$webappname
            Read-FilesFromWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -kuduPath $("$kuduPath$name") -localPath $("$localPath$webappname\$name") }
        $Container = "$webappname$(get-date -Format `"yyyy-MM-dd`")".ToLower()
        "New-AzureRmStorageContainer -Context $context.context -Name $Container"
        if (!(get-AzStorageContainer -context $Context.context -Name $Container -ErrorAction SilentlyContinue)) {
            New-AzureRmStorageContainer -resourcegroupName Infrastructure -StorageAccountName gumlogs -Name $Container
        }
        & $AzCopyPath /Source:"$localPath$webappname" /Dest:"https://gumlogs.blob.core.windows.net/$Container" /DestKey:$key /S /Y
    } else { "Rien a sauver!" }
}
remove-item $localpath -Recurse -Force -Confirm:$false
