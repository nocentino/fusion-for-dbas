# ===============================================
# ARRAY CONNECTION AND SELECTION
# ===============================================
# Multiple arrays are available in the fleet - uncomment the one you want to use
# Each array serves different purposes:
# - X90R2 arrays: High-performance production workloads
# - C60 arrays: Cost-effective capacity for dev/test or backup
$ArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'    # Primary production array
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$FlashArray = Connect-Pfa2Array –EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError

# ===============================================
# DISCOVER AVAILABLE FUSION CMDLETS
# ===============================================
# List all Fleet-related PowerShell cmdlets available in the SDK
# These cmdlets enable fleet-wide operations and management
Get-Command -Module PureStoragePowerShellSDK2 -Noun '*Fleet*'


# List all Workload and Preset-related cmdlets
# These are the primary tools for Fusion workload management
Get-Command -Module PureStoragePowerShellSDK2 -Noun '*Workload*'


# ===============================================
# VERIFY FLEET MEMBERSHIP
# ===============================================
# Get fleet membership - shows all arrays that are part of this Fusion fleet
# This confirms which arrays we can manage from this connection point
$FleetInfo = Get-Pfa2FleetMember -Array $FlashArray 
$FleetInfo.Member.Name 


# ===============================================
# CREATE SQL SERVER WORKLOAD PRESET
# ===============================================
# This preset implements SQL Server storage best practices:
# - Separate volumes for Data, Log, TempDB, and System files
# - Appropriate sizing for each volume type
# - QoS limits to prevent noisy neighbor issues
# - Snapshot policies for data protection
# - Tags for tracking and automation

$presetParams = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'  # Fleet name required for fleet-wide objects
    Name                                            = "SQL-Server-MultiDisk-Optimized"
    Description                                     = "SQL Server optimized preset with different volumes for Data, Log, TempDB, and System"
    WorkloadType                                    = "database"  # Categorizes workload for reporting and management

    # QoS Configuration: Define performance limits for the entire workload
    # This prevents a single SQL instance from consuming all array resources
    QosConfigurationsName                           = @("Sql-QoS")
    QosConfigurationsIopsLimit                      = @("75000")  # 75K IOPS limit suitable for most SQL workloads

    # Placement Configuration: Determines which arrays/storage classes can host this workload
    PlacementConfigurationsName                     = @("Data-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")  # Target high-performance X arrays
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Sql-QoS"))  # Link QoS to placement

    # Volume Configuration: SQL Server requires different volumes for optimal performance
    VolumeConfigurationsName                        = @("SQL-Data", "SQL-Log", "SQL-TempDB", "SQL-System")
    VolumeConfigurationsCount                       = @("1", "1", "1", "1")  # One of each volume type
    VolumeConfigurationsPlacementConfigurations     = @( @("Data-Placement"), @("Data-Placement"), @("Data-Placement"), @("Data-Placement") )
    VolumeConfigurationsProvisionedSize             = @( 5TB, 1TB, 500GB, 2TB )  # Sizes using PowerShell's native suffixes

    # Snapshot Configuration: Local protection policy
    SnapshotConfigurationsName                      = @("Data-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("600000")      # 600,000ms = 10 minutes
    SnapshotConfigurationsRulesKeepFor              = @("604800000")   # 604,800,000ms = 7 days

    # Apply snapshots selectively - TempDB doesn't need snapshots as it's recreated on SQL restart
    VolumeConfigurationsSnapshotConfigurations      = @(
        @("Data-Snapshots"),   # SQL-Data: Critical user data needs protection
        @("Data-Snapshots"),   # SQL-Log: Transaction logs for point-in-time recovery
        @(),                   # SQL-TempDB: Temporary data, no snapshots needed
        @("Data-Snapshots")    # SQL-System: System databases need protection
    )

    # Workload Tags: Metadata for automation, compliance, and reporting
    WorkloadTagsKey                                 = @("database-type", "application", "tier", "backup-required")
    WorkloadTagsValue                               = @("sql-server", "enterprise-app", "production", "true")
}

Write-Host "Creating SQL Server optimized multi-disk preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @presetParams


# Verify preset creation
# Note: The -Filter parameter is not available for this cmdlet, so we use Where-Object
Get-Pfa2PresetWorkload -Array $FlashArray | Where-Object { $_.Name -like "fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized" } | Format-List


# ===============================================
# DEPLOY WORKLOAD FROM PRESET
# ===============================================
# Create a production SQL Server instance using our standardized preset
# This single command creates all volumes, configures QoS, and sets up snapshots

# Example 1: Create Production SQL Server Workload
$workloadParams1 = @{
    Array       = $FlashArray
    Name        = "Production-SQL-01"
    PresetNames = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")  # Reference the fleet-scoped preset
}

New-Pfa2Workload @workloadParams1

# Verify workload creation and list all workloads using this preset
Get-Pfa2Workload -Array $FlashArray | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Format-Table -AutoSize

# ===============================================
# INSPECT WORKLOAD COMPONENTS
# ===============================================
# Each workload creates multiple objects that we can query

# Get the volume group (container for all volumes in the workload)
Get-Pfa2VolumeGroup -Array $FlashArray -Filter "workload.name='Production-SQL-01'"


# Get individual volumes created for the workload
# This will show SQL-Data, SQL-Log, SQL-TempDB, and SQL-System volumes
Get-Pfa2Volume -Array $FlashArray -Filter "workload.name='Production-SQL-01'"


# Get the protection group automatically created for snapshot management
$PGName = Get-Pfa2ProtectionGroup -Array $FlashArray -Filter "workload.name='Production-SQL-01'"
$PGName


# List existing snapshots for the protection group
# Snapshots are created automatically based on the schedule defined in the preset
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Filter "name='$($PGName.Name)*'"


# ===============================================
# FLEET-WIDE MANAGEMENT DEMONSTRATION
# ===============================================
# Fusion enables management across all arrays in the fleet from a single connection
# This eliminates the need to connect to each array individually

# Get all fleet members, excluding non-FlashArray systems
# The FlashBlade (sn1-s200-c09-33) is excluded as it uses different object types
$FleetMembers = Get-Pfa2FleetMember -Array $FlashArray -Filter "Member.Name!='sn1-s200-c09-33'"
$FleetMembers.Member.Name


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

$SQLInstances = @("Production-SQL-03", "DR-SQL-01", "Test-SQL-01", "Dev-SQL-01")

foreach ($instance in $SQLInstances) {
    $workloadParams = @{
        Array       = $FlashArray
        Name        = $instance
        PresetNames = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
    }
    
    New-Pfa2Workload @workloadParams
    Write-Output "Created workload for $instance" -ForegroundColor Green
}

# List all workloads across the fleet that use our SQL Server preset
Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Format-Table -AutoSize

# ===============================================
# CROSS-ARRAY WORKLOAD DEPLOYMENT
# ===============================================
# Deploy a workload on a different array (if connected)
# This demonstrates Fusion's ability to manage workloads regardless of which array you're connected to

$FleetMembers.Member.Name

$workloadParams2 = @{
    Array       = $FlashArray
    ContextNames = $FleetMembers.Member.Name
    Name        = "Production-SQL-02"
    PresetNames = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}

New-Pfa2Workload @workloadParams2

# ===============================================
# CLEANUP OPERATIONS
# ===============================================
# Remove test workloads and presets
# WARNING: This will delete all volumes and data associated with these workloads

# Remove individual workloads
Remove-Pfa2Workload -Array $FlashArray -Name "Production-SQL-01"
Remove-Pfa2Workload -Array $FlashArray -Name "Production-SQL-02"

# Remove workloads
$SQLInstances = @("Production-SQL-03", "DR-SQL-01", "Test-SQL-01", "Dev-SQL-01")

foreach ($instance in $SQLInstances) {
    $workloadParams = @{
        Array       = $FlashArray
        Name        = $instance
        PresetNames = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
    }
    
    Remove-Pfa2Workload -Array $FlashArray -Name $instance
    Write-Output "Removed workload for $instance" -ForegroundColor Green
}

# Remove the preset (only after all workloads using it are deleted)
Remove-Pfa2PresetWorkload -Array $FlashArray -ContextNames 'fsa-lab-fleet1' -Name "SQL-Server-MultiDisk-Optimized" 




# ===============================================
# ADVANCED FUSION TOPICS (FUTURE EXPLORATION)
# ===============================================
# The following topics represent advanced Fusion capabilities for future scripts:

# **Cross-Array Replication**: Configuring periodic replication between arrays in your Fleet for disaster recovery and data mobility

# **Using Fusion for Remote Command Execution**: Fusion allows for remote command execution across all objects in your fleet rather than just per array

# **Building a Global Snapshot Catalog**: Using tags combined with Fusion's fleet-wide scope, you can find and consume a snapshot anywhere in your Fleet

# **Updating Workload Presets**: How to modify existing Presets and handle versioning as your requirements evolve

# **Finding Configuration Skew**: Use PowerShell to find configuration skew in your environment

# **Fleet-Wide Monitoring**: Gathering performance metrics and capacity data across all arrays from a single control point

# **Advanced Placement Strategies**: Using Workload placement recommendations to optimize resource utilization across your Fleet