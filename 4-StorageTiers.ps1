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


# Retrieve the remote array object needed for configuring replication targets
# CurrentFleetOnly ensures we only get arrays within our managed fleet
$remoteArray = Get-Pfa2RemoteArray -Array $PrimaryArray -CurrentFleetOnly $true -Name $SecondaryArrayName.Split('.')[0]
$remoteArray.Name

Get-Pfa2ArrayConnection -Array $PrimaryArray `
    -ContextNames $PrimaryFleetInfo.Member.Name `
    -Filter "Remote.Name='$($remoteArray.Name)' and Type='async-replication' and Status='Connected'"



# ===============================================
# BRONZE TIER PRESETS
# ===============================================

# Bronze Tier - No Replication
$BronzePresetNoRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Bronze-NoRepl"
    Description                                     = "Bronze tier compute workload without replication"
    WorkloadType                                    = "Custom"

    # QoS Configuration
    QosConfigurationsName                           = @("Bronze-QoS")
    QosConfigurationsIopsLimit                      = @("10000")
    QosConfigurationsBandwidthLimit                 = @((200MB).ToString())  # 200 MB/s

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
    SnapshotConfigurationsRulesEvery                = @(([TimeSpan]::FromHours(6).TotalMilliseconds).ToString())    # 6 hours
    SnapshotConfigurationsRulesKeepFor              = @(([TimeSpan]::FromDays(7).TotalMilliseconds).ToString())     # 7 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Bronze-Snapshots"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level")
    WorkloadTagsValue                               = @("bronze", "false", "standard")
}

New-Pfa2PresetWorkload @BronzePresetNoRepl


# ===============================================
# SILVER TIER PRESETS
# ===============================================


# Silver Tier - No Replication
$SilverPresetNoRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Silver-NoRepl"
    Description                                     = "Silver tier compute workload without replication"
    WorkloadType                                    = "Custom"

    # QoS Configuration
    QosConfigurationsName                           = @("Silver-QoS")
    QosConfigurationsIopsLimit                      = @("50000")
    QosConfigurationsBandwidthLimit                 = @((1GB).ToString())  # 1 GB/s

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
    SnapshotConfigurationsRulesEvery                = @(([TimeSpan]::FromHours(2).TotalMilliseconds).ToString())     # 2 hours
    SnapshotConfigurationsRulesKeepFor              = @(([TimeSpan]::FromDays(14).TotalMilliseconds).ToString())    # 14 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Silver-Snapshots"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level")
    WorkloadTagsValue                               = @("silver", "false", "enhanced")
}

New-Pfa2PresetWorkload @SilverPresetNoRepl


# In the current version of the powershell module there is a type mismatch on the parameter, so we have to construct a .net object to match the current type. 
# This issue has been reported and will be fixed in the next version of the module.
$ReplicationTargets = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
$inner = [System.Collections.Generic.List[string]]::new()
$inner.Add("")
$inner.Add($remoteArray.Name)
$inner.Add("remote-arrays")
$ReplicationTargets.Add($inner)

# Silver Tier - With Replication
$SilverPresetWithRepl = @{
    Array                                           = $PrimaryArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Compute-Silver-WithRepl"
    Description                                     = "Silver tier compute workload with bi-hourly replication"
    WorkloadType                                    = "Custom"

    # QoS Configuration
    QosConfigurationsName                           = @("Silver-QoS")
    QosConfigurationsIopsLimit                      = @("50000")
    QosConfigurationsBandwidthLimit                 = @((1GB).ToString())  # 1 GB/s

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
    SnapshotConfigurationsRulesEvery                = @(([TimeSpan]::FromHours(2).TotalMilliseconds).ToString())     # 2 hours
    SnapshotConfigurationsRulesKeepFor              = @(([TimeSpan]::FromDays(14).TotalMilliseconds).ToString())    # 14 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Silver-Snapshots"))

    # Replication Configuration
    PeriodicReplicationConfigurationsRemoteTargets  = $ReplicationTargets
    PeriodicReplicationConfigurationsName           = @("Silver-Replication")
    PeriodicReplicationConfigurationsRulesEvery     = @(([TimeSpan]::FromHours(2).TotalMilliseconds).ToString())     # 2 hours
    PeriodicReplicationConfigurationsRulesKeepFor   = @(([TimeSpan]::FromDays(14).TotalMilliseconds).ToString())    # 14 days
    
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
    WorkloadType                                    = "Custom"

    # QoS Configuration - Set very high limits
    QosConfigurationsName                           = @("Gold-QoS")
    QosConfigurationsIopsLimit                      = @("1000000")      # 1M IOPS
    QosConfigurationsBandwidthLimit                 = @((10GB).ToString())  # 10 GB/s

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
    SnapshotConfigurationsRulesEvery                = @(([TimeSpan]::FromMinutes(30).TotalMilliseconds).ToString())  # 30 minutes
    SnapshotConfigurationsRulesKeepFor              = @(([TimeSpan]::FromDays(30).TotalMilliseconds).ToString())    # 30 days

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
    WorkloadType                                    = "Custom"

    # QoS Configuration - Set very high limits
    QosConfigurationsName                           = @("Gold-QoS")
    QosConfigurationsIopsLimit                      = @("1000000")      # 1M IOPS
    QosConfigurationsBandwidthLimit                 = @((10GB).ToString())  # 10 GB/s

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
    SnapshotConfigurationsRulesEvery                = @(([TimeSpan]::FromMinutes(30).TotalMilliseconds).ToString())  # 30 minutes
    SnapshotConfigurationsRulesKeepFor              = @(([TimeSpan]::FromDays(30).TotalMilliseconds).ToString())    # 30 days

    VolumeConfigurationsSnapshotConfigurations      = @(@("Gold-Snapshots"))

    # Replication Configuration
    PeriodicReplicationConfigurationsName           = @("Gold-Replication")
    PeriodicReplicationConfigurationsRulesEvery     = @(([TimeSpan]::FromMinutes(15).TotalMilliseconds).ToString())  # 15 minutes
    PeriodicReplicationConfigurationsRulesKeepFor   = @(([TimeSpan]::FromDays(30).TotalMilliseconds).ToString())    # 30 days
    
    PeriodicReplicationConfigurationsRemoteTargets  = $ReplicationTargets

    VolumeConfigurationsPeriodicReplicationConfigurations = @(@("Gold-Replication"))

    # Workload Tags
    WorkloadTagsKey                                 = @("tier", "replication", "service-level", "rpo", "priority")
    WorkloadTagsValue                               = @("gold", "true", "premium", "15-minutes", "critical")
}

New-Pfa2PresetWorkload @GoldPresetWithRepl

# ===============================================
# VERIFY PRESET CREATION
# ===============================================

# List all compute tier presets
Write-Output "`nCreated Storage Tier Presets:"
Get-Pfa2PresetWorkload -Array $PrimaryArray -ContextNames "fsa-lab-fleet1" | 
    Select-Object Name, Description | Format-Table -AutoSize


# ===============================================
# PROVISION WORKLOADS FROM PRESETS
# ===============================================


Write-Output "`nProvisioning workloads from presets..."

# Get available fleet members for workload placement
$FleetMembers = Get-Pfa2FleetMember -Array $PrimaryArray -Filter "Member.Name!='sn1-s200-c09-33'"


# 1. Bronze Workload - Deploy to C60 array
Write-Output "`nCreating Bronze tier workload on C60 array..."
$BronzeWorkload = @{
    Array        = $PrimaryArray
    ContextNames = ($FleetMembers.Member.Name | Where-Object { $_ -eq 'sn1-c60-e12-16' })
    Name         = "WebApp-Dev-01"
    PresetNames  = @("fsa-lab-fleet1:Compute-Bronze-NoRepl")
}
New-Pfa2Workload @BronzeWorkload



Write-Output "`nAdding volumes to Bronze workload (WebApp-Dev-01)..."
$bronzeContext = (Get-Pfa2Workload -Array $PrimaryArray  -ContextNames $FleetMembers.Member.Name -Name "WebApp-Dev-01").Context.Name


# Add logs volume, notice we don't have to give it a name...all preset configurations will be applied to this volume using the workload configuration/
New-Pfa2Volume -Array $PrimaryArray `
    -ContextNames $bronzeContext `
    -Provisioned 100GB `
    -WorkloadName "WebApp-Dev-01" `
    -WorkloadConfiguration 'Bronze-Vol'


# The volume is added to the workload
Get-Pfa2Volume -Array $PrimaryArray -ContextNames $bronzeContext -Filter "workload.name='WebApp-Dev-01'" | Format-Table -AutoSize


# Which also adds it to the protection group
$PGNames = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name -Filter "workload.name='WebApp-Dev-01'"
$PGNames | Format-Table -AutoSize


# Here is a listing of the volumes now in the protection group
Get-Pfa2ProtectionGroupVolume -Array $PrimaryArray -ContextNames $bronzeContext -GroupName $PGNames.Name | Format-Table -AutoSize


# The new volume is also added to the volume group, which means the QoS policy will apply
$VGNames = Get-Pfa2VolumeGroup -Array $PrimaryArray -ContextNames $bronzeContext -Filter "workload.name='WebApp-Dev-01'" 
$VGNames


# Here is a listing of the volumes in the volume group, including our newly added one
Get-Pfa2VolumeGroupVolume -Array $PrimaryArray -ContextNames $bronzeContext -GroupName $VGNames.Name | Format-List




# 2. Silver Workload - Let placement engine decide (will go to X array)
Write-Output "`nCreating Silver tier workload..."
$SilverWorkload = @{
    Array        = $PrimaryArray
    ContextNames = $FleetMembers.Member.Name | Where-Object { $_ -eq 'sn1-x90r2-f06-27' }
    Name         = "Database-Prod-01"
    PresetNames  = @("fsa-lab-fleet1:Compute-Silver-WithRepl")
}

New-Pfa2Workload @SilverWorkload




# 3. Gold Workload - Create first, then add volumes
Write-Output "`nCreating Gold tier workload..."
$GoldWorkload = @{
    Array        = $PrimaryArray
    ContextNames = ($FleetMembers.Member.Name | Where-Object { $_ -eq 'sn1-x90r2-f06-33' })
    Name         = "Analytics-Critical-01"
    PresetNames  = @("fsa-lab-fleet1:Compute-Gold-WithRepl")
}

New-Pfa2Workload @GoldWorkload



# ===============================================
# DEMONSTRATE FLEET-WIDE VOLUME VIEW
# ===============================================

Write-Output "`nFleet-wide view of all workload volumes:"
Get-Pfa2Volume -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name -Filter "workload.name='WebApp*' or workload.name='Database-*' or workload.name='Analytics-*'" |
    Select-Object Name, 
                  @{N='Array';E={$_.Context.Name}}, 
                  @{N='Size(GB)';E={[math]::Round($_.Provisioned/1GB,2)}}, 
                  @{N='Workload';E={$_.Workload.Name}},
                  @{N='VolumeConfig';E={$_.Workload._Configuration}} |
    Sort-Object Name |
    Format-Table -AutoSize

# ===============================================
# OPTIONAL: CLEANUP DEMONSTRATION WORKLOADS
# ===============================================

<#
# To remove the demonstration workloads:
$demoWorkloads = @("WebApp-Dev-01", "Database-Prod-01", "Analytics-Critical-01")

foreach ($workloadName in $demoWorkloads) {
    $contextName = (Get-Pfa2Workload -Array $PrimaryArray -Name $workloadName -ContextNames $FleetMembers.Member.Name).Context.Name
    Remove-Pfa2Workload -Array $PrimaryArray -Name $workloadName -ContextNames $contextName
    Write-Output "Removed workload: $workloadName"
}

# Wait for soft deletion
Start-Sleep -Seconds 5

# Eradicate the workloads
foreach ($workloadName in $demoWorkloads) {
    $contextName = (Get-Pfa2Workload -Array $PrimaryArray -Name $workloadName -ContextNames $FleetMembers.Member.Name -Destroyed $true).Context.Name
    Remove-Pfa2Workload -Array $PrimaryArray -Name $workloadName -ContextNames $contextName -Eradicate -Confirm:$false
    Write-Output "Eradicated workload: $workloadName"
}

# Remove all of the created presets
$createdPresets = @("Compute-Bronze-NoRepl", "Compute-Silver-WithRepl", "Compute-Gold-WithRepl", "Compute-Gold-NoRepl","Compute-Silver-NoRepl")

foreach ($presetName in $createdPresets) {
    Remove-Pfa2PresetWorkload -Array $PrimaryArray -Name $presetName -Context 'fsa-lab-fleet1'
    Write-Output "Removed preset: $presetName"
}
#>
