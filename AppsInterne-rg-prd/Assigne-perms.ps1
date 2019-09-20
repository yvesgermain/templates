param(
     [string]
    [ValidateSet("dev", "qa", "prd", "devops")] 
    $Environnement
 )

$resourceGroupName = "AppsInterne-rg-$environnement"

# Donner les droits aux groupes Dev et QA sur les resources groups ***-dev et **-qa
if ( $Environnement -eq "dev" -or $Environnement -eq "qa") {
    $QA = Get-AzureRmADGroup -SearchString "QA"
    New-AzureRmRoleAssignment -ObjectId $QA.Id -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName -AllowDelegation
    $dev = Get-AzureRmADGroup -SearchString "dev"
    New-AzureRmRoleAssignment -ObjectId $dev.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroupName -AllowDelegation
}
