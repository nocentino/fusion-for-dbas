# ===============================================
# ARRAY CONNECTION AND SELECTION
# ===============================================
# - X90R2 arrays: High-performance production workloads
$ArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'    
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$FlashArray = Connect-Pfa2Array –EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError -Verbose


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
$FleetInfo | Format-List
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
    QosConfigurationsIopsLimit                      = @("75000") 

    # Placement Configuration: Determines which arrays/storage classes can host this workload
    PlacementConfigurationsName                     = @("Data-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")  # Target high-performance X arrays
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Sql-QoS"))    # Link QoS to placement

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

Write-Host "Creating SQL Server optimized multi-disk preset..."
New-Pfa2PresetWorkload @presetParams


# Verify preset creation
# Note: The -Filter parameter is not available for this cmdlet, so we use Where-Object
Get-Pfa2PresetWorkload -Array $FlashArray | Where-Object { $_.Name -like "fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized" } | Format-List


# ===============================================
# DEPLOY WORKLOAD FROM PRESET
# ===============================================
# Create a production SQL Server instance using our standardized preset
# This single command creates all volumes, configures QoS, and sets up protection group snapshots


# Example 1: Create Production SQL Server Workload
$workloadParams1 = @{
    Array       = $FlashArray # This gets deployed on the array we're currently connected to
    Name        = "Production-SQL-01"
    PresetNames = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")  # Reference the fleet-scoped preset
}

New-Pfa2Workload @workloadParams1


# Verify workload creation and list all workloads using this preset, -Filter is also not available for this cmdlet
Get-Pfa2Workload -Array $FlashArray | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Format-List 


# ===============================================
# INSPECT WORKLOAD COMPONENTS
# ===============================================
# Each workload creates multiple objects that we can query

# Get the volume group (container for all volumes in the workload), using array-side filtering on the workload attribute
# Notice the QoS configuration is applied here.
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
# BULK WORKLOAD DEPLOYMENT
# ===============================================
# Deploy multiple SQL Server instances using the same preset
# These workloads are being placed on the FlashArray we're connected to. We will cover cross-array deployment later.
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
