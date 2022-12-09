#Set-PSDebug -Trace 1

function  GenerateForm {
    Set-Variable -Name Form, SubscriptionDropDown, ResourceGroupDropDown, StorageAccountDropDown, ContainerDropDown -Option AllScope
    Set-Variable -Name Subscription, Subscriptions, ResourceGroup, StorageAccount, Context, Container, Folder, VHDFiles -Option AllScope

    function PrepareElements {
        $Subscriptions = Get-AzSubscription
        if ($Subscriptions.Count -eq 0) {
            throw "No Azure subscriptions found"
            exit 1
        }
        else {
            Write-Host "Buiding the GUI"
            $Form = New-Object System.Windows.Forms.Form
            $Form.Text = "Upload VHD disk images to Azure"
            $Form.Size = New-Object System.Drawing.Size(400, 400)
            $Form.StartPosition = 'CenterScreen'
            $Form.FormBorderStyle = 'FixedDialog'
            $Form.MaximizeBox = $false
            $Form.MinimizeBox = $false
            $Form.AcceptButton = $Button
            $Form.CancelButton = $Button
            $Form.TopMost = $true
            $Form.ShowInTaskbar = $false
            $Form.AutoSize = $true
        }
        RenderSubsriptionSelectBox | Out-Null
        $Form.ShowDialog()
    }

    function RenderSubsriptionSelectBox {
        # Add a drop-down list to select the Azure subscription
        $SubscriptionDropDown = New-Object System.Windows.Forms.ComboBox
        $SubscriptionDropDown.Location = New-Object System.Drawing.Size(50, 50)
        $SubscriptionDropDown.Size = New-Object System.Drawing.Size(280, 35)
        $SubscriptionDropDown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

        # Populate the drop-down list with available Azure subscriptions
        if ($Subscriptions.Count -eq 1) {
            $SubscriptionDropDown.Items.Add($Subscriptions.Name)
            $SubscriptionDropDown.SelectedIndex = 0
            $Subscription = $Subscriptions.Name
            $Subscriptions | Set-AzContext
            Write-Host "Selected subscription: $Subscription"
            
            RenderResourceGroupSelectBox | Out-Null
            
        }
        else {
            $Subscriptions | ForEach-Object {
                $SubscriptionDropDown.Items.Add($_.Name)
            }
        }

        $SubscriptionDropDown.Add_SelectedIndexChanged({
                $Subscription = $SubscriptionDropDown.SelectedItem
                $Subscriptions | Where-Object name -eq $Subscription | Set-AzContext
                Write-Host "Selected subscription: $Subscription"
            
                RenderResourceGroupSelectBox | Out-Null
            
            })

        $Form.Controls.Add($SubscriptionDropDown)

        # Add a label to show the selected subscription
        $SubscriptionLabel = New-Object System.Windows.Forms.Label
        $SubscriptionLabel.Location = New-Object System.Drawing.Size(50, 25)
        $SubscriptionLabel.Size = New-Object System.Drawing.Size(280, 35)
        $SubscriptionLabel.Text = "Selected subscription: "
        $Form.Controls.Add($SubscriptionLabel)
    }

    function RenderResourceGroupSelectBox {
        # Add a drop-down list to select the Azure resource group
        $ResourceGroupDropDown = New-Object System.Windows.Forms.ComboBox
        $ResourceGroupDropDown.Location = New-Object System.Drawing.Size(50, 100)
        $ResourceGroupDropDown.Size = New-Object System.Drawing.Size(280, 35)
        $ResourceGroupDropDown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $ResourceGroups = Get-AzResourceGroup

        if ($ResourceGroups.Count -eq 0) {
            throw "No Azure resource groups found. Please create one first."
            $Form.Close()
        }
        elseif ($ResourceGroups.Count -eq 1) {
            $ResourceGroupDropDown.Items.Add($ResourceGroups.ResourceGroupName)
            $ResourceGroupDropDown.SelectedIndex = 0
            $ResourceGroup = $ResourceGroups.ResourceGroupName
            Write-Host "Selected resource group: $ResourceGroup"
            
            RenderStorageAccountSelectBox | Out-Null
            
        }
        else {
            $ResourceGroups | ForEach-Object {
                $ResourceGroupDropDown.Items.Add($_.ResourceGroupName)
            }
        }

        $ResourceGroupDropDown.Add_SelectedIndexChanged({
                $ResourceGroup = $ResourceGroupDropDown.SelectedItem
                Write-Host "Selected resource group: $ResourceGroup"
            
                RenderStorageAccountSelectBox | Out-Null
            
            })

        $Form.Controls.Add($ResourceGroupDropDown)

        # Add a label to show the selected resource group
        $ResourceGroupLabel = New-Object System.Windows.Forms.Label
        $ResourceGroupLabel.Location = New-Object System.Drawing.Size(50, 75)
        $ResourceGroupLabel.Size = New-Object System.Drawing.Size(280, 35)
        $ResourceGroupLabel.Text = "Select resource group"
        $Form.Controls.Add($ResourceGroupLabel)
    }

    function RenderStorageAccountSelectBox {
        # Add a drop-down list to select the Azure storage account
        $StorageAccountDropDown = New-Object System.Windows.Forms.ComboBox
        $StorageAccountDropDown.Location = New-Object System.Drawing.Size(50, 150)
        $StorageAccountDropDown.Size = New-Object System.Drawing.Size(280, 35)
        $StorageAccountDropDown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

        # Populate the drop-down list with available Azure storage accounts
        $StorageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroup
        if ($StorageAccounts.Count -eq 0) {
            throw "No Azure storage accounts found. Please create one first or change the resource group."
            return

        }
        elseif ($StorageAccounts.Count -eq 1) {
            $StorageAccountDropDown.Items.Add($StorageAccounts.('StorageAccountName'))
            $StorageAccountDropDown.SelectedIndex = 0
            $StorageAccount = $StorageAccounts.('StorageAccountName')
            Write-Host "Selected storage account: $StorageAccount"
            
            RenderContainerSelectBox | Out-Null
            
        }
        else {
            $StorageAccounts.('StorageAccountName') | ForEach-Object {
                $StorageAccountDropDown.Items.Add($_)
            }
        }

        $StorageAccountDropDown.Add_SelectedIndexChanged({
                $StorageAccount = $StorageAccountDropDown.SelectedItem
                Write-Host "Selected storage account: $StorageAccount"
            
                RenderContainerSelectBox | Out-Null
            
            })

        $Form.Controls.Add($StorageAccountDropDown)

        # Add a label to show the selected storage account
        $StorageAccountLabel = New-Object System.Windows.Forms.Label
        $StorageAccountLabel.Location = New-Object System.Drawing.Size(50, 125)
        $StorageAccountLabel.Size = New-Object System.Drawing.Size(280, 35)
        $StorageAccountLabel.Text = "Select storage account"
        $Form.Controls.Add($StorageAccountLabel)
    }

    function RenderContainerSelectBox {
        $key1 = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroup -Name $StorageAccount)[0].value
        $Context = New-AzStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $key1
        $ContainerDropDown = New-Object System.Windows.Forms.ComboBox
        $ContainerDropDown.Location = New-Object System.Drawing.Size(50, 200)
        $ContainerDropDown.Size = New-Object System.Drawing.Size(280, 35)
        $ContainerDropDown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $Containers = Get-AzStorageContainer -Context $Context
        if ($Containers.Count -eq 0) {
            throw "No Azure storage containers found"
        }
        elseif ($Containers.Count -eq 1) {
            $ContainerDropDown.Items.Add($Containers.Name)
            $ContainerDropDown.SelectedIndex = 0
            $Container = $Containers.Name
            Write-Host "Selected container: $Container"
         
            RenderSelectVHDFolderButton | Out-Null
         
        }
        else {
            $Containers | ForEach-Object {
                $ContainerDropDown.Items.Add($_.Name)
            }
        }


        $ContainerDropDown.Add_SelectedIndexChanged({
                $Container = $ContainerDropDown.SelectedItem
                Write-Host "Selected container: $Container"

                RenderSelectVHDFolderButton | Out-Null

            })

        $Form.Controls.Add($ContainerDropDown)
        $Form.Refresh();

        # Add a label to show the selected storage account
        $ContainerLabel = New-Object System.Windows.Forms.Label
        $ContainerLabel.Location = New-Object System.Drawing.Size(50, 175)
        $ContainerLabel.Size = New-Object System.Drawing.Size(280, 35)
        $ContainerLabel.Text = "Select container"
        $Form.Controls.Add($ContainerLabel)
        
    }

    function RenderSelectVHDFolderButton {
        # Add a button to select the VHD folder
        $SelectFolderButton = New-Object System.Windows.Forms.Button
        $SelectFolderButton.Location = New-Object System.Drawing.Size(50, 225)
        $SelectFolderButton.Size = New-Object System.Drawing.Size(280, 35)
        $SelectFolderButton.Text = "Select VHD folder"
        $SelectFolderButton.Add_Click({
                # Create a new folder browser dialog
                $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog

                # Set the initial folder to the Computer's root folder
                $FolderBrowserDialog.SelectedPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyComputer)

                # Show the folder browser dialog and get the selected folder
                $Result = $FolderBrowserDialog.ShowDialog()

                # If the user clicked OK and selected a folder,
                # get all VHD files in the selected folder
                if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
                    $Folder = $FolderBrowserDialog.SelectedPath
                    $VHDFiles = Get-ChildItem $Folder -Filter "*.vhd"
                    if ($VHDFiles.Count -eq 0) {
                        throw "No VHD files found in folder $Folder"
                        return
                    }
                    Write-Host "Selected folder: $Folder"
                    Write-Host "Found $($VHDFiles.Count) VHD files"
                    for ($i = 0; $i -lt $VHDFiles.Count; $i++) {
                        Write-Host "VHD file $($i+1): $($VHDFiles[$i])"
                    }
                }
                else {
                    return 
                }

                RenderConfirmUploadButton | Out-Null

            })
        $Form.Controls.Add($SelectFolderButton)
    }

    function RenderConfirmUploadButton {
        $UploadButton = New-Object System.Windows.Forms.Button
        $UploadButton.Location = New-Object System.Drawing.Size(50, 270)
        $UploadButton.Size = New-Object System.Drawing.Size(280, 35)
        $UploadButton.Text = "Upload VHD disk images to Azure"
        $UploadButton.Add_Click({
                # Upload the VHD disk images to the container
                $Form.Hide()
                Write-Host "WARNING: If the container '$Container' contains any blobs with the same name as the selected VHD files, they will be overwritten."
                $Confirmation = read-host "Press Enter to continue. Type 'q' and press Enter to quit"
                if (($Confirmation -eq "q") -or ($Confirmation -eq "Q")) {
                    $Form.Close()
                    return
                }

                $VHDFiles | ForEach-Object {
                    $file = $_.Name
                    $FilePath = Join-Path  $Folder  $file
                    Write-Host "Uploading $FilePath to container '$Container'"
                    if (Add-AzVhd -Destination "$($Context.BlobEndPoint)$Container/$file" -LocalFilePath "$FilePath" -ResourceGroupName $ResourceGroup -SkipResizing -AsJob -OverWrite | Wait-Job -Any | Receive-Job -WriteJobInResults -WriteEvents -Wait) {
                        Write-Host "$FilePath uploaded successfully"
                    }
                    else {
                        Write-Host "Failed to upload $FilePath"
                    }
                }
                read-host "Upload complete. Press Enter to exit"
                $Form.Close()
            })
        $Form.Controls.Add($UploadButton)
    }

    PrepareElements | Out-Null

}


# Main

if (Get-Module -ListAvailable -Name Az.Accounts) {
    Write-Host "Az module is present, skipping installation"

} 
else {
    Write-Host "Az module is not present, installing it, please wait..."
    Install-Module -Name Az -AllowClobber -force
    Write-Host "NOTE: Script may take a while to initialize. Please be patient."
    Import-Module Az
}

## Authenticate to Azure
"Connecting to Azure"
if (Connect-AzAccount) {
    Write-Host "Connected to Azure"
    GenerateForm | Out-Null
}
else {
    Write-Host "Failed to connect to Azure"
    exit 1
}
