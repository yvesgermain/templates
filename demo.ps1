# Connection � Azure
connect-azaccount
Get-AzResourceGroup
Get-AzResourceGroup | where { $_.resourcegroupname -like "*-rg-devops"}
Get-AzResourceGroup | where { $_.resourcegroupname -like "*-rg-dev"}
# Donner la liste des serveurs SQL dans notre souscription dans Azure
Get-AzSqlServer
Get-AzSqlServer | select ServerName, ResourceGroupName, SqlAdministratorLogin
Get-AzSqlServer | Get-AzSqlDatabase
Get-AzSqlServer | Get-AzSqlDatabase | select databasename , servername, ResourceGroupName
# Donner la liste des sites web dans Azure
get-azwebapp
get-azwebapp | select name, location, OutboundIpAddresses
get-azappserviceplan  | select  name, ResourceGroup, @{ name ="tier"; e = {$_.sku.tier}},  @{ name ="Size"; e = {$_.sku.size}}
set-azappserviceplan -Name ASP-Standard-dev -ResourceGroupName appsinterne-rg-dev -tier free
Get-AzResourceGroup | where {$_.resourcegroupname -like "*-rg-dev"}  | select @{name = "Tag" ;e = {$_.tags.'Environnement'}}
Get-AzResourceGroup | where {$_.resourcegroupname -like "*-rg-prd"}  | select @{name = "Tag" ;e = {$_.tags.'Environnement'}}
Get-AzResourceGroup | where {$_.resourcegroupname -like "*-rg-prd"}  | Set-AzResourceGroup -tag @{ "Environnement" = "prd"}