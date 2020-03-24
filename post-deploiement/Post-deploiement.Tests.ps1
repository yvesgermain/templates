param(
    [Parameter(Mandatory = $false)]
    [string[]]
    [ValidateSet("dev", "qa", "prd", "devops")]
    $Environnement = @("prd", "dev", "qa")
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Post-deploiement" {
    Context -name "Test Storage Account" {
        ForEach ($Environnement in $Environnement) {
            it "Vérifie que le storage account <storage>$Environnement existe" -TestCases $Stockage {
                param ($Storage, $ResourceGroupName, $Account, $container )
                Test-azstorageaccount -Environnement $Environnement -Storage $Storage -account $Account -ResourceGroupName $ResourceGroupName -container $container                 
            }
        }
    }
    Context -name "Test Storage Container" {
        ForEach ($Environnement in $Environnement) {
            it "Vérifie que le storage Container, <storage>$Environnement existe" -TestCases $Stockage {
                param ($Storage, $ResourceGroupName, $Account, $container )
                Test-azstorageContainer -Environnement $Environnement -Storage $Storage -account $Account -ResourceGroupName $ResourceGroupName -container $container
            }
        }
    }
    Context -name "Storage Blob" {
        ForEach ($Environnement in $Environnement) {    
            it "Vérifie que le blob <Container> du storage Account <Storage>$Environnement contient des documents" -TestCases $Stockage {
                param ($Storage, $ResourceGroupName, $Account, $container )
                Test-azStorageBlob -Environnement $Environnement -Storage $Storage -account $Account -ResourceGroupName $ResourceGroupName -container $container
            }
        }
    }
}
Describe "Service SQL" {
    Context -name "Vérifie le déploiement SQL dans GUM" {
        ForEach ($Environnement in $Environnement) {
            it "Vérifie le serveur SQL est <serveur>$Environnement" -TestCases $SQL {
                param ($Serveur, $ResourceGroupName, $BD)
                (get-azsqlserver -ResourceGroupName "$ResourceGroupName$Environnement").ServerName | should be "$serveur$Environnement"
            }
            it "Vérifie la BD est <BD>$Environnement pour le serveur <serveur>$Environnement" -TestCases $SQL {
                param ($Serveur, $ResourceGroupName, $BD)
                ( Get-azsqldatabase -ResourceGroupName "$ResourceGroupName$Environnement" -ServerName "$serveur$Environnement" -DatabaseName "$BD$Environnement").databasename | should be "$BD$Environnement"
            }
            it "Vérifie qu'il y a des tables dans la <BD>$Environnement (pas une BD vide!) du serveur <serveur>$Environnement" -TestCases $SQL {
                param ($Serveur, $ResourceGroupName, $BD)
                Test-azSqlTables -Serveur $serveur$Environnement -BD $BD$Environnement -Environnement $Environnement | should Not be "0"
            }
        }
    }
}
    
Describe "App Service" {
    Context -Name "" {
    
            
    }
}