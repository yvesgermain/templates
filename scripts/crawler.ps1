$environnement = "devops"
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

$i = switch ($environnement){
"dev"    {"3"}
"qa"     {"4"}
"prd"    {"5"}
"devops" {"6"}
}

$SubnetAddressPrefix = "10.0.$i.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$PublicIPAddressName = "PIP-$environnement"
$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{"Environnement" = $environnement}
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

$DestKey = (get-azStorageAccountKey -Name gumbackups -ResourceGroupName infrastructure | where-object {$_.keyname -eq "key1"}).value
. $AzCopyPath /source:\\srvtfs01\drop\GuichetUnique\ControleQualite\ControleQualite-IC\20190920.4\TestExecCrawler\TriggerExecCrawler.zip /dest:https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip /destkey:$destkey

Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VmName -CommandId 'RunPowerShellScript' -ScriptPath "C:\templates\devops\scripts\Install-Chrome.ps1" 
Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId EnableRemotePS

$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$ComputerName\$VMLocalAdminUser", $VMLocalAdminSecurePassword
$ip = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPAddressName).ipaddress

New-AzStorageContext -StorageAccountName gumbackups -StorageAccountKey $Destkey
$storageContext = New-AzStorageContext -StorageAccountName gumbackups -StorageAccountKey $Destkey

get-AzStorageBlobContent -Container depot-tfs -Context $StorageContext -Blob TriggerExecCrawler.zip -Destination c:\temp\TriggerExecCrawler.zip
