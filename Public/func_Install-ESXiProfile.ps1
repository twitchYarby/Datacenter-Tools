function Install-ESXiProfile {
    <#
    .Synopsis
        Install a new Image Profile to the specified ESXi host from a local datastore
    .Description
        This command is the PowerCLI equivalent of executing the shell command: esxcli software profile install
        You can specify either a Local or a Remote Depot, but an error will be thrown if you select both.
        If selecting a Local Depot, use the absolute path from root and use the Datastore name, not it's GUID.

    .PARAMETER VMHost
        The VMHost instance for the host being updated
    
    .PARAMETER Depot
        Specifies full remote URL of the depot index.xml or server file path pointing to an offline bundle .zip file.

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
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]$VMHost,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Depot,
        [switch]$Dryrun,
        [switch]$Force,
        [switch]$MaintenanceMode,
        [switch]$NoHardwareWarning,
        [switch]$NoLiveInstall,
        [switch]$NoSigCheck,
        [switch]$OkToRemove,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ImageProfile,
        [string]$Proxy = $null
    )

    Write-Host "Validating inputs"

    #Validation - Check if depot is remote or local
    $ext = $Depot.Substring($Depot.Length - 3)
    if ($ext -eq "zip") {

        #Check if the LocalDepot file exists
        if ($null -ne $LocalDepot) {
            #Split the path so we can extract the datastore name
            $splitpath = $LocalDepot -Split '/'
            $ds = Get-Datastore -Name $splitpath[3] -ErrorAction Ignore

            if ($null -eq $ds) {
                throw [System.Exception] "Local Depot not found. Cannot locate datastore " + $ds
            }

            #Get the vmstore path for the datastore
            $dsPath = $ds.DatastoreBrowserPath

            #Build the vmstore path
            $depotPath = $dsPath
            for ($i = 4; $i -lt $splitpath.Count; $i++){
                $depotPath = $depotPath + "\\" + $splitpath[$i]
            }

            #Use the vmstore path to test if the depot file exists
            if (Test-Path $depotPath -ne 'True')
            {
                throw [System.IO.FileNotFoundException] "Local depot not found. " + $LocalDepot
            }
        }
    }else {
        if ($ext -eq "xml") {
            #Check if RemoteDepot is reachable
            if ($null -ne $RemoteDepot) {
                $statuscode = Invoke-WebRequest $RemoteDepot | Select-Object statuscode
                if ($statuscode -ne 200) {
                    throw [System.Exception] "Remote Depot is not reachable. " + $RemoteDepot
                }
            }
        }else{
            throw [System.Exception] "Depot must either point to the index.xml of an online depot or the .zip of an offline bundle."
        }
    }

    try {
        $VMHostESXCLI = Get-EsxCli -V2 -VMHost $VMHost -ErrorAction:Stop
    } catch {
        throw [System.Exception] "Failed to get the EsxCli session for the specified host"
    }

    #Validation - Check if the ImageProfile exists
    $profiles = $VMHostESXCLI.software.sources.profile.list.Invoke(@{'depot' = $Depot})
    if ($profiles.Name.Contains($ImageProfile) -ne "True")
    {
        throw [System.Exception] "Depot exists, but does not contain the specified Image Profile: " + $ImageProfile
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

    if ($NoHardwareWarning) {
        $arguments.Add('nohardwarewarning', $true)
    }

    if ($NoLiveInstall) {
        $arguments.Add('noliveinstall', $true)
    }

    if ($NoSigCheck) {
        $arguments.Add('nosigcheck', $true)
    }

    if ($OkToRemove) {
        $arguments.Add('oktoremove', $true)
    }

    if ($null -ne $Proxy) {
        $arguments.Add('proxy', $Proxy)
    }

    try {
        $output = $VMHostESXCLI.software.profile.install.Invoke($arguments)
    } catch {
        Write-Error "Install failed with the following message:"
        Write-Error $_
        exit 1
    }

    if ($Dryrun) {
        Write-Host "Dry run completed successfully."
        return $output
    }

    if ($output.VIBsInstalled.count -eq 0 -and $output.VIBsRemoved.count -eq 0) {
        Write-Host "The installer did not make any changes. Check if you already installed this Profile"
        return $output
    }

    if ($output.VIBsInstalled.count -ne 0 -or $output.VIBsRemoved.count -ne 0 -and $NoLiveInstall -eq $true) {
        Hrite-Host "The installer has successfully applied the profile to altbootbank. A reboot is required to activate the new profile."
        return $output
    }

    if ($output.VIBsInstalled.count -ne 0 -or $output.VIBsRemoved.count -ne 0 -and $output.RebootRequired -eq $true) {
        Hrite-Host "The installer has successfully applied the profile. A reboot is required to complete installation."
        return $output
    }
}
