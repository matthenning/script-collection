<#
.SYNOPSIS
Unregisters the Microsoft.Windows.Servermanagerworkflows PowerShell Session Configuration
Then registers and configures it again.

.DESCRIPTION
When deploying PowerShell profiles for all Session Configurations you can easily damage.
the Server Manager Workflow configuration. When this happens some cmdlets ceases to work.
This script fixes the Problem by reregistering the configuration.

.LINK
https://github.com/matthenning/script-collection

.PARAMETER WinVer
Windows version. Leave empty for automatic detection
10.0 = Windows 10 / Server 2016
6.3  = Windows 8.1 / Server 2012 R2
6.2  = Windows 8 / Server 2012

.EXAMPLE
Manually define Windows version
Reregister-ServerManagerPSSessionConfiguration -WinVer 10.0

.EXAMPLE
Automatic detection
Reregister-ServerManagerPSSessionConfiguration
#>
Function Reregister-ServerManagerPSSessionConfiguration {
    [CmdletBinding(
        SupportsShouldProcess=$True
    )]
    Param (
        [Parameter(Mandatory=$False)]
        [String]$WinVer
    )

    Process {
        If (-Not [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
            Write-Error "This CMDlet requires admin privileges"
            Return
        }

        If (-Not $WinVer) {
            $WinVer = (((Get-WmiObject -Class Win32_OperatingSystem).Version -split "\.")[0..1] -join ".")
        }

        $WinVer += ".0.0"
        Write-Verbose "Using Windows Assembly version $WinVer"
        
        Write-Verbose "Unregistering microsoft.windows.servermanagerworkflows"
        Unregister-PSSessionConfiguration -Name microsoft.windows.servermanagerworkflows
        Write-Verbose "Registering microsoft.windows.servermanagerworkflows"
        Register-PSSessionConfiguration -Name microsoft.windows.servermanagerworkflows -SessionType Workflow -UseSharedProcess -SecurityDescriptorSddl "O:NSG:BAD:P(A;;GA;;;IU)(A;;GA;;;BA)S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)" -PSVersion 3.0
        Write-Verbose "Updating settings for microsoft.windows.servermanagerworkflows"
        Set-PSSessionConfiguration -Name microsoft.windows.servermanagerworkflows -ModulesToImport "C:\Windows\\system32\\ServerManagerInternal","C:\Windows\\system32\\windowspowershell\\v1.0\\Modules\\PSWorkflow"
        Set-PSSessionConfiguration -Name microsoft.windows.servermanagerworkflows -ConfigurationTypeName Microsoft.Windows.ServerManager.Common.Workflow.WorkflowSessionConfiguration -AssemblyName "Microsoft.Windows.ServerManager.Common, Version=$WinVer, Culture=neutral,PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL"
    }
}
