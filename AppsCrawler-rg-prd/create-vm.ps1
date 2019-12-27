$VMLocalAdminUser = "Soquijadm"
$VMLocalAdminSecurePassword = (Get-AzureKeyVaultsecret -VaultName gumkeyvault -name Soquijadm ).SecretValue
$Location = "CanadaCentral"
$ResourceGroupName = "VmCrawler-rg"
$ComputerName = "VMcrawler"
$VMName = "VMcrawl"
$VMSize = "Standard_D2_v2"
$NetworkName = "CrawlNet"
$NICName = "CrawlerNIC"
$SubnetName = "CrawlSubnet"
$PublicIPAddressName = "PIP-crawler"
New-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{"Environnement" = "VmCrawler" } 
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$SingleSubnet = New-AzureRMVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$AzCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"

$Vnet = New-AzureRMVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet

$PIP = New-AzureRMPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic
$NIC = New-AzureRMNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);
$VirtualMachine = New-AzureRMVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRMVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzureRMVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzureRMVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
$VirtualMachine = Set-AzureRMVMBootDiagnostics -VM $VirtualMachine -Disable

"Creation de la VM"
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Verbose

$DestKey = (get-AzureRmStorageAccountKey -Name gumbackups -ResourceGroupName infrastructure | where-object { $_.keyname -eq "key1" }).value
$source = (Get-ChildItem \\srvtfs01\drop\GuichetUnique\ControleQualite\ControleQualite-IC\*\crawler\publish.zip | sort-object -Property creationtime)[0].fullname
"Copie du TriggerExecCrawler.zip dans https://gumbackups.blob.core.windows.net/depot-tfs"
. $AzCopyPath /source:$source /dest:https://gumbackups.blob.core.windows.net/depot-tfs/TriggerExecCrawler.zip /destkey:$destkey /Y

$storageContext = New-AzureStorageContext -StorageAccountName gumbackups -StorageAccountKey $Destkey
"Permettre les droits sur le blob https://gumbackups.blob.core.windows.net/depot-tfs"
Get-AzureStorageContainer depot-tfs -Context $storageContext | set-AzurestorageContainerAcl -Permission Blob

"Donne accès à l'adresse IP du crawler au site Gum et gummaster"
$VmIP = (Get-AzureRMPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPAddressName).ipaddress
$APIVersion = ((Get-AzureRMResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]

$storageContext = New-AzureStorageContext -StorageAccountName gumbackups -StorageAccountKey $Destkey
"Permettre les droits sur le blob https://gumbackups.blob.core.windows.net/depot-tfs"
Get-AzureStorageContainer depot-tfs -Context $storageContext | set-AzurestorageContainerAcl -Permission Blob

"Configurer la vm avec Chrome et installer le crawler"
Invoke-AzureRMVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptPath $chromepath -Parameter @{"Environnement" = $Environnement }

$Environnements = "dev", "qa", "prd"
$Sites = "gummaster", "gum"

foreach ($Environnement in $Environnements) {
    foreach ($site in $sites) {
        $WebAppConfig = (Get-AzureRMResource -ResourceType Microsoft.Web/sites/config -ResourceName "$site-$Environnement" -ResourceGroupName GumSite-rg-$Environnement -ApiVersion $APIVersion)
        if ( Get-Variable -name "WebAppConfig$site" ) { Remove-Variable -Name "WebAppConfig$site" }
        New-Variable -Name "WebAppConfig$site" -Value $webAppConfig
        $priority = 500;  
        if ( Get-Variable -name "IpSecurityRestrictions$site" ) { Remove-Variable -Name "IpSecurityRestrictions$site" }
        New-Variable -Name "IpSecurityRestrictions$site" -value $WebAppConfig.Properties.ipsecurityrestrictions; 
        $IpSecurityRestrictions = $WebAppConfig.Properties.ipsecurityrestrictions; 

        [System.Collections.ArrayList]$ArrayList = $IpSecurityRestrictions ;

        if ($arrayList.ipAddress -notcontains ($VmIP + '/32')) {
            $webIP = [PSCustomObject]@{ipAddress = ''; action = ''; priority = ""; name = ""; description = ''; }; 
            $webip.ipAddress = $Vmip + '/32';  
            $webip.action = "Allow"; 
            $webip.name = "Allow_Crawler"
            $priority = $priority + 20 ; 
            $webIP.priority = $priority;  
            $ArrayList.Add($webIP); 
            Remove-Variable webip
        }

        $WebAppConfig.properties.ipSecurityRestrictions = $ArrayList
        Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
    }

    "Run lighthouse remotely"
    Invoke-AzureRMVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptPath .\Run-lighthouse.ps1 -Parameter @{"Environnement" = $Environnement }

    "Retire accès à l'adresse IP du crawler au site Gum et gummaster"

    foreach ($site in $sites) {
        $WebAppConfig = (Get-Variable -Name "WebAppConfig$site").value
        $WebAppConfig.properties.ipSecurityRestrictions = (get-variable -name "IpSecurityRestrictions$site").value
        Set-AzureRmResource -resourceid $webAppConfig.ResourceId -Properties $WebAppConfig.properties -ApiVersion $APIVersion -Force
    }
}

"Retirer les droits sur le blob https://gumbackups.blob.core.windows.net/depot-tfs"
Get-AzureStorageContainer depot-tfs -Context $storageContext | set-AzurestorageContainerAcl -Permission  Off