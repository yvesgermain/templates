Save-azurermContext -Path "C:\Temp\AzContext.json" -Force

$scriptBlock = {
    $jobs = @()
    for ($i = 0; $i -lt 10; $i++) {
        $jobs += Start-Job -ScriptBlock {
            #Clear-azurermContext -Force | Out-Null
            Disable-azurermContextAutosave -Scope Process | Out-Null
            Import-azurermContext -Path "C:\Temp\AzContext-Empty.json" | Out-Null
            Import-azurermContext -Path "C:\Temp\AzContext.json" | Out-Null
            $AzContext = Get-azurermContext
            
            $rg = $(Get-azurermResourceGroup -azurermContext $AzContext).Count
            if (-not $rg) {
                Write-Error "Hit an issue..."
            }
            else {
                Write-Output "No problem..."
            }
        }
    }

    if($jobs.Count -ne 0)
    {
        Write-Output "Waiting for $($jobs.Count) test runner jobs to complete"
        foreach ($job in $jobs){
            $result = Receive-Job $job -Wait
            Write-Output $result
        }
        Remove-Job -Job $jobs
    }
}

$jobs = @()

for ($i = 0; $i -lt 5; $i++) {
    $jobs += Start-Job -ScriptBlock $scriptBlock
}

if($jobs.Count -ne 0)
{
    Write-Output "Waiting for $($jobs.Count) test runner jobs to complete"
    foreach ($job in $jobs){
        $result = Receive-Job $job -Wait
        Write-Output $result
    }
    Remove-Job -Job $jobs
}