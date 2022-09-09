<#
.Synopsis
    Install a new Vib to the specified ESXi host from a local datastore
.Description
    This command is the PowerCLI equivalent of executing the shell command: esxcli software vib install
#>
function Install-ESXiVib {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [EsxCliImpl]$VMHostESXCLI,
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
            throw [System.Exception] "Depot must either point to the index.xml of an online depot or the zip of an offline bundle."
        }
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
