function copy-storage{
param(
     [Parameter(Mandatory = $True)]
     [string]
     [ValidateSet("dev", "qa", "prd", "devops")] 
     $Environnement,

     [Parameter(Mandatory = $True)]
     [string]
     [ValidateSet("storgum", "appsinterne")] 
     $storage
      
 )

$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

switch ($storage){
"storgum" {$ResourceGroupName = "gumstorage-rg-" + $environnement}
"appsinterne"   {$ResourceGroupName = "Storage-rg-" + $environnement}
}


$GumBackupKey = (get-azureRMstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object {$_.keyname -eq "key1"}).value
$GumBackupContext = (get-azstorageaccount -name gumbackups -ResourceGroupName Infrastructure).context

$date = get-date -Format "yyyy-MM-dd"

if (!( get-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-$date" -ErrorAction SilentlyContinue) ) {
    New-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-$date" 
}

$newStore = get-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-$date"
$newPath = $NewStore.name

$SourceKey = ( get-azureRMstorageaccountkey -Name "$storage$Environnement" -ResourceGroupName $ResourceGroupName | where-object {$_.keyname -eq "key1"}).value
$SourceContext = (get-azureRmstorageaccount -name "$storage$Environnement" -ResourceGroupName $ResourceGroupName ).context


. $AzCopyPath /source:https://$storage$environnement.blob.core.windows.net/appsinterne/ /sourcekey:$SourceKey /dest:https://gumbackups.blob.core.windows.net/$newPath/ /s /y /destkey:$GumBackupKey
}

# Restore storage  *************************************************

function restore-storage{
param(
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    
    [Parameter(Mandatory=$false,
    HelpMessage="Donner la date du restore dans le format yyyy-MM-dd, sinon on prendra le dernier backup")]
    [datetime]
    $date,

    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("strogum", "guichetunique", "appsinterne")] 
    $storage
 )

$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

switch ($storage){
"storgum" {$ResourceGroupName = "gumstorage-rg-" + $environnement}
"appsinterne"   {$ResourceGroupName = "Storage-rg-" + $environnement}
}

$GumBackupKey = (get-azureRMstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object {$_.keyname -eq "key1"}).value
$GumBackupContext = (get-azstorageaccount -name gumbackups -ResourceGroupName Infrastructure).context

if (!$date) {
$date= ((get-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-*" | sort -Property LastModified -Descending)[0]).LastModified.localdatetime
}

$date = $date.ToShortDateString()

if (!( get-AzStorageContainer -Context $GumBackupContext -name "$storage-$Environnement-$date" -ErrorAction SilentlyContinue)) {
    write-warning "Le blob n'existe pas";
    break 
}

$newPath = "$storage-$Environnement-$date"

. $AzCopyPath /source:https://storappsinterne$environnement.blob.core.windows.net/appsinterne/ /sourcekey:$SourceKey /dest:https://gumbackups.blob.core.windows.net/$newPath/ /s /y /destkey:$GumBackupKey
}