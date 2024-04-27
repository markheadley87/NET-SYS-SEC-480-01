Import-Module '480-utils' -Force
# Call a banner to check
480banner
$conf = Get-480Config -config_path ./480.json
480Connect -server $conf.vcenter_server

# Display menu options to the user
Write-Host "Please select an option:"
Write-Host "1: Create a Linked Clone"
Write-Host "2: Create a Full Clone"
Write-Host "3: Create Network"
Write-Host "4: Set Network"
Write-Host "5: Retrieve VM"
Write-Host "6: Start VM"
Write-Host "7: Stop VM"
# Write-Host "*: Placeholder"
Write-Host "X: Exit Program"

# Capture the user's choice
$choice = Read-Host "Please enter 1, 2, 3, 4, or X to exit."

# Process the user's choice
switch ($choice) {
    "1" {
        # User chose to create a Linked Clone
        Write-Host "Creating a Linked Clone..."
        New-480LinkedClone
    }
    "2" {
        # User chose to create a Full Clone
        Write-Host "Creating a Full Clone..."
        New-480FullClone
    }

    "3" {
        # User chose to create new network
        Write-Host "Creating a new Network..."
        New-Network
    }

    "4" {
        # User chose to create new network
        Write-Host "Setting a new Network..."
        Set-Network
    }


    "5" {
        # User chose to retrieve VM
        Write-Host "Retrieving VM..."
        Get-IP
    }

    "6" {
        # User chose to Start VM
        Write-Host "Starting VM..."
        Invoke-480StartVM
    }
    
    "7" {
        # User chose to Stop VM
        Write-Host "Stopping VM..."
        Invoke-480StopVM
    }

    "X" {
        # User chose to exit
        Write-Host "Exiting..."
    }
    default {
        # User made an invalid choice
        Write-Host "Invalid choice. Please enter 1, 2, 3, 4, or X to exit."
    }
}

