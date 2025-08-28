# ===============================================
# FLEET-WIDE MANAGEMENT DEMONSTRATION
# ===============================================
# Fusion enables management across all arrays in the fleet from a single connection
# This eliminates the need to connect to each array individually



# List existing snapshots for the protection group
# Snapshots are created automatically based on the schedule defined in the preset
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Filter "name='$($PGName.Name)*'"


# Get all fleet members, excluding non-FlashArray systems
# The FlashBlade (sn1-s200-c09-33) is excluded as it uses different object types
$FleetMembers = Get-Pfa2FleetMember -Array $FlashArray -Filter "Member.Name!='sn1-s200-c09-33'"
$FleetMembers.Member.Name


# List all arrays in the fleet
Get-Pfa2Array -Array $FlashArray -ContextNames $FleetMembers.Member.Name | Format-List


# Search the entire fleet for protection group snapshots
# The ContextNames parameter enables fleet-wide queries
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Filter "name='$($PGName.Name)*'" -Limit 10 | 
    Format-Table -AutoSize

# ===============================================
# INDIVIDUAL ARRAY QUERIES (FOR COMPARISON)
# ===============================================
# These commands show how to query specific arrays in the fleet
# Useful when you need to isolate operations to a single array

# Query snapshots on the C60 array (typically used for dev/test)
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[0].Member.Name)" -Limit 10


# Query snapshots on the primary X90 array
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[1].Member.Name)" -Limit 10


# Query snapshots on the secondary X90 array
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[2].Member.Name)" -Limit 10


# ===============================================
# BULK WORKLOAD DEPLOYMENT
# ===============================================
# Deploy multiple SQL Server instances using the same preset
# This ensures consistency across all deployments

$SQLInstances = @("Production-SQL-02", "DR-SQL-01", "Test-SQL-01", "Dev-SQL-01")

foreach ($instance in $SQLInstances) {
    $workloadParams = @{
        Array       = $FlashArray
        Name        = $instance
        PresetNames = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
    }
    
    New-Pfa2Workload @workloadParams
    Write-Output "Created workload for $instance"
}

# List all workloads across the fleet that use our SQL Server preset
Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Format-Table -AutoSize

# ===============================================
# CROSS-ARRAY WORKLOAD DEPLOYMENT
# ===============================================
# Deploy a workload on a different array (if connected)
# This demonstrates Fusion's ability to manage workloads regardless of which array you're connected to
# The scope of the preset is the whole fleet

$workloadParams2 = @{
    Array        = $FlashArray
    ContextNames = ($FleetMembers.Member.Name) | Where-Object { $_ -eq 'sn1-x90r2-f06-33' }
    Name         = "Production-SQL-03"
    PresetNames  = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}

New-Pfa2Workload @workloadParams2

# Create another workload with the same name in a different context
$workloadParams3 = @{
    Array        = $FlashArray
    ContextNames = ($FleetMembers.Member.Name) | Where-Object { $_ -eq 'sn1-x90r2-f06-27' }
    Name         = "Production-SQL-03"
    PresetNames  = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}

New-Pfa2Workload @workloadParams3


# Get all workloads using the SQL Server preset
Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Sort-Object -Property Name | Format-Table -AutoSize

# ===============================================
# CLEANUP OPERATIONS
# ===============================================
# Remove test workloads and presets
# WARNING: This will delete all volumes and data associated with these workloads

# Remove individual workloads
$ContextName = (Get-Pfa2Workload -Array $FlashArray -Name "Production-SQL-01" -ContextNames $FleetMembers.Member.Name).Context.Name
Write-output "Context for Production-SQL-01 is $ContextName"

Remove-Pfa2Workload -Array $FlashArray -Name "Production-SQL-01" -ContextNames $ContextName


# Verify workload destruction status
Get-Pfa2Workload -Array $PrimaryArray -Destroyed $true | 
    Where-Object { $_.Name -eq "Production-SQL-01" } | 
    Format-List Name, Destroyed, TimeRemaining


# Force immediate eradication of the destroyed workload
Remove-Pfa2Workload -Array $FlashArray -Name "Production-SQL-01"  -ContextNames $ContextName -Eradicate


# Remove workloads
$SQLInstances = @("Production-SQL-02", "DR-SQL-01", "Test-SQL-01", "Dev-SQL-01")

foreach ($instance in $SQLInstances) {
    $ContextName = (Get-Pfa2Workload -Array $FlashArray -Name $instance -ContextNames $FleetMembers.Member.Name).Context.Name
    Write-output "Context for $instance is $ContextName"

    $workloadParams = @{
        Array       = $FlashArray
        Name        = $instance
        ContextName = $ContextName
    }

    Remove-Pfa2Workload -Array $FlashArray -Name $instance -ContextNames $ContextName
    Write-Output "Removed workload for $instance"
    
    Remove-Pfa2Workload -Array $FlashArray -Name $instance -Eradicate -Confirm:$false
    Write-Output "Eradicated workload for $instance"
}


# Remove the preset which you can do even with a workload deployed 
Remove-Pfa2PresetWorkload -Array $FlashArray -ContextNames 'fsa-lab-fleet1' -Name "SQL-Server-MultiDisk-Optimized" 


# Remove our last workload
Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Sort-Object -Property Name | Format-Table -AutoSize

Remove-Pfa2Workload -Array $FlashArray -ContextNames 'sn1-x90r2-f06-27' -Name "Production-SQL-03" 
Remove-Pfa2Workload -Array $FlashArray -ContextNames 'sn1-x90r2-f06-27' -Name "Production-SQL-03" -Eradicate -Confirm:$false

Remove-Pfa2Workload -Array $FlashArray -ContextNames 'sn1-x90r2-f06-33' -Name "Production-SQL-03" 
Remove-Pfa2Workload -Array $FlashArray -ContextNames 'sn1-x90r2-f06-33' -Name "Production-SQL-03" -Eradicate -Confirm:$false
