<#
.Synopsis
    Install a new Image Profile to the specified ESXi host
.Description
    This command is the PowerCLI equivalent of executing the shell command: esxcli software vib install
#>
function Install-ESXiProfile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [VMware.VimAutomation.ViCore.Impl.V1.EsxCli.EsxCliElementImpl]$VMHostESXCLI,
        [Parameter(Mandatory)]
        [string]$Datastore,
        [Parameter(Mandatory)]
        [string]$RelativePath,
        [Parameter(Mandatory)]
        [string]$Depot,
        [switch]$Dryrun,
        [switch]$Force,
        [switch]$MaintenanceMode,
        [switch]$NoLiveInstall,
        [switch]$NoSigCheck,
        [switch]$OkToRemove,
        [Parameter(Mandatory)]
        [string]$ImageProfile,
        [switch]$NoHardwareWarning,
        [string]$Proxy = $null
    )

    #Check if the Depot file exists
    $ds = Get-Datastore -Name $Datastore
    $dsPath = $ds.DatastoreBrowserPath
    $depotPath = $dsPath + $RelativePath + $Depot
    if (Test-Path $depotPath -ne 'True')
    {
        throw [System.IO.FileNotFoundException] "Depot not found. Datastore: " + $Datastore + " | Depot: " + $RelativePath + $Depot
    }

    #Check if the ImageProfile exists
    $absPath = "/vmfs/volumes/" + $Datastore + $RelativePath + $Depot
    $profiles = $VMHostESXCLI.software.sources.profile.list.Invoke(@{'depot' = $absPath})
    if ($profiles.Name.Contains($ImageProfile) -ne "True")
    {
        throw [System.Exception] "Depot exists, but does not contain the specified Image Profile: " + $ImageProfile
    }

    #Prepare Arguments
    $arguments = @{}

    $arguments.Add('depot', $absPath)
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

    if ($OkToRemove) {
        $arguments.Add('oktoremove', $true)
    }

    if ($NoHardwareWarning) {
        $arguments.Add('nohardwarewarning', $true)
    }

    if ($null -ne $Proxy) {
        $arguments.Add('proxy', $Proxy)
    }


    $VMHostESXCLI.software.profile.install.Invoke($arguments)
}
