# ===============================================
# CONNECT TO PRIMARY ARRAY (FlashArray X)
# ===============================================
# The primary array serves as the source for replication
# FlashArray X is typically used for high-performance production workloads
# FlashArray C is cost-effective capacity for dev/test or backup
$PrimaryArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'
$SecondaryArrayName = 'sn1-c60-e12-16.puretec.purestorage.com'
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$PrimaryArray = Connect-Pfa2Array –EndPoint $PrimaryArrayName -Credential $Credential -IgnoreCertificateError


# ===============================================
# VERIFY FLEET MEMBERSHIP AND ARRAY CONNECTIONS
# ===============================================
# Retrieve all fleet members visible from the primary array
# Excluding FlashBlade (sn1-s200-c09-33) and the secondary array to focus on FlashArray X's
$PrimaryFleetInfo = Get-Pfa2FleetMember -Array $PrimaryArray -Filter "Member.Name!='sn1-s200-c09-33' and Member.Name!='sn1-c60-e12-16'"


Write-Output "`nFleet Members from Primary Array perspective:"
$PrimaryFleetInfo.Member.Name


# Verify if a replication connection already exists between the arrays
# This checks for async-replication type connections specifically
$SecondaryArrayName.Split('.')[0]
Write-Output "`nChecking for existing replication connections to $($SecondaryArrayName.Split('.')[0])..." 

Get-Pfa2ArrayConnection -Array $PrimaryArray `
    -ContextNames $PrimaryFleetInfo.Member.Name `
    -Filter "Remote.Name='$($SecondaryArrayName.Split('.')[0])' and Type='async-replication'"


# Retrieve the remote array object needed for configuring replication targets
# CurrentFleetOnly ensures we only get arrays within our managed fleet
$remoteArray = Get-Pfa2RemoteArray -Array $PrimaryArray -CurrentFleetOnly $true -Name $SecondaryArrayName.Split('.')[0]
$remoteArray

# ===============================================
# CREATE REPLICATION-ENABLED PRESET WITH PROTECTION
# ===============================================
# This preset defines a complete SQL Server storage configuration with:
# - 4 volumes (Data, Log, TempDB, System) with different sizes
# - Quality of Service (QoS) limits
# - Snapshot policies for local protection
# - Cross-array replication for disaster recovery
# Build one remote target as a List[string]

$ReplicationTargets = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
$inner = [System.Collections.Generic.List[string]]::new()
$inner.Add("")
$inner.Add($remoteArray.Name)
$inner.Add("remote-arrays")
$ReplicationTargets.Add($inner)

$presetParams = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'  # The Fusion context where this preset will be created
    Name                                            = "SQL-Server-MultiDisk-Optimized-Replication"
    Description                                     = "SQL Server optimized preset with different volumes for Data, Log, TempDB, and System with cross-array replication"
    WorkloadType                                    = "database"  # Categorizes this as a database workload

    # QoS Configuration: Define performance limits to prevent noisy neighbor issues
    QosConfigurationsName                           = @("Sql-QoS")
    QosConfigurationsIopsLimit                      = @("75000")  # 75K IOPS limit for SQL workload

    # Placement Configuration: Determines which storage class/array type to use
    PlacementConfigurationsName                     = @("Data-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")  # Target high-performance X arrays
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Sql-QoS"))  # Apply QoS to this placement

    # Volume Configuration: Define 4 volumes with SQL Server best practices
    VolumeConfigurationsName                        = @("SQL-Data", "SQL-Log", "SQL-TempDB", "SQL-System")
    VolumeConfigurationsCount                       = @("1", "1", "1", "1")  # One volume of each type
    VolumeConfigurationsPlacementConfigurations     = @( @("Data-Placement"), @("Data-Placement"), @("Data-Placement"), @("Data-Placement") )
    VolumeConfigurationsProvisionedSize             = @( 5TB, 1TB, 2TB, 500GB )  # Different sizes per SQL requirements

    # Snapshot Configuration: Local protection with 10-minute intervals kept for 7 days
    SnapshotConfigurationsName                      = @("Data-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("600000")     # 600,000ms = 10 minutes
    SnapshotConfigurationsRulesKeepFor              = @("604800000")  # 604,800,000ms = 7 days

    # Apply snapshots to all volumes except TempDB (temporary data doesn't need snapshots)
    VolumeConfigurationsSnapshotConfigurations      = @(
        @("Data-Snapshots"),  # SQL-Data gets snapshots
        @("Data-Snapshots"),  # SQL-Log gets snapshots
        @(),                  # SQL-TempDB no snapshots (temporary data)
        @("Data-Snapshots")   # SQL-System gets snapshots
    )

    # Replication Configuration: Cross-array protection for disaster recovery
    PeriodicReplicationConfigurationsRemoteTargets  = $ReplicationTargets
    PeriodicReplicationConfigurationsName           = @("CrossArray-Replication-PG")
    PeriodicReplicationConfigurationsRulesEvery     = @(([TimeSpan]::FromMinutes(10).TotalMilliseconds).ToString())   # 10 minutes
    PeriodicReplicationConfigurationsRulesKeepFor   = @(([TimeSpan]::FromDays(14).TotalMilliseconds).ToString())    # 14 days

    # Apply replication to all volumes except TempDB (can be recreated in DR)
    VolumeConfigurationsPeriodicReplicationConfigurations = @(
        @("CrossArray-Replication-PG"),  # SQL-Data gets replicated
        @("CrossArray-Replication-PG"),  # SQL-Log gets replicated
        @(),                             # SQL-TempDB not replicated (recreate in DR)
        @("CrossArray-Replication-PG")   # SQL-System gets replicated
    )

    # Workload Tags: Metadata for tracking, compliance, and automation
    WorkloadTagsKey                                 = @("database-type", "application", "tier", "backup-required","replication-enabled", "dr-priority", "rpo", "target-array")
    WorkloadTagsValue                               = @("sql-server", "enterprise-app", "production", "true","true", "high", "1-hour", $SecondaryArrayName.Split('.')[0])
}

Write-Output "`nCreating cross-array replication preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @presetParams -Verbose

# ===============================================
# CREATE WORKLOAD FROM PRESET
# ===============================================
# Example: Deploy a new SQL Server workload using the preset we just created
# This will automatically create all volumes, apply QoS, configure snapshots, and set up replication
$workloadParams1 = @{
    Array                                           = $PrimaryArray
    Name                                            = "Production-SQL-01"
    PresetNames                                     = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized-Replication")
}
New-Pfa2Workload @workloadParams1


# Verify the workload was created successfully
Get-Pfa2Workload -Array $PrimaryArray | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized-Replication' } | Format-List


# ===============================================
# VERIFY PROTECTION GROUP CONFIGURATION
# ===============================================
# Get the protection group created for cross-array replication
# Note: Removed underscore from workload name as Fusion uses hyphens
$PGName = Get-Pfa2ProtectionGroup -Array $PrimaryArray -Filter "workload.name='Production-SQL-01' and workload.configuration='CrossArray-Replication-PG'"
$PGName


# ===============================================
# QUERY FLEET-WIDE PROTECTION GROUPS
# ===============================================
# Get all fleet members except FlashBlade for protection group queries
$FleetInfo = Get-Pfa2FleetMember -Array $PrimaryArray -Filter "Member.Name!='sn1-s200-c09-33'"  # Exclude the FlashBlade
$FleetInfo | Format-List


# Query all arrays in the fleet for protection groups associated with our workload
# This returns both local snapshot PGs and remote replication PGs
$PGNames = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetInfo.Member.Name -Filter "workload.name='Production-SQL-01'"
$PGNames


# Identify local and remote protection groups
$LocalProtectionGroup  = $PGNames | Where-Object { $_.Workload._Configuration -eq 'Data-Snapshots' }
$RemoteProtectionGroup = $PGNames | Where-Object { $_.Workload._Configuration -eq 'CrossArray-Replication-PG' }
$LocalProtectionGroup.Name
$RemoteProtectionGroup.Name

# Build the remote protection group name to include the source array name and the protection group name
$RemoteProtectionGroupName = "$($RemoteProtectionGroup.Source.Name):$($RemoteProtectionGroup.Name)"
$RemoteProtectionGroupName


# ===============================================
# LOCATE REPLICATED DATA
# ===============================================
# Find which array in the fleet contains the replicated protection group
# The format is "source-array:protection-group-name" for replicated PGs...eventually I don't want to use PG name, but Tags
$TargetPGName = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetInfo.Member.Name -Name $RemoteProtectionGroupName
$TargetPGName

Write-Output "The protection group snapshots are on the array: $($TargetPGName.Context.Name)"


# ===============================================
# LIST PROTECTION GROUP SNAPSHOTS
# ===============================================
# Query all fleet arrays for snapshots of our protection group
# This shows snapshots on both source and target arrays
Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -ContextNames $FleetInfo.Member.Name -Name $RemoteProtectionGroupName
Write-Output "The snapshots are on the following arrays: $($TargetPGName.Context.Name)"

# we don't want the user to have to care about this....

# Measure the runtime of the previous cmdlet
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -ContextNames $FleetInfo.Member.Name -Name $RemoteProtectionGroupName
$Stopwatch.Stop()
Write-Output "Runtime: $($Stopwatch.Elapsed.TotalSeconds) seconds"


# For better performance, query only the specific target array
# This is more efficient when you know which array contains the replicas
Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -ContextNames $($TargetPGName.Context.Name) -Name $RemoteProtectionGroupName

# Measure the runtime of the previous cmdlet
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -ContextNames $($TargetPGName.Context.Name) -Name $RemoteProtectionGroupName
$Stopwatch.Stop()
Write-Output "Runtime: $($Stopwatch.Elapsed.TotalSeconds) seconds"


# Clean up created resources
Remove-Pfa2Workload -Array $PrimaryArray -Name "Production-SQL-01"
Remove-Pfa2Workload -Array $PrimaryArray -Name "Production-SQL-01" -Eradicate -Confirm:$false


# Remove the Preset
Remove-Pfa2PresetWorkload -Array $FlashArray -ContextNames 'fsa-lab-fleet1' -Name "SQL-Server-MultiDisk-Optimized-Replication"



########################################################################################################################
#
# When we removed the workload what happens to the protection group snapshots on the source and target arrays?
#
########################################################################################################################







# Ask the whole fleet, where are the local and remote snapshots.
Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name -Name $RemoteProtectionGroupName | Format-Table -AutoSize
Get-Pfa2ProtectionGroupSnapshot -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name -Name $LocalProtectionGroup.Name | Format-Table -AutoSize

# Get the protection groups to delete
$LocalProtectionGroupToDelete  = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name -Name $LocalProtectionGroup.Name
$RemoteProtectionGroupToDelete = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name -Name $RemoteProtectionGroupName


$LocalProtectionGroupToDelete
$RemoteProtectionGroupToDelete


# If we want we can remove it from the X array, which is the source array, you have to scope the command to the array where the snapshots are
Remove-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $LocalProtectionGroupToDelete.Context.Name -Name $LocalProtectionGroupToDelete.Name
Remove-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $LocalProtectionGroupToDelete.Context.Name -Name $LocalProtectionGroupToDelete.Name -Eradicate -Confirm:$false
