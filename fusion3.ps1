# ===============================================
# DEMO 1: Fleet-Wide Storage Efficiency Dashboard
# ===============================================
# Get space metrics for all arrays at once
$fleetSpace = Get-Pfa2ArraySpace -Array $FlashArray -ContextNames $FleetMembers.Member.Name

# Create efficiency dashboard
$efficiencyDashboard = $fleetSpace | ForEach-Object {
    # Calculate available space (assuming Capacity - TotalUsed)
    $totalCapacity = $_.Capacity
    $usedSpace = $_.Space.TotalUsed
    $availableSpace = $totalCapacity - $usedSpace
    
    # Prevent division by zero
    $availablePercent = if ($totalCapacity -gt 0) {
        [math]::Round(($availableSpace / $totalCapacity) * 100, 2)
    } else { 0 }
    
    $efficiencyScore = if ($totalCapacity -gt 0) {
        [math]::Round($_.Space.DataReduction * ($availableSpace / $totalCapacity) * 100, 2)
    } else { 0 }
    
    [PSCustomObject]@{
        Array = $_.Name
        DataReduction = [math]::Round($_.Space.DataReduction, 2)
        TotalCapacityTB = [math]::Round($totalCapacity / 1TB, 2)
        UsedCapacityTB = [math]::Round($usedSpace / 1TB, 2)
        AvailablePercent = $availablePercent
        EfficiencyScore = $efficiencyScore
    }
}

$efficiencyDashboard | Sort-Object EfficiencyScore -Descending | Format-Table -AutoSize


# ===============================================
# DEMO 2: Fleet-Wide Volume Inventory
# ===============================================
# Get all volumes across the entire fleet in one call
$fleetVolumes = Get-Pfa2Volume -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Limit 1000

# Analyze volume distribution
$volumeAnalysis = $fleetVolumes | Group-Object { $_.Name.Split(':')[0] } | ForEach-Object {
    $arrayVolumes = $_.Group
    [PSCustomObject]@{
        Array = $_.Name
        VolumeCount = $arrayVolumes.Count
        TotalProvisionedTB = [math]::Round(($arrayVolumes.Space.Total | Measure-Object -Sum).Sum / 1TB, 2)
        AverageVolumeSizeTB = [math]::Round(($arrayVolumes.Space.Total | Measure-Object -Average).Average / 1TB, 2)
        ProtectedVolumes = ($arrayVolumes | Where-Object { $_.ProtectionGroup }).Count
        UnprotectedVolumes = ($arrayVolumes | Where-Object { -not $_.ProtectionGroup }).Count
    }
}

Write-Host "`nFleet-Wide Volume Distribution:" -ForegroundColor Cyan
$volumeAnalysis | Format-Table -AutoSize


# ===============================================
# DEMO 3: Fleet-Wide Protection Group Snapshots
# ===============================================
# Get all protection group snapshots across the fleet
$fleetSnapshots = Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Sort "created-" -Limit 100

# Analyze snapshot patterns
$snapshotSummary = $fleetSnapshots | Group-Object { $_.Name.Split(':')[0] } | ForEach-Object {
    [PSCustomObject]@{
        Array = $_.Name
        TotalSnapshots = $_.Count
        OldestSnapshot = ($_.Group | Sort-Object Created | Select-Object -First 1).Created
        NewestSnapshot = ($_.Group | Sort-Object Created -Descending | Select-Object -First 1).Created
        TotalSpaceGB = [math]::Round(($_.Group.Space.TotalReduction | Measure-Object -Sum).Sum / 1GB, 2)
        UniqueProtectionGroups = ($_.Group.Source.Name | Sort-Object -Unique).Count
    }
}

$snapshotSummary | Format-Table -AutoSize


# ===============================================
# DEMO 4: Fleet-Wide Host Performance
# ===============================================
# Get performance metrics for all hosts across the fleet
$fleetHostPerf = Get-Pfa2HostPerformance -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Limit 1

# Find top performers across the entire fleet
$topPerformers = $fleetHostPerf | Sort-Object Iops -Descending | Select-Object -First 20 | ForEach-Object {
    [PSCustomObject]@{
        Array = $_.Name.Split(':')[0]
        Host = $_.Name.Split(':')[1]
        IOPS = "{0:N0}" -f $_.Iops
        BandwidthMBps = [math]::Round($_.BytesPerSec / 1MB, 2)
        LatencyMs = [math]::Round($_.LatencyUs / 1000, 2)
        QueueDepth = $_.QueueDepth
    }
}

Write-Host "`nTop 20 Hosts by IOPS (Fleet-Wide):" -ForegroundColor Green
$topPerformers | Format-Table -AutoSize


# ===============================================
# DEMO 5: Fleet-Wide Alert Analysis
# ===============================================
# Get all active alerts across the fleet
$fleetAlerts = Get-Pfa2Alert -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Filter "state='open'"

# Create alert summary
$alertSummary = $fleetAlerts | Group-Object ComponentType, Severity | ForEach-Object {
    [PSCustomObject]@{
        ComponentType = $_.Name.Split(',')[0].Trim()
        Severity = $_.Name.Split(',')[1].Trim()
        Count = $_.Count
        Arrays = ($_.Group.Name | ForEach-Object { $_.Split(':')[0] } | Sort-Object -Unique) -join ", "
        ExampleIssue = ($_.Group | Select-Object -First 1).Summary
    }
} | Sort-Object Severity, Count -Descending

Write-Host "`nFleet-Wide Alert Summary:" -ForegroundColor Yellow
$alertSummary | Format-Table -AutoSize -Wrap


# ===============================================
# DEMO 6: Fleet-Wide Array Performance Comparison
# ===============================================
# Get performance for all arrays
$fleetArrayPerf = Get-Pfa2ArrayPerformance -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Limit 1

# Create performance comparison
$perfComparison = $fleetArrayPerf | ForEach-Object {
    [PSCustomObject]@{
        Array = $_.Name
        TotalIOPS = "{0:N0}" -f $_.Iops
        ReadIOPS = "{0:N0}" -f $_.ReadsPerSec
        WriteIOPS = "{0:N0}" -f $_.WritesPerSec
        BandwidthMBps = [math]::Round($_.BytesPerSec / 1MB, 2)
        LatencyMs = [math]::Round($_.LatencyUs / 1000, 3)
        QueueDepth = $_.QueueDepth
        DataReduction = [math]::Round($_.DataReduction, 2)
    }
}

Write-Host "`nFleet Array Performance Comparison:" -ForegroundColor Magenta
$perfComparison | Sort-Object { [int]($_.TotalIOPS -replace ',', '') } -Descending | Format-Table -AutoSize


# ===============================================
# DEMO 7: Fleet-Wide Network Interface Status
# ===============================================
# Get all network interfaces across the fleet
$fleetInterfaces = Get-Pfa2NetworkInterface -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Filter "enabled='true'"

# Summarize by service type
$interfaceSummary = $fleetInterfaces | Group-Object { ($_.Services -join ",") } | ForEach-Object {
    [PSCustomObject]@{
        ServiceType = $_.Name
        InterfaceCount = $_.Count
        Arrays = ($_.Group.Name | ForEach-Object { $_.Split(':')[0] } | Sort-Object -Unique).Count
        Examples = ($_.Group | Select-Object -First 3).Name -join ", "
    }
}

Write-Host "`nFleet Network Interface Summary:" -ForegroundColor Cyan
$interfaceSummary | Format-Table -AutoSize -Wrap


# ===============================================
# DEMO 8: Fleet-Wide Workload Distribution
# ===============================================
# Get all workloads across the fleet
$fleetWorkloads = Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name

# Analyze workload distribution by preset
$workloadDistribution = $fleetWorkloads | Group-Object { $_.Preset.Name } | ForEach-Object {
    $workloads = $_.Group
    [PSCustomObject]@{
        PresetName = $_.Name
        WorkloadCount = $workloads.Count
        Arrays = ($workloads.Name | ForEach-Object { $_.Split(':')[0] } | Sort-Object -Unique) -join ", "
        WorkloadNames = ($workloads.Name | ForEach-Object { $_.Split(':')[1] }) -join ", "
        TotalVolumes = ($workloads.VolumeCount | Measure-Object -Sum).Sum
    }
}

Write-Host "`nFleet-Wide Workload Distribution:" -ForegroundColor Green
$workloadDistribution | Format-Table -AutoSize -Wrap


# ===============================================
# DEMO 9: Fleet-Wide Protection Group Health
# ===============================================
# Get all protection groups with their replication status
$fleetPGs = Get-Pfa2ProtectionGroup -Array $FlashArray -ContextNames $FleetMembers.Member.Name

# Analyze protection group health
$pgHealth = $fleetPGs | ForEach-Object {
    [PSCustomObject]@{
        Array = $_.Name.Split(':')[0]
        ProtectionGroup = $_.Name.Split(':')[1]
        SnapshotCount = $_.SnapshotCount
        ReplicationEnabled = $_.ReplicationEnabled
        TargetCount = $_.Targets.Count
        MemberVolumes = $_.MemberVolumes.Count
        LastSnapshot = $_.TimeRemaining
    }
} | Sort-Object Array, ProtectionGroup

Write-Host "`nFleet Protection Group Health Check:" -ForegroundColor Yellow
$pgHealth | Where-Object { $_.SnapshotCount -eq 0 -or -not $_.ReplicationEnabled } | Format-Table -AutoSize