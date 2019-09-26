Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "qa", "prd", "devops")]
    [string]
    $Environnement = "devops"
)

$VMLocalAdminUser = "Soquijadm"
$VMLocalAdminSecurePassword = (Get-AzKeyVaultsecret -VaultName gumkeyvault -name Soquijadm ).SecretValue
$Location = "CanadaCentral"
$ResourceGroupName = "crawler-rg-$environnement"
$ComputerName = "VMcrawl-$environnement"
$VMName = "VMcrawl-$environnement"
$VMSize = "Standard_D2_v2"
$NetworkName = "CrawlNet-$environnement"
$NICName = "CrawlNIC-$environnement"
$SubnetName = "CrawlSubnet-$environnement"
$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

$i = switch ($environnement) {
    "dev" { "3" }
    "qa" { "4" }
    "prd" { "5" }
    "devops" { "6" }
}

$SubnetAddressPrefix = "10.0.$i.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$PublicIPAddressName = "PIP-$environnement"
$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{"Environnement" = $environnement }
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet

$PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable

New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Verbose

$DestKey = (get-azStorageAccountKey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value
$source = (Get-ChildItem \\srvtfs01\drop\GuichetUnique\ControleQualite\ControleQualite-IC\*\TestExecCrawler\TriggerExecCrawler.zip | sort-object CreationTime -Descending )[0].fullname
. $AzCopyPath /source:$source /dest:https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip /destkey:$destkey /Y

#  Donne accès à l'adresse IP du crawler au site gummaster
$ip = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPAddressName).ipaddress
$Site = "gummaster-$environnement"
$APIVersion = ((Get-AzResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]
$WebAppConfig = (Get-AzResource -ResourceType Microsoft.Web/sites/config -ResourceName $site -ResourceGroupName GumSite-rg-$Environnement -ApiVersion $APIVersion)
$priority = 500;  
$IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 
$IpSecurityRestrictions

[System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

if ($arrayList.ipAddress -notcontains ($Ip + '/32')) {
    $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
    $webip.ipAddress = $_ + '/32';  
    $webip.action = "Allow"; 
    $webip.name = "Allow_Crawler"
    $priority = $priority; 
    $webIP.priority = $priority;  
    $ArrayList.Add($webIP); 
    Remove-Variable webip

}
$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
$WebAppConfig | Set-AzResource  -ApiVersion $APIVersion -Force -Verbose

$storageContext = New-AzStorageContext -StorageAccountName gumbackups -StorageAccountKey $Destkey
Get-AzStorageContainer depot-tfs -Context $storageContext | set-AzstorageContainerAcl -Permission Blob

get-AzStorageBlobContent -Container depot-tfs -Context $StorageContext -Blob TriggerExecCrawler.zip -Destination c:\temp\TriggerExecCrawler.zip
Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VmName -CommandId 'RunPowerShellScript' -ScriptPath "C:\templates\devops\scripts\Install-Chrome.ps1" 

#  Retire accès à l'adresse IP du crawler au site gummaster
$ArrayList.Remove($webIP); 
$WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
$WebAppConfig | Set-AzResource  -ApiVersion $APIVersion -Force -Verbose
