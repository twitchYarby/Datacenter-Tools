<#
.Synopsis
    Updates the host with VIBs from an image profile in a depot
.Description
    Updates the host with VIBs from an image profile in a depot. Installed VIBs may be upgraded
    (or downgraded if --allow-downgrades is specified), but they will not be removed. Any VIBs in
    the image profile which are not related to any installed VIBs will be added to the host.
    WARNING: If your installation requires a reboot, you need to disable HA first.

.PARAMETER VMHost
    The VMHost instance for the host being updated
    
.PARAMETER Depot
    Specifies full remote URL of the depot index.xml or file path pointing to an offline bundle .zip file on a local datastore.
    Use /path/to/depot.zip OR https://URL/index.xml

.PARAMETER AllowDowngrade
    If this option is specified, then the VIBs from the image profile which update, downgrade, or are new to the host will be installed.
    If the option is not specified, then the VIBs which update or are new to the host will be installed.

.PARAMETER Dryrun
    Performs a dry-run only. Report the VIB-level operations that would be performed, but do not change anything in the system.
    
.PARAMETER Force
    Bypasses checks for package dependencies, conflicts, obsolescence, and acceptance levels. Really not recommended
    unless you know what you are doing. Use of this option will result in a warning being displayed in vSphere Web Client.
    Use this option only when instructed to do so by VMware Technical Support.

.PARAMETER MaintenanceMode
    Pretends that maintenance mode is in effect. Otherwise, installation will stop for live installs that require maintenance mode.
    This flag has no effect for reboot required remediations.

.PARAMETER NoHardwareWarning
    Allows the transaction to proceed when hardware precheck returns a warning.
    A hardware error will continue to be shown with this option. Use of this option may result in device not functioning normally.

.PARAMETER NoLiveInstall
    Forces an install to /altbootbank even if the VIBs are eligible for live installation or removal.
    Will cause installation to be skipped on PXE-booted hosts.

.PARAMETER NoSigCheck
    Bypasses acceptance level verification, including signing.
    Use of this option poses a large security risk and will result in a SECURITY ALERT warning being displayed in vSphere Web Client.

.PARAMETER OkToRemove
    Allows the removal of installed VIBs as part of applying the image profile.
    If not specified, esxcli will error out if applying the image profile results in the removal of installed VIBs.

.PARAMETER ImageProfile
    Specifies the name of the image profile to install

.PARAMETER Proxy
    Specifies a proxy server to use for HTTP, FTP, and HTTPS connections. The format is proxy-url:port.

.EXAMPLE
    Install-EsxProfile -VMHost $VMHost -Depot "vmstore:\Datastore01\updates\depot.zip" -Dryrun -ImageProfile "TheProfileName"
#>
function Update-ESXiProfile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]$VMHost,
        [Parameter(Mandatory)]
        [string]$Depot,
        [switch]$AllowDowngrades,
        [switch]$Dryrun,
        [switch]$Force,
        [switch]$MaintenanceMode,
        [switch]$NoHardwareWarning,
        [switch]$NoLiveInstall,
        [switch]$NoSigCheck,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ImageProfile,
        [string]$Proxy
    )

    try {
        $VMHostESXCLI = Get-EsxCli -V2 -VMHost $VMHost -ErrorAction:Stop
    } catch {
        throw [System.Exception] "Failed to get the EsxCli session for the specified host"
    }

    #Validation - Check if the ImageProfile exists
    try{
        $profiles = $VMHostESXCLI.software.sources.profile.list.Invoke(@{'depot' = $Depot})
        
        if ($profiles.Name.Contains($ImageProfile) -ne "True")
        {
            throw [System.Exception] "Depot exists, but does not contain the specified Image Profile: " + $ImageProfile
        }
    }catch{
        throw [System.Exception] "Depot does not exists or is corrupt."
    }

    #Prepare Arguments
    $arguments = @{}

    $arguments.Add('depot', $Depot)
    $arguments.Add('profile', $ImageProfile)

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

    if ($AllowDowngrades) {
        $arguments.Add('allowdowngrades', $true)
    }

    if ($NoHardwareWarning) {
        $arguments.Add('nohardwarewarning', $true)
    }

    if ($null -ne $Proxy) {
        $arguments.Add('proxy', $Proxy)
    }


    $VMHostESXCLI.software.profile.update.Invoke($arguments)
}
