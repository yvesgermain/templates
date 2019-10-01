Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement 
)

$VMLocalAdminUser = "Soquijadm"
$VMLocalAdminSecurePassword = (Get-AzureKeyVaultsecret -VaultName gumkeyvault -name Soquijadm ).SecretValue
$Location = "CanadaCentral"
$ResourceGroupName = "crawler-rg-$environnement"
$ComputerName = "VMcrawl-$environnement"
$VMName = "VMcrawl-$environnement"
$VMSize = "Standard_D2_v2"
$NetworkName = "CrawlNet-$environnement"
$NICName = "CrawlNIC-$environnement"
$SubnetName = "CrawlSubnet-$environnement"
$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
$chromepath = $env:System.DefaultWorkingDirectory +'\DevOps\AppsCrawler-rg-prd\Install-chrome.ps1'

$i = switch ($environnement) {
    "dev" { "3" }
    "qa" { "4" }
    "prd" { "5" }
    "devops" { "6" }
}

$SubnetAddressPrefix = "10.0.$i.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$PublicIPAddressName = "PIP-$environnement"
$SingleSubnet = New-AzureRMVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix

if ( get-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue ) { 
    "Removing resource group $ResourceGroupName"
    Remove-AzureRMResourceGroup -Name $ResourceGroupName -Force
}
 while (get-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue ) { start-sleep 20}

 "Création du resourceGroup $ResourceGroupName"
New-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{"Environnement" = $environnement } 
$Vnet = New-AzureRMVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet

$PIP = New-AzureRMPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic
$NIC = New-AzureRMNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);
$VirtualMachine = New-AzureRMVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRMVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzureRMVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzureRMVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
# $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable

"Création de la VM"
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Verbose

$DestKey = (get-AzureRmStorageAccountKey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value
$source = (Get-ChildItem \\srvtfs01\drop\GuichetUnique\ControleQualite\ControleQualite-IC\*\crawler\publish.zip | sort-object -Property creationdate)[0].fullname
"Copie du TriggerExecCrawler.zip dans https://gumbackups.blob.core.windows.net/depot-tfs"
. $AzCopyPath /source:$source /dest:https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip /destkey:$destkey /Y

$storageContext = New-AzureStorageContext -StorageAccountName gumbackups -StorageAccountKey $Destkey
"Permettre les droits sur le blob https://gumbackups.blob.core.windows.net/depot-tfs"
Get-AzureStorageContainer depot-tfs -Context $storageContext | set-AzurestorageContainerAcl -Permission Blob

"Donne accès à l'adresse IP du crawler au site gummaster"
$ip = (Get-AzureRMPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPAddressName).ipaddress
$Site = "gummaster-$environnement"
$APIVersion = ((Get-AzureRMResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
$WebAppConfig = (Get-AzureRMResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName GumSite-rg-$Environnement -ApiVersion $APIVersion)
$priority = 500;  
$IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
$IpSecurityRestrictions

[System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
    $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
    $webip.ipAddress = $ip + '/32';  
    $webip.action = "Allow"; 
    $webip.name = "Allow_Crawler"
    $webIP.priority = $priority;  
    $index= $ArrayList.Add($webIP); 
    $WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
    $WebAppConfig | Set-AzureRMResource -ApiVersion $APIVersion -Force -Verbose
}

"Configurer la vm avec Chrome et installer le crawler"
Invoke-AzureRMVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VmName -CommandId 'RunPowerShellScript' -ScriptPath $chromepath -Parameter @{"Environnement" = $Environnement }
"Retirer les droits sur le blob https://gumbackups.blob.core.windows.net/depot-tfs"
#Get-AzureStorageContainer depot-tfs -Context $storageContext | set-AzureRMstorageContainerAcl -Permission  Off

"Retire accès à l'adresse IP du crawler au site gummaster"

$ArrayList.Removeat( $Index ) 
$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
$WebAppConfig | Set-AzureRMResource -ApiVersion $APIVersion -Force -Verbose

if ( get-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue ) { Remove-AzureRMResourceGroup -Name $ResourceGroupName -Force }
