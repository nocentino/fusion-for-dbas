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
$remoteArray.Name




# ===============================================
# BRONZE TIER PRESETS
# ===============================================

# Bronze Tier - No Replication
$BronzePresetNoRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Bronze-NoRepl"
    Description                                     = "Bronze tier compute workload without replication"
    WorkloadType                                    = "compute"

    # QoS Configuration
    QosConfigurationsName                           = @("Bronze-QoS")
    QosConfigurationsIopsLimit                      = @("10000")
    QosConfigurationsBandwidthLimit                 = @("209715200")  # 200 MB/s in bytes/sec

    # Placement Configuration
    PlacementConfigurationsName                     = @("Bronze-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-c")  # Target C-series arrays
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Bronze-QoS"))

    # Volume Configuration
    VolumeConfigurationsName                        = @("Bronze-Vol")
    VolumeConfigurationsCount                       = @("1")
    VolumeConfigurationsPlacementConfigurations     = @(@("Bronze-Placement"))
    VolumeConfigurationsProvisionedSize             = @(500GB)

    # Snapshot Configuration
    SnapshotConfigurationsName                      = @("Bronze-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("21600000")    # 6 hours in ms
    SnapshotConfigurationsRulesKeepFor              = @("604800000")   # 7 days in ms

    VolumeConfigurationsSnapshotConfigurations      = @(@("Bronze-Snapshots"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level")
    WorkloadTagsValue                               = @("bronze", "false", "standard")
}

New-Pfa2PresetWorkload @BronzePresetNoRepl


$remoteTarget1 = [System.Collections.Generic.List[string]]::new()
$remoteTarget1.Add("")
$remoteTarget1.Add($remoteArray.Name)
$remoteTarget1.Add("remote-arrays")


# Build the outer List<List[string]> and add the inner one
$remoteTargets = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
$remoteTargets.Add($remoteTarget1)

# Bronze Tier - With Replication
$BronzePresetWithRepl = @{
    Array                                           = $PrimaryArray  # Changed from $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Bronze-WithRepl"
    Description                                     = "Bronze tier compute workload with daily replication"
    WorkloadType                                    = "compute"

    # QoS Configuration
    QosConfigurationsName                           = @("Bronze-QoS")
    QosConfigurationsIopsLimit                      = @("10000")
    QosConfigurationsBandwidthLimit                 = @("209715200")  # 200 MB/s

    # Placement Configuration
    PlacementConfigurationsName                     = @("Bronze-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-c")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Bronze-QoS"))

    # Volume Configuration
    VolumeConfigurationsName                        = @("Bronze-Vol")
    VolumeConfigurationsCount                       = @("1")
    VolumeConfigurationsPlacementConfigurations     = @(@("Bronze-Placement"))
    VolumeConfigurationsProvisionedSize             = @(500GB)

    # Snapshot Configuration
    SnapshotConfigurationsName                      = @("Bronze-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("21600000")    # 6 hours
    SnapshotConfigurationsRulesKeepFor              = @("604800000")   # 7 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Bronze-Snapshots"))

    # Replication Configuration
    PeriodicReplicationConfigurationsName           = @("Bronze-Replication")
    PeriodicReplicationConfigurationsRulesEvery     = @("86400000")    # 24 hours
    PeriodicReplicationConfigurationsRulesKeepFor   = @("604800000")   # 7 days

    
    # Build remote targets as shown in the replication example
    PeriodicReplicationConfigurationsRemoteTargets  = $remoteTargets

    VolumeConfigurationsPeriodicReplicationConfigurations = @(@("Bronze-Replication"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level", "rpo")
    WorkloadTagsValue                               = @("bronze", "true", "standard", "24-hours")
}

New-Pfa2PresetWorkload @BronzePresetWithRepl

# ===============================================
# SILVER TIER PRESETS
# ===============================================


# Silver Tier - No Replication
$SilverPresetNoRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Silver-NoRepl"
    Description                                     = "Silver tier compute workload without replication"
    WorkloadType                                    = "compute"

    # QoS Configuration
    QosConfigurationsName                           = @("Silver-QoS")
    QosConfigurationsIopsLimit                      = @("50000")
    QosConfigurationsBandwidthLimit                 = @("1073741824")  # 1 GB/s

    # Placement Configuration
    PlacementConfigurationsName                     = @("Silver-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Silver-QoS"))

    # Volume Configuration
    VolumeConfigurationsName                        = @("Silver-Vol")
    VolumeConfigurationsCount                       = @("1")
    VolumeConfigurationsPlacementConfigurations     = @(@("Silver-Placement"))
    VolumeConfigurationsProvisionedSize             = @(1TB)

    # Snapshot Configuration
    SnapshotConfigurationsName                      = @("Silver-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("7200000")     # 2 hours
    SnapshotConfigurationsRulesKeepFor              = @("1209600000")  # 14 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Silver-Snapshots"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level")
    WorkloadTagsValue                               = @("silver", "false", "enhanced")
}

New-Pfa2PresetWorkload @SilverPresetNoRepl


# Silver Tier - With Replication
$SilverPresetWithRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Silver-WithRepl"
    Description                                     = "Silver tier compute workload with bi-hourly replication"
    WorkloadType                                    = "compute"

    # QoS Configuration
    QosConfigurationsName                           = @("Silver-QoS")
    QosConfigurationsIopsLimit                      = @("50000")
    QosConfigurationsBandwidthLimit                 = @("1073741824")  # 1 GB/s

    # Placement Configuration
    PlacementConfigurationsName                     = @("Silver-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Silver-QoS"))

    # Volume Configuration
    VolumeConfigurationsName                        = @("Silver-Vol")
    VolumeConfigurationsCount                       = @("1")
    VolumeConfigurationsPlacementConfigurations     = @(@("Silver-Placement"))
    VolumeConfigurationsProvisionedSize             = @(1TB)

    # Snapshot Configuration
    SnapshotConfigurationsName                      = @("Silver-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("7200000")     # 2 hours
    SnapshotConfigurationsRulesKeepFor              = @("1209600000")  # 14 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Silver-Snapshots"))

    # Replication Configuration
    PeriodicReplicationConfigurationsName           = @("Silver-Replication")
    PeriodicReplicationConfigurationsRulesEvery     = @("7200000")     # 2 hours
    PeriodicReplicationConfigurationsRulesKeepFor   = @("1209600000")  # 14 days
    
    PeriodicReplicationConfigurationsRemoteTargets  = $remoteTargets

    VolumeConfigurationsPeriodicReplicationConfigurations = @(@("Silver-Replication"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level", "rpo")
    WorkloadTagsValue                               = @("silver", "true", "enhanced", "2-hours")
}

New-Pfa2PresetWorkload @SilverPresetWithRepl

# ===============================================
# GOLD TIER PRESETS
# ===============================================

# Gold Tier - No Replication
$GoldPresetNoRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Gold-NoRepl"
    Description                                     = "Gold tier compute workload without replication"
    WorkloadType                                    = "compute"

    # QoS Configuration - Set very high limits
    QosConfigurationsName                           = @("Gold-QoS")
    QosConfigurationsIopsLimit                      = @("1000000")      # 1M IOPS
    QosConfigurationsBandwidthLimit                 = @("10737418240")  # 10 GB/s

    # Placement Configuration
    PlacementConfigurationsName                     = @("Gold-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Gold-QoS"))

    # Volume Configuration
    VolumeConfigurationsName                        = @("Gold-Vol")
    VolumeConfigurationsCount                       = @("1")
    VolumeConfigurationsPlacementConfigurations     = @(@("Gold-Placement"))
    VolumeConfigurationsProvisionedSize             = @(2TB)

    # Snapshot Configuration
    SnapshotConfigurationsName                      = @("Gold-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("1800000")     # 30 minutes
    SnapshotConfigurationsRulesKeepFor              = @("2592000000")  # 30 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Gold-Snapshots"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level")
    WorkloadTagsValue                               = @("gold", "false", "premium")
}

New-Pfa2PresetWorkload @GoldPresetNoRepl

# Gold Tier - With Replication
$GoldPresetWithRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Gold-WithRepl"
    Description                                     = "Gold tier compute workload with aggressive replication"
    WorkloadType                                    = "compute"

    # QoS Configuration - Set very high limits
    QosConfigurationsName                           = @("Gold-QoS")
    QosConfigurationsIopsLimit                      = @("1000000")      # 1M IOPS
    QosConfigurationsBandwidthLimit                 = @("10737418240")  # 10 GB/s

    # Placement Configuration
    PlacementConfigurationsName                     = @("Gold-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Gold-QoS"))

    # Volume Configuration
    VolumeConfigurationsName                        = @("Gold-Vol")
    VolumeConfigurationsCount                       = @("1")
    VolumeConfigurationsPlacementConfigurations     = @(@("Gold-Placement"))
    VolumeConfigurationsProvisionedSize             = @(2TB)

    # Snapshot Configuration
    SnapshotConfigurationsName                      = @("Gold-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("1800000")     # 30 minutes
    SnapshotConfigurationsRulesKeepFor              = @("2592000000")  # 30 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Gold-Snapshots"))

    # Replication Configuration
    PeriodicReplicationConfigurationsName           = @("Gold-Replication")
    PeriodicReplicationConfigurationsRulesEvery     = @("900000")      # 15 minutes
    PeriodicReplicationConfigurationsRulesKeepFor   = @("2592000000")  # 30 days
    
    PeriodicReplicationConfigurationsRemoteTargets  = $remoteTargets

    VolumeConfigurationsPeriodicReplicationConfigurations = @(@("Gold-Replication"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level", "rpo", "priority")
    WorkloadTagsValue                               = @("gold", "true", "premium", "15-minutes", "critical")
}

New-Pfa2PresetWorkload @GoldPresetWithRepl