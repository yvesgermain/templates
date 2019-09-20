# Connection à Azure
connect-azaccount
# Création de la variable Environnement
$Environnement = "devops"
# Création de l'environnement de stockage
cd \templates\devops\gumstorage-rg-prd
.\deploy.ps1 -environnement devops -ParametersFilePath .\parameters-$environnement.json
# Création de l'environnement pour les bases de données
cd \templates\devops\gumsql-rg-prd
.\deploy.ps1 -environnement $environnement -ParametersFilePath .\parameters-$environnement.json
# Création de l'environnement pour les sites Web
cd \templates\devops\GumSite-rg-prd
.\deploy.ps1 -environnement $environnement -ParametersFilePath .\parameters-$environnement.json
# Déployer le code source de TFS dans notre Environnement
Set-VSTeamAccount -Account http://srvtfs01:8080/tfs/soquij -UseWindowsAuthentication -verbose
Set-VSTeamDefaultProject -Project GuichetUnique
Get-VSTeamRelease -ProjectName GuichetUnique | where { $_.definitionName -like "Guichet Unique" } | fl *
Add-VSTeamRelease -DefinitionName "Guichet Unique-Devops" -Description Test -BuildNumber 3075

