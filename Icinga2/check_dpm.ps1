Import-Module DataProtectionManager

Try {
    Write-Verbose "Connection to DPM Server on $env:COMPUTERNAME"
    $DPMObject = Connect-DPMServer -DPMServerName $env:COMPUTERNAME -WarningAction SilentlyContinue
}
Catch [Exception] {
    Write-Host "CRITICAL - Could not connect to DPM server: $_"
    [Environment]::Exit(2)
}


Try {
    Write-Verbose "Refreshing alerts"
    $DPMObject.AlertController.RefreshAlerts()
}
Catch [Exception] {
    Write-Host "CRITICAL - Could not refresh alerts: $_"
    [Environment]::Exit(2)
}


Write-Verbose "Waiting for events to refresh"
Wait-Event -Timeout 20

$Alerts = @($DPMObject.AlertController.ActiveAlerts.Values)
$WarnCount = ($Alerts | Where {$_.Severity -eq "Warning"} | Measure-Object | Select count).Count
$ErrorCount = ($Alerts | Where {$_.Severity -like "Error"} | Measure-Object | Select count).Count

If ($Errors.Count -ne 0) {
    $Status = "CRITICAL - $ErrorCount errors and $WarnCount warnings."
    $ExitCode = 2
}
Elseif ($Warnings.Count -ne 0) {
    $Status = "WARNING - $WarnCount warnings"
    $ExitCode = 1
}
Else {
    $Status = "OK - No errors or warnings"
    $ExitCode = 0
}

Write-Host "$Status |'Warnings'=$WarnCount 'Errors'=$ErrorCount"
[Environment]::Exit($ExitCode)