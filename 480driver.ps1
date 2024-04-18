Import-Module '480-utils' -Force
# Call a banner to check
480banner
$conf = Get-480Config -config_path ./480.json
480Connect -server $conf.vcenter_server

# Display menu options to the user
Write-Host "Please select an option:"
Write-Host "1: Create a Linked Clone"
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
    "X" {
        # User chose to exit
        Write-Host "Exiting..."
    }
    default {
        # User made an invalid choice
        Write-Host "Invalid choice. Please enter 1, 2, 3, 4, or X to exit."
    }
}
