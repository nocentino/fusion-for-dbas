# ===============================================
# PRESET 1: Kubernetes Persistent Volume Template
# ===============================================
$k8sPreset = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Kubernetes-PVC-Dynamic"
    Description                                     = "Dynamic persistent volume claims for Kubernetes with auto-scaling support"
    WorkloadType                                    = "container"

    # QoS for container workloads - balanced performance
    QosConfigurationsName                           = @("Container-Balanced", "Container-Burst")
    QosConfigurationsIopsLimit                      = @("20000", "50000")
    QosConfigurationsBandwidthLimit                 = @("1000000000", "2000000000")  # 1GB/s, 2GB/s

    # Placement for different storage classes
    PlacementConfigurationsName                     = @("Fast-SSD", "Standard-SSD")
    PlacementConfigurationsQosConfigurations        = @(@("Container-Burst"), @("Container-Balanced"))
    PlacementConfigurationsStorageClassName         = @("flasharray-x", "flasharray-c")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes", "storage-classes")

    # Frequent snapshots for container recovery
    SnapshotConfigurationsName                      = @("Container-Snapshots")
    SnapshotConfigurationsRulesEvery                = @("300000")        # 5 minutes
    SnapshotConfigurationsRulesKeepFor              = @("86400000")      # 24 hours

    # Volume configurations for different PVC types
    VolumeConfigurationsName                        = @("App-Data", "Config-Maps", "Scratch-Space")
    VolumeConfigurationsCount                       = @("10", "5", "3")  # Multiple volumes per type
    VolumeConfigurationsPlacementConfigurations     = @(@("Fast-SSD"), @("Standard-SSD"), @("Standard-SSD"))
    VolumeConfigurationsProvisionedSize             = @(100GB, 10GB, 500GB)
    VolumeConfigurationsSnapshotConfigurations      = @(@("Container-Snapshots"), @("Container-Snapshots"), @())

    WorkloadTagsKey                                 = @("orchestrator", "namespace", "storage-class", "auto-scale")
    WorkloadTagsValue                               = @("kubernetes", "production", "premium", "enabled")
}

Write-Host "Creating Kubernetes PVC preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @k8sPreset -Verbose


# ===============================================
# PRESET 2: AI/ML Training Dataset Template
# ===============================================
$aimlPreset = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "AI-ML-Training-Optimized"
    Description                                     = "High-throughput storage for AI/ML training datasets with checkpoint support"
    WorkloadType                                    = "analytics"

    # High bandwidth QoS for data ingestion
    QosConfigurationsName                           = @("ML-Training", "ML-Inference")
    QosConfigurationsBandwidthLimit                 = @("10000000000", "5000000000")  # 10GB/s, 5GB/s
    QosConfigurationsIopsLimit                      = @("100000", "50000")

    # Placement optimized for sequential access
    PlacementConfigurationsName                     = @("ML-HighBandwidth")
    PlacementConfigurationsQosConfigurations        = @(@("ML-Training", "ML-Inference"))
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")

    # Checkpoint snapshots for model training
    SnapshotConfigurationsName                      = @("Training-Checkpoints", "Daily-Backup")
    SnapshotConfigurationsRulesEvery                = @("3600000", "86400000")      # 1 hour, 24 hours
    SnapshotConfigurationsRulesKeepFor              = @("604800000", "2592000000")  # 7 days, 30 days

    # Volumes for different ML workflow stages
    VolumeConfigurationsName                        = @("Raw-Datasets", "Processed-Data", "Model-Checkpoints", "Training-Scratch")
    VolumeConfigurationsCount                       = @("1", "1", "1", "1")
    VolumeConfigurationsPlacementConfigurations     = @(@("ML-HighBandwidth"), @("ML-HighBandwidth"), @("ML-HighBandwidth"), @("ML-HighBandwidth"))
    VolumeConfigurationsProvisionedSize             = @(50TB, 20TB, 5TB, 10TB)
    VolumeConfigurationsSnapshotConfigurations      = @(@("Daily-Backup"), @("Daily-Backup"), @("Training-Checkpoints"), @())

    WorkloadTagsKey                                 = @("workload-type", "framework", "gpu-optimized", "data-pipeline")
    WorkloadTagsValue                               = @("ml-training", "tensorflow", "true", "active")
}

Write-Host "Creating AI/ML Training preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @aimlPreset -Verbose


# ===============================================
# PRESET 3: VDI Gold Image Template
# ===============================================
$vdiPreset = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "VDI-Gold-Image-Pool"
    Description                                     = "Virtual Desktop Infrastructure with linked clones and user profile storage"
    WorkloadType                                    = "virtualization"

    # Mixed QoS for boot storms and steady state
    QosConfigurationsName                           = @("VDI-BootStorm", "VDI-SteadyState")
    QosConfigurationsIopsLimit                      = @("80000", "30000")
    QosConfigurationsBandwidthLimit                 = @("2000000000", "500000000")  # 2GB/s, 500MB/s

    # Placement configurations
    PlacementConfigurationsName                     = @("VDI-Performance")
    PlacementConfigurationsQosConfigurations        = @(@("VDI-BootStorm", "VDI-SteadyState"))
    PlacementConfigurationsStorageClassName         = @("flasharray-x")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes")

    # Snapshot policies for different purposes
    SnapshotConfigurationsName                      = @("Hourly-Snapshot", "Daily-Gold-Image")
    SnapshotConfigurationsRulesEvery                = @("3600000", "86400000")       # 1 hour, 24 hours
    SnapshotConfigurationsRulesKeepFor              = @("86400000", "604800000")     # 24 hours, 7 days

    # Volume configurations for VDI components
    VolumeConfigurationsName                        = @("Gold-Images", "User-Profiles", "App-Layers", "Temp-Data")
    VolumeConfigurationsCount                       = @("5", "1", "3", "1")  # Multiple gold images
    VolumeConfigurationsPlacementConfigurations     = @(@("VDI-Performance"), @("VDI-Performance"), @("VDI-Performance"), @("VDI-Performance"))
    VolumeConfigurationsProvisionedSize             = @(100GB, 10TB, 500GB, 2TB)
    VolumeConfigurationsSnapshotConfigurations      = @(@("Daily-Gold-Image"), @("Hourly-Snapshot"), @("Daily-Gold-Image"), @())

    WorkloadTagsKey                                 = @("vdi-type", "user-count", "profile-type", "dedup-friendly")
    WorkloadTagsValue                               = @("horizon", "1000", "persistent", "true")
}

Write-Host "Creating VDI Gold Image preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @vdiPreset -Verbose


# ===============================================
# PRESET 4: DevOps CI/CD Pipeline Storage
# ===============================================
$devopsPreset = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "DevOps-CICD-Pipeline"
    Description                                     = "Storage optimized for CI/CD pipelines with artifact repository and build caches"
    WorkloadType                                    = "development"

    # QoS for different pipeline stages
    QosConfigurationsName                           = @("Build-Performance", "Artifact-Storage")
    QosConfigurationsIopsLimit                      = @("40000", "20000")
    QosConfigurationsBandwidthLimit                 = @("1500000000", "800000000")  # 1.5GB/s, 800MB/s

    # Placement configurations
    PlacementConfigurationsName                     = @("CICD-Fast", "CICD-Standard")
    PlacementConfigurationsQosConfigurations        = @(@("Build-Performance"), @("Artifact-Storage"))
    PlacementConfigurationsStorageClassName         = @("flasharray-x", "flasharray-c")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes", "storage-classes")

    # Snapshot for build artifacts and rollback
    SnapshotConfigurationsName                      = @("Build-Snapshots", "Release-Archive")
    SnapshotConfigurationsRulesEvery                = @("1800000", "86400000")      # 30 min, 24 hours
    SnapshotConfigurationsRulesKeepFor              = @("259200000", "31536000000") # 3 days, 365 days

    # Volumes for CI/CD workflow
    VolumeConfigurationsName                        = @("Source-Repos", "Build-Cache", "Artifacts", "Container-Registry")
    VolumeConfigurationsCount                       = @("1", "1", "1", "1")
    VolumeConfigurationsPlacementConfigurations     = @(@("CICD-Standard"), @("CICD-Fast"), @("CICD-Standard"), @("CICD-Standard"))
    VolumeConfigurationsProvisionedSize             = @(2TB, 1TB, 5TB, 3TB)
    VolumeConfigurationsSnapshotConfigurations      = @(@("Release-Archive"), @("Build-Snapshots"), @("Release-Archive"), @("Release-Archive"))

    WorkloadTagsKey                                 = @("pipeline-type", "tools", "team", "retention-policy")
    WorkloadTagsValue                               = @("jenkins", "docker-gradle-npm", "platform-engineering", "automated")
}

Write-Host "Creating DevOps CI/CD preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @devopsPreset -Verbose


# ===============================================
# PRESET 5: Healthcare PACS Imaging System
# ===============================================
$healthcarePreset = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Healthcare-PACS-Compliant"
    Description                                     = "HIPAA-compliant medical imaging storage with long-term retention"
    WorkloadType                                    = "healthcare"

    # QoS for medical imaging workloads
    QosConfigurationsName                           = @("PACS-Primary", "PACS-Archive")
    QosConfigurationsIopsLimit                      = @("60000", "10000")
    QosConfigurationsBandwidthLimit                 = @("3000000000", "500000000")  # 3GB/s, 500MB/s

    # Placement with compliance considerations
    PlacementConfigurationsName                     = @("PACS-Tier1", "PACS-Archive")
    PlacementConfigurationsQosConfigurations        = @(@("PACS-Primary"), @("PACS-Archive"))
    PlacementConfigurationsStorageClassName         = @("flasharray-x", "flasharray-c")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes", "storage-classes")

    # Compliance snapshots - immutable for regulatory requirements
    SnapshotConfigurationsName                      = @("Hourly-Compliance", "Daily-Legal-Hold", "Monthly-Archive")
    SnapshotConfigurationsRulesEvery                = @("3600000", "86400000", "2592000000")        # 1hr, 24hr, 30days
    SnapshotConfigurationsRulesKeepFor              = @("604800000", "63072000000", "220752000000") # 7days, 2yrs, 7yrs

    # Volumes for PACS components
    VolumeConfigurationsName                        = @("DICOM-Active", "Patient-Records", "Archive-Tier1", "Audit-Logs")
    VolumeConfigurationsCount                       = @("1", "1", "1", "1")
    VolumeConfigurationsPlacementConfigurations     = @(@("PACS-Tier1"), @("PACS-Tier1"), @("PACS-Archive"), @("PACS-Tier1"))
    VolumeConfigurationsProvisionedSize             = @(20TB, 5TB, 100TB, 1TB)
    VolumeConfigurationsSnapshotConfigurations      = @(
        @("Hourly-Compliance", "Daily-Legal-Hold"),
        @("Hourly-Compliance", "Daily-Legal-Hold", "Monthly-Archive"),
        @("Daily-Legal-Hold", "Monthly-Archive"),
        @("Daily-Legal-Hold", "Monthly-Archive")
    )

    WorkloadTagsKey                                 = @("compliance", "data-type", "retention-years", "encryption", "audit-enabled")
    WorkloadTagsValue                               = @("hipaa", "medical-imaging", "7", "aes-256", "true")
}

Write-Host "Creating Healthcare PACS preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @healthcarePreset -Verbose


# ===============================================
# PRESET 6: Real-time Analytics Data Lake
# ===============================================
$realtimeAnalyticsPreset = @{
    Array                                           = $FlashArray
    ContextNames                                    = 'fsa-lab-fleet1'
    Name                                            = "Realtime-Analytics-DataLake"
    Description                                     = "High-performance data lake for real-time analytics with Kafka/Spark integration"
    WorkloadType                                    = "analytics"

    # QoS optimized for streaming and batch
    QosConfigurationsName                           = @("Streaming-Ingest", "Batch-Process", "Query-Service")
    QosConfigurationsIopsLimit                      = @("100000", "80000", "60000")
    QosConfigurationsBandwidthLimit                 = @("5000000000", "4000000000", "3000000000")  # 5GB/s, 4GB/s, 3GB/s

    # Placement for hot/warm/cold data
    PlacementConfigurationsName                     = @("Hot-Data", "Warm-Data")
    PlacementConfigurationsQosConfigurations        = @(@("Streaming-Ingest", "Query-Service"), @("Batch-Process"))
    PlacementConfigurationsStorageClassName         = @("flasharray-x", "flasharray-c")
    PlacementConfigurationsStorageClassResourceType = @("storage-classes", "storage-classes")

    # Snapshot policies for data lifecycle
    SnapshotConfigurationsName                      = @("Streaming-Checkpoint", "Daily-Partition")
    SnapshotConfigurationsRulesEvery                = @("900000", "86400000")       # 15 min, 24 hours
    SnapshotConfigurationsRulesKeepFor              = @("86400000", "2592000000")   # 24 hours, 30 days

    # Volumes for data lake tiers
    VolumeConfigurationsName                        = @("Kafka-Logs", "Spark-Shuffle", "Parquet-Store", "Query-Cache")
    VolumeConfigurationsCount                       = @("3", "1", "1", "1")  # Multiple Kafka partitions
    VolumeConfigurationsPlacementConfigurations     = @(@("Hot-Data"), @("Hot-Data"), @("Warm-Data"), @("Hot-Data"))
    VolumeConfigurationsProvisionedSize             = @(5TB, 10TB, 50TB, 2TB)
    VolumeConfigurationsSnapshotConfigurations      = @(@("Streaming-Checkpoint"), @(), @("Daily-Partition"), @())

    WorkloadTagsKey                                 = @("analytics-engine", "data-format", "partition-strategy", "compression")
    WorkloadTagsValue                               = @("kafka-spark", "parquet-orc", "time-based", "snappy")
}

Write-Host "Creating Real-time Analytics preset..." -ForegroundColor Green
New-Pfa2PresetWorkload @realtimeAnalyticsPreset -Verbose


# ===============================================
# List all created presets
# ===============================================
Write-Host "`n`nListing all Fleet Workload Presets:" -ForegroundColor Cyan
Get-Pfa2PresetWorkload -Array $FlashArray -ContextNames 'fsa-lab-fleet1' | 
    Select-Object Name, WorkloadType, Description | 
    Format-Table -AutoSize -Wrap