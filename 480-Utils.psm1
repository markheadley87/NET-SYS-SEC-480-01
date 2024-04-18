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
