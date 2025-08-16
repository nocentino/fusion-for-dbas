# Connect to the FlashArray
$ArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$FlashArray = Connect-Pfa2Array –EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError

# Get fleet membership to extract fleet name and identify replication target
$FleetInfo = Get-Pfa2FleetMember -Array $FlashArray
$FleetName = $FleetInfo[0].Fleet.Name

# Identify FlashArray//C as replication target
$FlashArrayCTarget = $FleetInfo | Where-Object { $_.Member.ArrayModel -like '*C*' } | Select-Object -First 1 -ExpandProperty Member | Select-Object -ExpandProperty Name

Write-Host "Fleet Name: $FleetName" -ForegroundColor Green
Write-Host "Replication Target (FlashArray//C): $FlashArrayCTarget" -ForegroundColor Yellow

# Example: Database with Data, Log, TempDB, and Backup volumes
$presetParams = @{
    Array                                           = $FlashArray
    ContextNames                                    = $FleetName
    Name                                            = "SQL-Server-MultiDisk-Replicated"
    Description                                     = "SQL Server optimized preset with async replication to FlashArray//C"
    WorkloadType                                    = "database"

    # QoS configurations
    QosConfigurationsName                           = @("Data-QoS")
    QosConfigurationsIopsLimit                      = @("75000")
    QosConfigurationsBandwidthLimit                 = @("2000000000")  # 2GB/s

    # Placement configurations
    PlacementConfigurationsName                     = @("Data-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Data-QoS"))

    # SQL Server volume configuration
    VolumeConfigurationsName                        = @("SQL-Data", "SQL-Log", "SQL-TempDB", "SQL-Backup")
    VolumeConfigurationsCount                       = @("1", "1", "1", "1")
    VolumeConfigurationsPlacementConfigurations     = @(@("Data-Placement"), @("Data-Placement"), @("Data-Placement"), @("Data-Placement"))
    VolumeConfigurationsProvisionedSize             = @(5TB, 1TB, 500GB, 2TB)

    # Snapshot configurations
    SnapshotConfigurationsName                      = @("Replication-Snapshots", "Local-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("900000", "600000")        # 15min, 10min
    SnapshotConfigurationsRulesKeepFor              = @("86400000", "604800000")   # 1 day, 7 days

    # Periodic Replication Configuration (corrected)
    PeriodicReplicationConfigurationsName           = @("SQL-Async-Replication")
    PeriodicReplicationConfigurationsRemoteTargets  = @(@($FlashArrayCTarget))    # Note: nested array
    PeriodicReplicationConfigurationsRulesEvery     = @("3600000")                # 1 hour in milliseconds
    PeriodicReplicationConfigurationsRulesKeepFor   = @("604800000")              # 7 days in milliseconds
    
    # Optional: If you want replication at a specific time (e.g., 2 AM)
    # PeriodicReplicationConfigurationsRulesAt      = @("7200000")                # 2 hours after midnight (2 AM)

    # Assign snapshot configurations to volumes
    VolumeConfigurationsSnapshotConfigurations      = @(
        @("Local-Snapshots", "Replication-Snapshots"),  # Data volume
        @("Local-Snapshots", "Replication-Snapshots"),  # Log volume
        @(),                                            # TempDB - no snapshots
        @("Local-Snapshots")                            # Backup - local only
    )

    # Workload tags
    WorkloadTagsKey                                 = @("database-type", "tier", "replication-enabled", "replication-target")
    WorkloadTagsValue                               = @("sql-server", "production", "true", $FlashArrayCTarget)
}

Write-Host "`nCreating SQL Server preset with periodic replication configuration..." -ForegroundColor Green
New-Pfa2PresetWorkload @presetParams -Verbose

# Verify the preset was created
$createdPreset = Get-Pfa2PresetWorkload -Array $FlashArray -Filter "name='$FleetName`:SQL-Server-MultiDisk-Replicated'"
if ($createdPreset) {
    Write-Host "`nPreset created successfully!" -ForegroundColor Green
    $createdPreset | Format-List Name, Description, WorkloadType
}

# ===============================================
# CREATE WORKLOADS FROM THE PRESET
# ===============================================

Write-Host "`n=== CREATING SQL SERVER WORKLOADS ===" -ForegroundColor Cyan

# Create multiple SQL Server instances
$sqlInstances = @(
    "PROD-SQL-001",
    "PROD-SQL-002", 
    "REP-SQL-001",
    "DEV-SQL-001",
    "QA-SQL-001"
)

foreach ($instance in $sqlInstances) {
    Write-Host "Creating workload: $instance" -ForegroundColor Yellow
    New-Pfa2Workload -Array $FlashArray -Name $instance -PresetNames @("$FleetName`:SQL-Server-MultiDisk-Replicated") -Verbose
}

# ===============================================
# VERIFY CREATED WORKLOADS
# ===============================================

Write-Host "`n=== VERIFYING WORKLOADS ===" -ForegroundColor Cyan

# Get all workloads created from this preset
$createdWorkloads = Get-Pfa2Workload -Array $FlashArray | 
    Where-Object { $_.Preset.Name -eq "$FleetName`:SQL-Server-MultiDisk-Replicated" }

Write-Host "`nCreated workloads:" -ForegroundColor Green
$createdWorkloads | Select-Object Name, @{N="VolumeCount";E={$_.VolumeCount}}, Created | Format-Table -AutoSize

# Check protection groups for the workloads
Write-Host "`nProtection Groups:" -ForegroundColor Green
foreach ($workload in $createdWorkloads) {
    $pg = Get-Pfa2ProtectionGroup -Array $FlashArray -Filter "workload.name='$($workload.Name)'"
    if ($pg) {
        Write-Host "  $($workload.Name): $($pg.Name) [Replication Enabled: $($pg.ReplicationEnabled)]"
    }
}

# ===============================================
# FLEET-WIDE VERIFICATION
# ===============================================

Write-Host "`n=== FLEET-WIDE VERIFICATION ===" -ForegroundColor Cyan

# Get all fleet members (excluding FlashBlade)
$FleetMembers = Get-Pfa2FleetMember -Array $FlashArray -Filter "Member.Name!='sn1-s200-c09-33'"

# Query all workloads across the fleet
Write-Host "`nQuerying workloads across entire fleet..." -ForegroundColor Yellow
$fleetWorkloads = Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name

Write-Host "Total workloads in fleet: $($fleetWorkloads.Count)" -ForegroundColor Green

# Filter for SQL workloads
$sqlWorkloads = $fleetWorkloads | Where-Object { $_.Preset.Name -like "*SQL-Server*" }
Write-Host "SQL Server workloads in fleet: $($sqlWorkloads.Count)" -ForegroundColor Green

$sqlWorkloads | Select-Object @{N="Array";E={$_.Name.Split(':')[0]}}, 
    @{N="Workload";E={$_.Name.Split(':')[1]}}, 
    @{N="Preset";E={$_.Preset.Name.Split(':')[1]}} | 
    Format-Table -AutoSize

# ===============================================
# CLEANUP (OPTIONAL)
# ===============================================

# Uncomment to remove created resources
# foreach ($instance in $sqlInstances) {
#     Remove-Pfa2Workload -Array $FlashArray -Name $instance -Confirm:$false
# }
# Remove-Pfa2PresetWorkload -Array $FlashArray -ContextNames $FleetName -Name "SQL-Server-MultiDisk-Replicated" -Confirm:$false

# Disconnect from array
Disconnect-Pfa2Array -Array $FlashArray -Confirm:$false