<#
.Synopsis
    Install a new Image Profile to the specified ESXi host from a local datastore
.Description
    This command is the PowerCLI equivalent of executing the shell command: esxcli software profile install
    You can specify either a Local or a Remote Depot, but an error will be thrown if you select both.
    If selecting a Local Depot, use the absolute path from root and use the Datastore name, not it's GUID.
#>
function Install-ESXiProfile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [VMware.VimAutomation.ViCore.Impl.V1.EsxCli.EsxCliElementImpl]$VMHostESXCLI,
        [string]$LocalDepot = $null,
        [string]$RemoteDepot = $null,
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

    #Make sure both Local and Remote Depots are not specified
    if ($null -ne $RemoteDepot -and $null -ne $LocalDepot) {
        throw [System.Exception] "Cannot specify both Local and Remote Depot."
    }

    #Check if the LocalDepot file exists
    if ($null -ne $LocalDepot) {
        #Split the path so we can extract the datastore name
        $splitpath = $LocalDepot -Split '/'
        $ds = Get-Datastore -Name $splitpath[3]

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

        #Pass along the depot to the rest of the script
        $Depot = $LocalDepot
    }

    #Check if RemoteDepot is reachable
    if ($null -ne $RemoteDepot) {
        $statuscode = Invoke-WebRequest $RemoteDepot | Select-Object statuscode
        if ($statuscode -ne 200) {
            throw [System.Exception] "Remote Depot is not reachable. " + $RemoteDepot
        }

        #Pass along the depot to the rest of the script
        $Depot = $RemoteDepot
    }

    #Check if the ImageProfile exists
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
