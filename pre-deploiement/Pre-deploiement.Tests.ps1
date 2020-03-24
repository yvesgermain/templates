param (
    [Parameter()]
    [string[]]
    $Environnement = @("prd", "dev", "qa", "devops")
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Comptes de service" {
    Context -Name "Vérifier votre compte dans Azure" {
        (get-azcontext ).Subscription | should be (Get-AzSubscription ).Id
    }
    Context -Name "Vérifier les comptes de service" {
        ForEach ($Environnement in $Environnement ) {
            It "Vérifie que le compte SQLadmin$Environnement existe et est capable de se connecter" {
                (Test-AzAccount -UserName SQLadmin -environnement $Environnement).id | Should Be "Sqladmin$Environnement@gumqc.OnMicrosoft.com"
            }
            It "Vérifie que le compte SQLrw$Environnement existe et est capable de se connecter" {
                (Test-AzAccount -UserName SQLrw -environnement $Environnement).id | Should Be "Sqlrw$Environnement@gumqc.OnMicrosoft.com"
            }
        }
        It "Vérifie que le compte gumqcdevops existe" {
            ( Get-AzADServicePrincipal -DisplayName gumqcdevops).DisplayName | Should Be "gumqcdevops"
        }
    }
    Context -name "Infrastructure" {
        ForEach ($Environnement in $Environnement ) {
            it "Vérifie que le répertoire c:\temp\$environnement existe sur le serveur TFS" {
                test-path \\srvdevops\c$\temp\$environnement | should be $true
            }
        }
        it "Vérifie le path pour le fichier azcopy.exe" {
            test-path "\\srvdevops\c$\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe" | should be $true
        }
    }
    Context -name "Storage Backup" {
        ForEach ($Environnement in $Environnement) {
            foreach ( $Storage in "guichetunique", "appsinterne" ) {
                it "Vérifie que le backup existe pour le fichier $storage-$Environnement" {
                    Test-AzStorage -Environnement $Environnement -Storage $Storage
                }
            }
        }
    }
}
Describe "Backup de BD" {
    Context -name "BD Backup" {
        ForEach ($Environnement in $Environnement) {
            foreach ( $BD in "BdGum-", "BdAppsInterne-", "BdVeille-" ) {
                it "Vérifie que le backup existe pour le fichier $BD$Environnement" {
                    Test-AzBD -Environnement $Environnement -BD $BD
                }
            }
        }
    }
}