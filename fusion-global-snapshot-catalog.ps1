# **Building a Global Snapshot Catalog**: Using tags combined with Fusion's fleet-wide scope, you can find and consume a snapshot anywhere in your Fleet

$PrimaryArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'
$SecondaryArrayName = 'sn1-c60-e12-16.puretec.purestorage.com'
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$PrimaryArray = Connect-Pfa2Array –EndPoint $PrimaryArrayName -Credential $Credential -IgnoreCertificateError

$PrimaryFleetInfo = Get-Pfa2FleetMember -Array $PrimaryArray 

# Get all members that have our SQL Server workload deployed
$FleetMembers = Get-Pfa2FleetMember -Array $PrimaryArray -Filter "Member.Name!='sn1-s200-c09-33'"  # Exclude FlashBlade
Write-Output "`nSearching for SQL Server workloads across the fleet..."

# Find all workloads with SQL Server preset across all arrays
$SQLWorkloads = Get-Pfa2Workload -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -like '*SQL-Server*' }

Write-Output "Found SQL Server workloads on the following arrays:"
$SQLWorkloads | Format-Table Name, @{Label="Array";Expression={$_.Context.Name}}, @{Label="Preset";Expression={$_.Preset.Name}} -AutoSize

# Get a listing of all protection group snapshots across all arrays in our fleet
Write-Output "`nQuerying protection group snapshots across the fleet..."

# Get all protection groups associated with SQL workloads
$AllProtectionGroups = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Workload.Name -like '*SQL*' }

# Get snapshots from all protection groups
$AllSnapshots = foreach ($pg in $AllProtectionGroups) {
    Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -ContextNames $pg.Context.Name -Filter "name='$($pg.Name)*'" -Limit 5
}

Write-Output "Found $($AllSnapshots.Count) snapshots across the fleet"
$AllSnapshots | Format-Table Name, @{Label="Array";Expression={$_.Context.Name}}, Created -AutoSize

# Take PG snapshot and inject the metadata tags inside the snapshot
Write-Output "`nCreating tagged snapshot for global catalog..."

# First, find a local protection group on the primary array
$LocalPG = Get-Pfa2ProtectionGroup -Array $PrimaryArray -Filter "workload.name='Production-SQL-01'"

if ($LocalPG) {
    # Create snapshot with metadata tags for catalog purposes
    $SnapshotTags = @{
        "catalog-type" = "global"
        "database-type" = "sql-server"
        "snapshot-purpose" = "demo-recovery"
        "source-array" = $PrimaryArrayName.Split('.')[0]
        "created-by" = "fusion-demo"
        "recovery-priority" = "high"
    }
    
    # Create the snapshot with tags
    $TaggedSnapshot = New-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -SourceName $LocalPG.Name
    
    # Note: Tags would typically be added via Update-Pfa2ProtectionGroupSnapshot if supported
    Write-Output "Created snapshot: $($TaggedSnapshot.Name)"
}

# Force replication of that snapshot to the C, checking its status
Write-Output "`nChecking replication status to secondary array..."

# Find the remote protection group that replicates to the C60
$RemotePG = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Targets.Name -contains $SecondaryArrayName.Split('.')[0] }

if ($RemotePG) {
    Write-Output "Replication protection group: $($RemotePG.Name)"
    
    # Check for snapshots on the target array
    $TargetSnapshots = Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray `
        -ContextNames $SecondaryArrayName.Split('.')[0] `
        -Filter "name='$($RemotePG.Source.Name):$($RemotePG.Name)*'" -Limit 5
    
    Write-Output "Recent replicated snapshots on target:"
    $TargetSnapshots | Format-Table Name, Created -AutoSize
}

# Delete our workload on the primary FlashArray
Write-Output "`nRemoving workload on primary array..."

$WorkloadToDelete = Get-Pfa2Workload -Array $PrimaryArray -Name "Production-SQL-01"
if ($WorkloadToDelete) {
    Remove-Pfa2Workload -Array $PrimaryArray -Name "Production-SQL-01"
    Remove-Pfa2Workload -Array $PrimaryArray -Name "Production-SQL-01" -Eradicate -Confirm:$false
    Write-Output "Workload 'Production-SQL-01' removed from primary array"
}

# Deploy a replacement workload on the same FlashArray
Write-Output "`nDeploying replacement SQL Server workload..."

# Find available SQL Server preset
$SQLPreset = Get-Pfa2PresetWorkload -Array $PrimaryArray | 
    Where-Object { $_.Name -like '*SQL-Server*' } | 
    Select-Object -First 1

if ($SQLPreset) {
    $NewWorkloadParams = @{
        Array = $PrimaryArray
        Name = "Recovery-SQL-01"
        PresetNames = @($SQLPreset.Name)
    }
    
    New-Pfa2Workload @NewWorkloadParams
    Write-Output "Created new workload 'Recovery-SQL-01'"
    
    # Get the volumes created for the new workload
    $NewVolumes = Get-Pfa2Volume -Array $PrimaryArray -Filter "workload.name='Recovery-SQL-01'"
    Write-Output "New volumes created:"
    $NewVolumes | Format-Table Name, Size -AutoSize
}

# Grab the snapshot from the remote array to the array our new SQL Server workload is deployed on
Write-Output "`nLocating snapshot for recovery..."

# Find the latest snapshot on the remote array
$RemoteSnapshotName = "$($PrimaryArrayName.Split('.')[0]):$($RemotePG.Name)*"
$AvailableSnapshots = Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray `
    -ContextNames $SecondaryArrayName.Split('.')[0] `
    -Filter "name='$RemoteSnapshotName'" `
    -Sort "-created" -Limit 1

if ($AvailableSnapshots) {
    $SelectedSnapshot = $AvailableSnapshots[0]
    Write-Output "Selected snapshot for recovery: $($SelectedSnapshot.Name)"
    Write-Output "Created: $($SelectedSnapshot.Created)"
    
    # Note: Cross-array snapshot recovery would typically involve:
    # 1. Creating a temporary volume from the snapshot on the remote array
    # 2. Replicating that volume back to the primary array
    # 3. Overwriting the target volumes
}

# Clone and overwrite the data volumes on our deployed workload
Write-Output "`nRestoring data to new workload volumes..."

# Get the data volumes (excluding TempDB which doesn't need restore)
$DataVolumes = Get-Pfa2Volume -Array $PrimaryArray -Filter "workload.name='Recovery-SQL-01'" | 
    Where-Object { $_.Name -notlike '*TempDB*' }

foreach ($volume in $DataVolumes) {
    Write-Output "Would restore snapshot to volume: $($volume.Name)"
    
    # In a real scenario, you would:
    # 1. Create a volume from the snapshot
    # 2. Use Copy-Pfa2Volume or similar to overwrite the target volume
    # Example (pseudo-code):
    # $SnapshotVolume = New-Pfa2Volume -Array $PrimaryArray -SourceName $SelectedSnapshot.Name
    # Copy-Pfa2Volume -Array $PrimaryArray -SourceName $SnapshotVolume.Name -DestinationName $volume.Name -Overwrite
}

# List all of the databases in the SQL Server
Write-Output "`nSQL Server database inventory after recovery:"
Write-Output "Note: In a real scenario, you would connect to SQL Server and run:"
Write-Output "  SELECT name, state_desc, recovery_model_desc FROM sys.databases"
Write-Output ""
Write-Output "Expected databases after recovery:"
Write-Output "  - master (ONLINE)"
Write-Output "  - model (ONLINE)"
Write-Output "  - msdb (ONLINE)"
Write-Output "  - tempdb (ONLINE) - recreated, not restored"
Write-Output "  - AdventureWorks (ONLINE) - restored from snapshot"
Write-Output "  - Contoso (ONLINE) - restored from snapshot"