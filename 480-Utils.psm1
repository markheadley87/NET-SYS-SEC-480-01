# This script is created by Mark
# This script is a utility script for SYS480

function 480banner()
{
    Write-Host "Mark SYS480"
}

Function 480Connect([string] $server)
{

    $conn = $global:DefaultVIServer
    # Are we connected already?

    if($conn){

        $msg = "Already Connected to {0}" -f $conn

        Write-Host -ForeGroundColor Green $msg

    }
    else{

        $conn = Connect-VIServer -Server $server
        # Connect to the server selected
    }

}

Function Get-480Config([string] $config_path)
{
    Write-Host "Reading " $config_path
    $conf=$null
    if(Test-Path $config_path){

        $conf = (Get-Content -Raw -Path $config_path | ConvertFrom-Json)
        $msg = "Using config at {0}" -f $config_path
        Write-Host -ForegroundColor "Green" $msg
    
    }
    else{

        Write-Host -ForegroundColor "Yellow" "No Config"
    }
    return $conf

}

Function Select-VM([string] $folder) 
{
  $selected_vm = $null
  try
  {
    $vms = Get-VM -Location $folder
    $index = 1
    foreach($vm in $vms)
    {
        Write-Host [$index] $vm.Name
        $index+=1

    }
    $pick_index = Read-Host "Which index number [x] do you wish to select?"
    # 480-Todo: Deal with an invalid index
    $selected_vm = $vms[$pick_index - 1]
    Write-Host "You picked " $selected_vm.Name
    #Note this is a full vm object we can interact with
    return $selected_vm
}
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host "Invalid Folder: $folder" -ForegroundColor "Red"
    }

}

Function New-480LinkedClone {
    param (
        [string]$EsxiHost = "192.168.7.21",
        [string]$Datastore = "datastore1-super11"
    )

    try {
        # Prompting for the source VM selection first.
        Write-Host "Please select the source VM for cloning from the 'BASEVM' folder:"
        $sourceVM = Select-VM -folder "BASEVM"

        if (-not $sourceVM) {
            throw "No VM selected or VM selection is invalid."
        }
        
        # Prompting for the clone name after the source VM has been selected.
        $CloneName = Read-Host 'Enter clone name'

        $SourceVMName = $sourceVM.Name
        $snapshotName = "Base"
        # Check for the existence of a 'Base' snapshot on the source VM.
        $snapshot = Get-Snapshot -VM $sourceVM -Name $snapshotName -ErrorAction SilentlyContinue
        if (-not $snapshot) {
            Write-Host "Snapshot named 'Base' not found for VM $SourceVMName."
            $createSnap = Read-Host "Would you like to create a 'Base' snapshot now? (Y/N)"
            if ($createSnap -eq 'Y') {
                Write-Host "Creating 'Base' snapshot for VM $SourceVMName..."
                $snapshot = New-Snapshot -VM $sourceVM -Name "Base"
                Write-Host "Snapshot 'Base' created."
            } else {
                throw "Unable to proceed without a 'Base' snapshot."
            }
        }

        # Clone specification including datastore and host details, linked clone flag, and snapshot.
        $cloneParams = @{
            Name = $CloneName
            VM = $sourceVM
            LinkedClone = $true
            ReferenceSnapshot = $snapshot
            Location = (Get-Folder -Name "BASEVM") # Specify the correct folder here
            Datastore = (Get-Datastore -Name $Datastore)
            VMHost = (Get-VMHost -Name $EsxiHost) # Correct usage of VMHost parameter
        }
                
        # Performing the actual cloning operation to create a linked clone.
        $linkedClone = New-VM @cloneParams

        Write-Host "Linked clone $CloneName created successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create linked clone: $_" -ForegroundColor Red
    }
}


Function New-480FullClone {
    param (
        [string]$EsxiHost = "192.168.7.21",
        [string]$Datastore = "datastore1-super11"
    )

    try {
        Write-Host "Please select the source VM for cloning from the 'BASEVM' folder:"
        $sourceVM = Select-VM -folder "BASEVM"

        if (-not $sourceVM) {
            throw "No VM selected or VM selection is invalid."
        }
        
        $CloneName = Read-Host 'Enter full clone name'
        $NetworkName = Read-Host 'Enter the network name for the full clone'

        # Ensure the 'Base' snapshot exists.
        $snapshotName = "Base"
        $snapshot = Get-Snapshot -VM $sourceVM -Name $snapshotName -ErrorAction SilentlyContinue
        if (-not $snapshot) {
            Write-Host "Snapshot named 'Base' not found for VM $sourceVM.Name."
            $createSnap = Read-Host "Would you like to create a 'Base' snapshot now? (Y/N)"
            if ($createSnap -eq 'Y') {
                Write-Host "Creating 'Base' snapshot for VM $sourceVM.Name..."
                $snapshot = New-Snapshot -VM $sourceVM -Name "Base"
                Write-Host "Snapshot 'Base' created."
            } else {
                throw "Unable to proceed without a 'Base' snapshot."
            }
        }

        # Clone the VM to create a full clone.
        $cloneVM = New-VM -Name $CloneName -VM $sourceVM -VMHost $EsxiHost -Datastore $Datastore -DiskStorageFormat Thin -Location (Get-Folder -Name "BASEVM")
        
        # Configure the network adapter to the specified network after VM creation.
        Get-NetworkAdapter -VM $cloneVM | Set-NetworkAdapter -NetworkName $NetworkName -Confirm:$false

        Write-Host "Full clone $CloneName created successfully and connected to network $NetworkName." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create full clone: $_" -ForegroundColor Red
    }
}

Function New-Network {
    # Prompt user for inputs
    $VirtualSwitchName = Read-Host "Enter the name for the new Virtual Switch"
    $PortGroupName = Read-Host "Enter the name for the new Port Group"
    $vHost = Read-Host "Enter the name of the ESXi host"

    $esxiHost = Get-VMHost -Name $vHost

    # Create the Virtual Switch if it does not exist
    $vSwitch = Get-VirtualSwitch -VMHost $esxiHost -Name $VirtualSwitchName -ErrorAction SilentlyContinue
    if (-not $vSwitch) {
        Write-Host "Creating new Virtual Switch named $VirtualSwitchName..."
        $vSwitch = New-VirtualSwitch -VMHost $esxiHost -Name $VirtualSwitchName
    }

    # Create the Port Group if it does not exist
    $portGroup = Get-VirtualPortGroup -VirtualSwitch $vSwitch -Name $PortGroupName -ErrorAction SilentlyContinue
    if (-not $portGroup) {
        Write-Host "Creating new Port Group named $PortGroupName..."
        New-VirtualPortGroup -VirtualSwitch $vSwitch -Name $PortGroupName
    }
}



Function Get-IP {
    # Prompt user for VM name
    $VMName = Read-Host "Enter the name of the VM"

    $vm = Get-VM -Name $VMName

    if (-not $vm) {
        Write-Host "VM with name $VMName was not found."
        return
    }

    # Get the first network adapter of the VM
    $netAdapter = Get-NetworkAdapter -VM $vm | Select -First 1

    if (-not $netAdapter) {
        Write-Host "No network adapter found for VM $VMName."
        return
    }

    # Assuming the VM might have multiple IP addresses, take the first one
    $ipAddress = $vm.Guest.IpAddress[0]
    $macAddress = $netAdapter.MacAddress
    $vmName = $vm.Name

    # Output the results
    Write-Host "VM Name: $vmName"
    Write-Host "IP Address: $ipAddress"
    Write-Host "MAC Address: $macAddress"
}

Function Invoke-480StartVM {
    # No parameters defined; VM names will be gathered via user input.
    try {
        $VMNames = Read-Host "Enter the names of the VMs to start (separate multiple names with commas)"
        $VMNameArray = $VMNames -split ',' | ForEach-Object { $_.Trim() }

        foreach ($Name in $VMNameArray) {
            $VM = Get-VM -Name $Name -ErrorAction SilentlyContinue
            if ($VM) {
                Start-VM -VM $VM -Confirm:$false
                Write-Host "VM '$Name' has been started." -ForegroundColor Green
            } else {
                Write-Host "VM '$Name' not found." -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

Function Invoke-480StopVM {
    # No parameters for VM names; gathers names via user input.
    try {
        $VMNames = Read-Host "Enter the names of the VMs to stop (separate multiple names with commas)"
        $VMNameArray = $VMNames -split ',' | ForEach-Object { $_.Trim() }
        $Force = $false

        # Optional: Ask the user if they want to force the VMs to stop.
        $forceInput = Read-Host "Do you want to force stop the VMs? (Y/N)"
        if ($forceInput -eq "Y") {
            $Force = $true
        }

        foreach ($Name in $VMNameArray) {
            $VM = Get-VM -Name $Name -ErrorAction SilentlyContinue
            if ($VM) {
                if ($Force) {
                    Stop-VM -VM $VM -Confirm:$false -Kill
                    Write-Host "VM '$Name' has been forcefully stopped." -ForegroundColor Yellow
                } else {
                    Stop-VM -VM $VM -Confirm:$false
                    Write-Host "VM '$Name' has been stopped." -ForegroundColor Green
                }
            } else {
                Write-Host "VM '$Name' not found." -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

Function Set-Network {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        
        [Parameter(Mandatory = $true)]
        [string]$NetworkName,
        
        [Parameter(Mandatory = $false)]
        [int[]]$AdapterIndices = @(1)
    )
    
    # Ensure you are connected to a vCenter or ESXi host.
    if (-not (Get-PowerCLIConfiguration).DefaultVIServerMode) {
        Write-Host "Please connect to a vCenter or ESXi host using Connect-VIServer." -ForegroundColor Red
        return
    }
    
    try {
        # Retrieve the specified VM.
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        
        # Retrieve all network adapters of the VM.
        $networkAdapters = Get-NetworkAdapter -VM $vm
        
        # Loop through each specified adapter index.
        foreach ($index in $AdapterIndices) {
            # Retrieve the specific network adapter by index.
            $adapter = $networkAdapters | Where-Object {$_.Name -eq "Network adapter $index"}
            
            if ($adapter) {
                # Set the network adapter to the specified network.
                Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName $NetworkName -Confirm:$false
                Write-Host "Set $($adapter.Name) on VM '$VMName' to network '$NetworkName'." -ForegroundColor Green
            }
            else {
                Write-Host "Network adapter with index $index not found on VM '$VMName'." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

Function Set-WindowsIP {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,  # Now expects a VM name as a string

        [Parameter(Mandatory = $true)]
        [string]$IpAddress,

        [Parameter(Mandatory = $true)]
        [string]$SubnetMask,

        [Parameter(Mandatory = $true)]
        [string]$DefaultGateway,

        [Parameter(Mandatory = $true)]
        [string]$PrimaryDNS,

        [Parameter(Mandatory = $false)]
        [string]$SecondaryDNS,

        [string]$InterfaceName = "Ethernet0"
    )

    # Retrieve the VM object based on the VM name
    $VM = Get-VM -Name $VMName
    if (-not $VM) {
        Write-Host "VM with name $VMName not found." -ForegroundColor Red
        return
    }

    # Prompt for guest username and password securely
    $GuestUser = Read-Host "Enter the guest username"
    $GuestPassword = Read-Host "Enter the guest password" -AsSecureString
    $Credential = New-Object System.Management.Automation.PSCredential ($GuestUser, $GuestPassword)

    # Build the network configuration script
    $ScriptText = "netsh interface ip set address name=`"$InterfaceName`" static $IpAddress $SubnetMask $DefaultGateway 1`n"
    $ScriptText += "netsh interface ip set dnsservers `"$InterfaceName`" static $PrimaryDNS`n"
    if ($SecondaryDNS) {
        $ScriptText += "netsh interface ip add dnsservers `"$InterfaceName`" $SecondaryDNS index=2`n"
    }

    # Execute the script inside the VM using the provided credentials
    $ScriptOutput = Invoke-VMScript -VM $VM -ScriptText $ScriptText -GuestUser $Credential.UserName -GuestPassword $Credential.GetNetworkCredential().Password -ScriptType "Powershell"

    # Output results
    if ($ScriptOutput.ScriptOutput) {
        Write-Host "IP configuration successful:" -ForegroundColor Green
        Write-Host $ScriptOutput.ScriptOutput
    } else {
        Write-Host "Failed to configure IP settings" -ForegroundColor Red
    }

}
