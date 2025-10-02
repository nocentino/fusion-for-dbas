# Pure Storage Fusion for DBAs

A collection of PowerShell scripts demonstrating Pure Storage Fusion capabilities for database administrators, focusing on SQL Server workload management across FlashArray fleets.

## Overview

This repository provides practical examples of using Pure Storage Fusion to:
- Create and manage standardized storage configurations (presets) for SQL Server
- Deploy consistent workloads across multiple arrays in a fleet
- Configure cross-array replication for disaster recovery
- Implement storage tiering strategies (Bronze, Silver, Gold)
- Build global snapshot catalogs for fleet-wide recovery
- Implement storage best practices for SQL Server environments

## Prerequisites

- Pure Storage PowerShell SDK 2.x (`PureStoragePowerShellSDK2` module)
- Access to a Pure Storage FlashArray fleet with Fusion enabled
- PowerShell 5.1 or later
- Stored credentials file (`$HOME\FA_Cred.xml`)

## Repository Structure

```
.
├── 1-fusion-gettingstarted.ps1           # Introduction to Fusion workload management
├── 2-fusion-fleet-wide-operations.ps1    # Fleet-wide management and operations
├── 3-fusion-replication.ps1              # Cross-array replication configuration
├── 4-StorageTiers.ps1                    # Storage tiering implementation
└── fusion-global-snapshot-catalog.ps1    # Building a global snapshot catalog
```

## Scripts Overview

### 1. Getting Started with Fusion ([1-fusion-gettingstarted.ps1](1-fusion-gettingstarted.ps1))

This script demonstrates fundamental Fusion concepts:

- **Fleet Discovery**: Connecting to arrays and discovering fleet membership
- **Preset Creation**: Building a SQL Server optimized storage preset with:
  - Separate volumes for Data (5TB), Log (1TB), TempDB (500GB), and System (2TB)
  - QoS limits (75,000 IOPS) to prevent noisy neighbor issues
  - Snapshot policies (10-minute intervals, 7-day retention)
  - Metadata tags for tracking and automation
- **Workload Deployment**: Creating SQL Server instances from presets
- **Fleet-wide Management**: Querying and managing resources across all arrays
- **Bulk Operations**: Deploying multiple workloads consistently

### 2. Fleet-wide Operations ([2-fusion-fleet-wide-operations.ps1](2-fusion-fleet-wide-operations.ps1))

This script covers fleet-wide management capabilities:

- **Single Connection Management**: Managing all arrays from one connection point
- **Fleet-wide Queries**: Searching for resources across all arrays
- **Cross-array Workload Deployment**: Creating workloads on any array in the fleet
- **Protection Group Management**: Finding and managing snapshots fleet-wide
- **Bulk Cleanup Operations**: Removing workloads and presets across arrays
- **Context-aware Operations**: Working with workloads in different array contexts

### 3. Replication Configuration ([3-fusion-replication.ps1](3-fusion-replication.ps1))

This script covers advanced disaster recovery scenarios:

- **Cross-array Replication**: Setting up periodic replication between arrays
- **Selective Replication**: Excluding TempDB from replication (can be recreated)
- **Protection Group Configuration**: Managing local and remote protection groups
- **Fleet-wide Snapshot Discovery**: Finding replicated data across arrays
- **Performance Optimization**: Efficient querying of specific target arrays
- **DR Tags**: Adding metadata for DR priority and RPO tracking

### 4. Storage Tiering ([4-StorageTiers.ps1](4-StorageTiers.ps1))

This script implements a comprehensive storage tiering strategy:

- **Bronze Tier**: 
  - Target: FlashArray C (cost-optimized)
  - QoS: 10,000 IOPS, 200 MB/s
  - Snapshots: Every 6 hours, 7-day retention
  - No replication
- **Silver Tier**: 
  - Target: FlashArray X (performance-optimized)
  - QoS: 50,000 IOPS, 1 GB/s
  - Snapshots: Every 2 hours, 14-day retention
  - Optional bi-hourly replication
- **Gold Tier**: 
  - Target: FlashArray X (performance-optimized)
  - QoS: 1M IOPS, 10 GB/s
  - Snapshots: Every 30 minutes, 30-day retention
  - Aggressive 15-minute replication

### 5. Global Snapshot Catalog ([fusion-global-snapshot-catalog.ps1](fusion-global-snapshot-catalog.ps1))

This script demonstrates advanced recovery scenarios:

- **Fleet-wide Snapshot Discovery**: Finding snapshots across all arrays
- **Metadata Tagging**: Using tags for catalog organization
- **Cross-array Recovery**: Restoring from snapshots on remote arrays
- **Workload Migration**: Moving workloads between arrays
- **Automated Recovery**: Streamlining disaster recovery processes

### 6. Workload Placement ([Untitled-2.ps1](Untitled-2.ps1))

This script shows placement recommendation features:

- **Placement Recommendations**: Using AI-driven placement suggestions
- **Resource Optimization**: Finding the best array for workload deployment
- **Capacity Planning**: Understanding placement based on available resources

## Key Concepts

### Workload Presets
Presets are templates that define:
- Volume configurations (names, sizes, counts)
- QoS policies for performance management
- Placement rules for array selection
- Snapshot schedules for local protection
- Replication policies for disaster recovery
- Metadata tags for organization

### Fleet-wide Scope
Fusion enables management of multiple arrays as a single entity:
- Deploy workloads to any array from a single connection
- Query resources across the entire fleet
- Maintain consistency with fleet-scoped presets
- Execute commands remotely on any array

### SQL Server Best Practices
The scripts implement storage best practices for SQL Server:
- Separation of Data, Log, TempDB, and System files
- Appropriate sizing for each volume type
- Performance isolation with QoS
- Automated snapshot protection
- Cross-array replication for DR
- Tiered storage for different workload requirements

## Usage Examples

### Connect to an Array
```powershell
$ArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$FlashArray = Connect-Pfa2Array -EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError
```

### Create a SQL Server Workload
```powershell
$workloadParams = @{
    Array       = $FlashArray
    Name        = "Production-SQL-01"
    PresetNames = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}
New-Pfa2Workload @workloadParams
```

### Query Fleet-wide Resources
```powershell
# Get all SQL Server workloads across the fleet
Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -match 'SQL-Server' }
```

### Deploy Tiered Storage
```powershell
# Deploy a Bronze tier workload to FlashArray C
$BronzeWorkload = @{
    Array        = $PrimaryArray
    ContextNames = 'sn1-c60-e12-16'
    Name         = "WebApp-Dev-01"
    PresetNames  = @("fsa-lab-fleet1:Compute-Bronze-NoRepl")
}
New-Pfa2Workload @BronzeWorkload
```

## Advanced Topics

The repository includes ideas for future exploration (see [blog idea.txt](blog%20idea.txt)):
- **Updating Workload Presets**: Modifying existing presets and version management
- **Resource Expansion**: Adding volumes to running workloads
- **Configuration Skew Detection**: Finding inconsistencies across the fleet
- **Fleet-wide Monitoring**: Performance metrics and capacity planning
- **Advanced Placement Strategies**: AI-driven workload placement optimization

## Important Notes

- Always test in non-production environments first
- The `-Eradicate` flag permanently deletes data - use with caution
- Snapshot and replication intervals are in milliseconds
- TempDB volumes are excluded from snapshots and replication by design
- Context-aware operations require specifying the correct array context
- Some cmdlets have known issues (e.g., type mismatches) that are being addressed

## Blog Resources

The repository includes blog posts explaining concepts in detail:
- [Managing Storage with Fusion PowerShell: Storage Tiers](https://www.nocentino.com/posts/2025-09-04-managing-storage-with-fusion-powershell-storage-tiers/)

## Contributing

Feel free to submit issues or pull requests to improve these examples or add new scenarios.

## License

Please refer to your Pure Storage licensing agreement for usage terms.