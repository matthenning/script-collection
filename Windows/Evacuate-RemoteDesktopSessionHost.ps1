<#
.SYNOPSIS
Disable new connections on a Remote Desktop Session Host,
then keeps looping through all disconnected sessions on the RDSH 
and checks if a process matching the search pattern is still running.
If not, the user will be logged off. The script is finished when all 
users are logged off.

.DESCRIPTION
This CMDlet allows you to softly evacuate an RDSH without disrupting
active users. For example when the host should be decommissioned or
you need to reboot the machine during business hours.

.LINK
https://github.com/matthenning/script-collection

.PARAMETER TargetRdsh
FQDN of the Session Host you wish to evacuate

.PARAMETER RdsConnectionBroker
FQDN of the responsible RDS Connection Broker

.PARAMETER RdsCollectionName
RDS Collection the RDSH is a member of

.PARAMETER ProcessSearchPattern
A regular expression matching the command line of the critical processes.
All users with active processes matching this pattern won't be logged off
until these processes are closed.

.PARAMETER FrequencySeconds
Check frequency. Default: 60 seconds

.EXAMPLE
Evacuate-RemoteDesktopSessionHost -TargetRdsh rdsh-01.contoso.com -RdsConnectionBroker rdcb.contoso.com -RdsCollectionName OfficeApps -ProcessSearchPattern Word|Excel
Evacuates the RDSH rdsh-01 but only if Excel and Word are not running.
#>
Function Evacuate-RemoteDesktopSessionHost {
    [CmdletBinding(
        SupportsShouldProcess=$True
    )]
    Param (
        [Parameter(Mandatory=$True)]
        [String]$TargetRdsh
    ,
        [Parameter(Mandatory=$True)]
        [String]$RdsConnectionBroker
    ,
        [Parameter(Mandatory=$True)]
        [String]$RdsCollectionName
    ,
        [Parameter(Mandatory=$False)]
        [String]$ProcessSearchPattern
    ,
        [Parameter(Mandatory=$False)]
        [Int]$FrequencySeconds = 60
    )

    Process {
        Import-Module RemoteDesktop

        Write-Verbose "Disabling new connection on RDSH"
        Set-RDSessionHost -SessionHost $TargetRdsh -NewConnectionAllowed No -ConnectionBroker $RdsConnectionBroker

        Write-Verbose "Retrieving active sessions on RDSH"
        $Sessions = Get-RDUserSession -CollectionName $RdsCollectionName -ConnectionBroker $RdsConnectionBroker | Where {$_.HostServer -eq $TargetRdsh}

        While ($Sessions.Count -gt 0) {

            If ($ProcessSearchPattern) {
                Write-Verbose "Retrieving processes on RDSH"
                $owners = @{}; 
                $cmd = @{}; 
                Get-WmiObject -Class Win32_Process -ComputerName $TargetRdsh | %{ 
                    Try { 
                        $Owners[$_.handle] = $_.getowner().user 
                        $Cmd[$_.handle] = $_.CommandLine
                    } 
                    Catch [Exception] {}
                }
                $Processes = Get-Process -ComputerName $TargetRdsh | Where {$_.ProcessName -match $ProcessSearchPattern} | Select ProcessName,Id,@{l='Owner';e={$Owners[$_.id.tostring()]}},@{l='CommandLine';e={$Cmd[$_.id.tostring()]}}

                ForEach ($Session in ($Sessions | Where {$_.SessionState -ne "STATE_ACTIVE" -and $_.SessionState -ne "STATE_CONNECTED"})) {
                    If (-Not ($Processes | Where {$_.Owner -eq $Session.UserName})) {
                        Write-Host ("Logging off " + $Session.UserName)
                        Invoke-RDUserLogoff -HostServer $Session.HostServer -UnifiedSessionID $Session.UnifiedSessionId -Force
                    }
                    Else {
                        Write-Verbose "$($Session.UserName) still has active processes. Skipping"
                    }
                }
            }
    
            Start-Sleep -Seconds $FrequencySeconds

            Write-Verbose "Retrieving active sessions on RDSH"
            $Sessions = Get-RDUserSession -CollectionName $RdsCollectionName -ConnectionBroker $RdsConnectionBroker | Where {$_.HostServer -eq $TargetRdsh}
            Write-Host ("" + $Sessions.Count + " Sessions remaining: " + $Sessions.UserName)

        }
    }
}
