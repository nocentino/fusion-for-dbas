# ===============================================
# ARRAY CONNECTION AND SELECTION
# ===============================================
# Multiple arrays are available in the fleet - uncomment the one you want to use
# Each array serves different purposes:
# - X90R2 arrays: High-performance production workloads
$ArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'    
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$FlashArray = Connect-Pfa2Array –EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError -Verbose

VERBOSE: PureStorage.Rest Verbose: 10 : 2025-08-27T13:17:41.5760540Z POST https://sn1-x90r2-f06-27.puretec.purestorage.com/api/1.16/auth/apitoken
VERBOSE: PureStorage.Rest Verbose: 10 : 2025-08-27T13:17:43.3616270Z POST https://sn1-x90r2-f06-27.puretec.purestorage.com/api/1.16/auth/session
VERBOSE: PureStorage.Rest Verbose: 10 : 2025-08-27T13:17:43.6965120Z PUT https://sn1-x90r2-f06-27.puretec.purestorage.com/api/1.16/admin/anocentino
VERBOSE: PureStorage.Rest Verbose: 11 : 2025-08-27T13:17:44.5050460Z PUT https://sn1-x90r2-f06-27.puretec.purestorage.com/api/1.16/admin/anocentino  809ms {"name": "anocentino", "role": "array_admin"}
VERBOSE: PureStorage.Rest Verbose: 10 : 2025-08-27T13:17:44.5059360Z POST https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.2/login <no body>
VERBOSE: PureStorage.Rest Verbose: 11 : 2025-08-27T13:17:44.9186390Z POST https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.2/login 200 413ms {"items":[{"username":"anocentino"}]}
VERBOSE: PureStorage.Rest Verbose: 13 : 2025-08-27T13:17:44.9191330Z sn1-x90r2-f06-27.puretec.purestorage.com: Connect-Pfa2Array (PSCredential) Endpoint=sn1-x90r2-f06-27.puretec.purestorage.com Credential=System.Management.Automation.PSCredential IgnoreCertificateError=True Verbose=True


# Example API request: Get array info
$ArrayEndpoint = 'sn1-x90r2-f06-27.puretec.purestorage.com' # FlashArray's IP or DNS name
$ApiToken      = "6a20f30a-2c4b-90eb-ada3-bcae602637a8"     # Paste your valid API token
$fa            = Connect-Pfa2Array -ApiToken $ApiToken -Endpoint $ArrayEndpoint -IgnoreCertificateError

VERBOSE: PureStorage.Rest Verbose: 10 : 2025-08-27T13:17:02.5634320Z POST https://sn1-x90r2-f06-27.puretec.purestorage.com/api/1.16/auth/session
VERBOSE: PureStorage.Rest Verbose: 10 : 2025-08-27T13:17:02.8450970Z PUT https://sn1-x90r2-f06-27.puretec.purestorage.com/api/1.16/admin/anthony-exporter
VERBOSE: PureStorage.Rest Verbose: 11 : 2025-08-27T13:17:03.1304660Z PUT https://sn1-x90r2-f06-27.puretec.purestorage.com/api/1.16/admin/anthony-exporter  287ms {"name": "anthony-exporter", "role": "readonly"}
VERBOSE: PureStorage.Rest Verbose: 10 : 2025-08-27T13:17:03.1306520Z POST https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.2/login <no body>
VERBOSE: PureStorage.Rest Verbose: 11 : 2025-08-27T13:17:03.3958940Z POST https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.2/login 200 265ms {"items":[{"username":"anthony-exporter"}]}
VERBOSE: PureStorage.Rest Verbose: 13 : 2025-08-27T13:17:03.3961860Z sn1-x90r2-f06-27.puretec.purestorage.com: Connect-Pfa2Array (ApiToken) ApiToken=6a20f30a-2c4b-90eb-ada3-bcae602637a8 Endpoint=sn1-x90r2-f06-27.puretec.purestorage.com IgnoreCertificateError=True Verbose=True


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
# This single command creates all volumes, configures QoS, and sets up snapshots


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


