<#
.Synopsis
    Installs VIB packages from a URL or depot
.Description
    Installs VIB packages from a URL or depot. VIBs may be installed, upgraded, or downgraded.
    WARNING: If your installation requires a reboot, you need to disable HA first.

.PARAMETER VMHost
    The VMHost instance for the host being updated
    
.PARAMETER Depot
    Specifies full remote URL of the depot index.xml or file path pointing to an offline bundle .zip file on a local datastore.
    Use /path/to/depot.zip OR https://URL/index.xml

.PARAMETER Dryrun
     Performs a dry-run only. Report the VIB-level operations that would be performed, but do not change anything in the system.
    
.PARAMETER Force
    Bypasses checks for package dependencies, conflicts, obsolescence, and acceptance levels. Really not recommended
    unless you know what you are doing. Use of this option will result in a warning being displayed in vSphere Web Client.
    Use this option only when instructed to do so by VMware Technical Support.

.PARAMETER MaintenanceMode
    Pretends that maintenance mode is in effect. Otherwise, installation will stop for live installs that require maintenance mode.
    This flag has no effect for reboot required remediations.

.PARAMETER NoLiveInstall
    Forces an install to /altbootbank even if the VIBs are eligible for live installation or removal.
    Will cause installation to be skipped on PXE-booted hosts.

.PARAMETER NoSigCheck
    Bypasses acceptance level verification, including signing.
    Use of this option poses a large security risk and will result in a SECURITY ALERT warning being displayed in vSphere Web Client.

.PARAMETER Proxy
    Specifies a proxy server to use for HTTP, FTP, and HTTPS connections. The format is proxy-url:port.

.PARAMETER VibName
    Specifies VIBs from a depot, using one of the following forms: name, name:version, vendor:name, or vendor:name:version.

.PARAMETER VibUrl
    Specifies one URL of a VIB package to install. http:, https:, ftp:, and file: are all supported.
#>
function Install-ESXiVib {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]$VMHost,
        [string]$Depot,
        [switch]$Dryrun,
        [switch]$Force,
        [switch]$MaintenanceMode,
        [switch]$NoLiveInstall,
        [switch]$NoSigCheck,
        [string]$Proxy,
        [string]$VibName,
        [string]$VibUrl
    )

    #Validation - Check that Depot or VibUrl was specified
    if ($null -eq $Depot -and $null -eq $VibUrl) {
        throw [System.Exception] "Must specify either a Depot or Vib url."
    }

    #Validation - Check if user specified both a VibUrl and Depot
    if ($null -ne $Depot -and $null -ne $VibUrl) {
        throw [System.Exception] "Cannot specify both a Depot and Vib Url."
    }

    #Validation - If using a depot, the user must select a Vib name
    if ($null -ne $Depot -and $null -ne $VibName) {
        throw [System.Exception] "When using a Depot, you must specify a Vib Name."
    }

    try {
        $VMHostESXCLI = Get-EsxCli -V2 -VMHost $VMHost -ErrorAction:Stop
    } catch {
        throw [System.Exception] "Failed to get the EsxCli session for the specified host"
    }

    #Prepare Arguments
    $arguments = @{}

    if ($null -ne $Depot) {
        $arguments.Add('depot', $Depot)
    }

    if ($null -ne $VibName) {
        $arguments.Add('vibname', $VibName)
    }

    if ($null -ne $VibUrl) {
        $arguments.Add('viburl', $VibUrl)
    }

    if ($Dryrun) {
        $arguments.Add('dryrun', $true)
    }

    if ($Force) {
        $arguments.Add('force', $true)
    }

    if ($MaintenanceMode) {
        $arguments.Add('maintenancemode', $true)
    }

    if ($NoLiveInstall) {
        $arguments.Add('noliveinstall', $true)
    }

    if ($NoSigCheck) {
        $arguments.Add('nosigcheck', $true)
    }

    if ($null -ne $Proxy) {
        $arguments.Add('proxy', $Proxy)
    }

    $VMHostESXCLI.software.vib.install.Invoke($arguments)
}
