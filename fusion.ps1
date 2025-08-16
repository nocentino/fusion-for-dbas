#$ArrayName = 'sn1-x90r2-f06-33.puretec.purestorage.com'
#$ArrayName = 'sn1-c60-e12-16.puretec.purestorage.com'
$ArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$FlashArray = Connect-Pfa2Array –EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError



# Get all available Fleet-related PowerShell cmdlets
Get-Command -Module PureStoragePowerShellSDK2 -Noun '*Fleet*'




# Get all available Workload and Preset-related PowerShell cmdlets
Get-Command -Module PureStoragePowerShellSDK2 -Noun '*Workload*'




# Get fleet membership - shows all arrays that are part of this Fusion fleet
$FleetInfo = Get-Pfa2FleetMember -Array $FlashArray 
$FleetInfo.Member.Name 



# Example: Database with Data, Log, TempDB, and System volumes
$presetParams = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1' #needs to be the fleet name when creating a fleet-wide object like a preset
    Name                                            = "SQL-Server-MultiDisk-Optimized"
    Description                                     = "SQL Server optimized preset with different volumes for Data, Log, TempDB, and System"
    WorkloadType                                    = "database"

    
    # Different QoS configurations for the whole preset
    QosConfigurationsName                           = @("Sql-QoS")
    QosConfigurationsIopsLimit                      = @("75000")


    # Different placement configurations
    PlacementConfigurationsName                     = @("Data-Placement")
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")
    PlacementConfigurationsQosConfigurations        = @(@("Sql-QoS"))


    # SQL Server volume configuration with different sizes and characteristics
    VolumeConfigurationsName                        = @("SQL-Data", "SQL-Log", "SQL-TempDB", "SQL-System")
    VolumeConfigurationsCount                       = @("1", "1", "1", "1")
    VolumeConfigurationsPlacementConfigurations     = @( @("Data-Placement"), @("Data-Placement"), @("Data-Placement"), @("Data-Placement") )
    VolumeConfigurationsProvisionedSize             = @( 5TB, 1TB, 500GB, 2TB ) # Data, Log, TempDB, System volumes using powershell's native size suffixes


    # Different snapshot policies
    SnapshotConfigurationsName                      = @("Data-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("600000")        # 10min in milliseconds
    SnapshotConfigurationsRulesKeepFor              = @("604800000")     # 7days in milliseconds


    # Create a snapshot configuration for all volumes. TempDB volume excluded from snapshot configurations
    VolumeConfigurationsSnapshotConfigurations      = @(
        @("Data-Snapshots"),   # Data volume gets snapshots
        @("Data-Snapshots"),   # Log volume gets snapshots
        @(),                   # TempDB volume gets NO snapshots (empty array)
        @("Data-Snapshots")    # System volume gets snapshots
    )


    # Workload tags for identification
    WorkloadTagsKey                                 = @("database-type", "application", "tier", "backup-required")
    WorkloadTagsValue                               = @("sql-server", "enterprise-app", "production", "true")
}
Write-Host "Creating SQL Server optimized multi-disk preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @presetParams

# Get the newly created workload -- the -Filter parameter is missing from this cmdlet
Get-Pfa2PresetWorkload -Array $FlashArray | Where-Object { $_.Name -like "fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized" } | Format-List


# ===============================================
# CREATE NEW WORKLOAD FROM SQL SERVER PRESET
# ===============================================


# Example 1: Create Production SQL Server Workload
$workloadParams1 = @{
    Array                                           = $FlashArray
    Name                                            = "Production-SQL-01"
    PresetNames                                     = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}

New-Pfa2Workload @workloadParams1


# Get the newly created workload -- the -Filter parameter is missing from this cmdlet
Get-Pfa2Workload -Array $FlashArray | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Format-Table -AutoSize


# Get the volume group and volume information for the new workload
Get-Pfa2VolumeGroup -Array $FlashArray -Filter "workload.name='Production-SQL-01'"
Get-Pfa2Volume      -Array $FlashArray -Filter "workload.name='Production-SQL-01'"



# Get the protection group for the new workload
$PGName = Get-Pfa2ProtectionGroup -Array $FlashArray -Filter "workload.name='Production-SQL-01'"
$PGName



# Get the snapshots for the protection group
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Filter "name='$($PGName.Name)*'"



# So we just did all that work on one array in the fleet. Now let's see how we can manage the fleet as a whole.
# We're gonna connect to another array and communicate with the fleet from there and get access to the workload we just created.


# Get a listing of all of the members of the fleet
$FleetMembers = Get-Pfa2FleetMember -Array $FlashArray -Filter "Member.Name!='sn1-s200-c09-33'"  # Exclude the FlashBlade 
$FleetMembers.Member.Name



# Search the entire fleet for the protection group snapshots for the workload we just created
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Filter "name='$($PGName.Name)*'" -Limit 10 
    | Format-Table -AutoSize




# Here we're logging into each array individually and getting the snapshots for any protection groups on that array
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[0].Member.Name)" -Limit 10 #sn1-c60-e12-1
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[1].Member.Name)" -Limit 10 #sn1-x90r2-f06-27
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[2].Member.Name)" -Limit 10 #sn1-x90r2-f06-33




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

# Get the newly created workloads -- the -Filter parameter is missing from this cmdlet
Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Format-Table -AutoSize



# Create a workload on another array
$workloadParams2 = @{
    Array                                           = $AnotherFlashArray
    Name                                            = "Production-SQL-02"
    PresetNames                                     = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}

New-Pfa2Workload @workloadParams2


#Remove the resources created
Remove-Pfa2Workload -Array $FlashArray -Name "Production-SQL-01"
Remove-Pfa2Workload -Array $FlashArray -Name "Production-SQL-02"
Remove-Pfa2PresetWorkload -Array $FlashArray -ContextNames 'fsa-lab-fleet1' -Name "SQL-Server-MultiDisk-Optimized" 




# **Cross-Array Replication**: Configuring periodic replication between arrays in your Fleet for disaster recovery and data mobility

# **Using Fusion for Remote Command Execution**: Fusion allows for remote command execution across all objects in your fleet rather than just per array.

# **Building a Global Snapshot Catalog**: Using tags combined with Fusion's fleet-wide scope, you can find and consume a snapshot anywhere in your Fleet

# **Updating Workload Presets**: How to modify existing Presets and handle versioning as your requirements evolve

# **Finding Configuration Skew**: Use PowerShell to find configuration skew in your environment

# **Fleet-Wide Monitoring**: Gathering performance metrics and capacity data across all arrays from a single control point

# **Advanced Placement Strategies**: Using Workload placement recommendations to optimize resource utilization across your Fleet