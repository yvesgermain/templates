function Test-AzAccount (
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [Parameter(Mandatory = $True)]
    [string]
    $UserName
) {
    $passw = (Get-azkeyvaultsecret -name $UserName$Environnement -VaultName gumkeyvault ).secretValue
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$UserName$Environnement@gumqc.OnMicrosoft.com", $passw
    $context = Connect-AzAccount -Credential $credential
    Disconnect-AzAccount -Username $context.Context.Account
}

function Test-AzStorage (
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [Parameter(Mandatory = $True)]
    [string]
    $Storage
) {
    # $GumBackupKey = (get-Azstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value
    $Context = get-azstorageaccount -resourcegroupName Infrastructure -name gumbackups

    if (get-AzStorageContainer -context $Context.context | where-object { $_.name -like "$container-$Environnement-*" } -ErrorAction SilentlyContinue) {$true}
}
function Test-AzBD (
    [Parameter(Mandatory = $True)]
    [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement,
    [Parameter(Mandatory = $True)]
    [string]
    $BD
) {
    # $GumBackupKey = (get-Azstorageaccountkey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value
    $Context = get-azstorageaccount -resourcegroupName Infrastructure -name gumbackups

    if (Get-AzureStorageBlob -Context $context.Context -Container sql-backup | Where-Object { $_.name -like ($bd + "*") }  -ErrorAction SilentlyContinue) {$true}
}
