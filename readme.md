# Pure Storage Fusion for DBAs

A collection of PowerShell scripts demonstrating Pure Storage Fusion capabilities for database administrators, focusing on SQL Server workload management across FlashArray fleets.

## Overview

This repository provides practical examples of using Pure Storage Fusion to:
- Create and manage standardized storage configurations (presets) for SQL Server
- Deploy consistent workloads across multiple arrays in a fleet
- Configure cross-array replication for disaster recovery
- Implement storage best practices for SQL Server environments

## Prerequisites

- Pure Storage PowerShell SDK 2.x (`PureStoragePowerShellSDK2` module)
- Access to a Pure Storage FlashArray fleet with Fusion enabled
- PowerShell 5.1 or later
- Stored credentials file (`$HOME\FA_Cred.xml`)

## Repository Structure

```
.
├── 1-fusion-gettingstarted.ps1    # Introduction to Fusion workload management
├── 2-fusion-replication.ps1       # Cross-array replication configuration
└── docs/
    ├── help.txt                   # PowerShell cmdlet documentation
    └── swagger.json               # Pure Storage REST API reference
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

### 2. Replication Configuration ([2-fusion-replication.ps1](2-fusion-replication.ps1))

This script covers advanced disaster recovery scenarios:

- **Cross-array Replication**: Setting up periodic replication between arrays
- **Selective Replication**: Excluding TempDB from replication (can be recreated)
- **REST API Usage**: Alternative preset creation using REST API
- **DR Tags**: Adding metadata for DR priority and RPO tracking

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

### SQL Server Best Practices
The scripts implement storage best practices for SQL Server:
- Separation of Data, Log, TempDB, and System files
- Appropriate sizing for each volume type
- Performance isolation with QoS
- Automated snapshot protection
- Cross-array replication for DR

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

## Advanced Topics

The scripts mention several advanced topics for future exploration:
- Remote command execution across fleets
- Building global snapshot catalogs
- Updating existing presets and versioning
- Expanding running workloads
- Finding configuration skew
- Fleet-wide monitoring and capacity planning
- Advanced placement strategies

## Important Notes

- Always test in non-production environments first
- The `-Eradicate` flag permanently deletes data - use with caution
- Snapshot and replication intervals are in milliseconds
- TempDB volumes are excluded from snapshots and replication by design

## Contributing

Feel free to submit issues or pull requests to improve these examples or add new scenarios.

## License

Please refer to your Pure Storage licensing agreement for usage terms.
```

This README provides a comprehensive overview of the repository, explains the key concepts, includes usage examples, and helps DBAs understand how to leverage Pure Storage Fusion for their SQL Server environments.This README provides a comprehensive overview of the repository, explains the key concepts, includes usage examples, and helps DBAs understand how to leverage Pure Storage Fusion for their SQL Server environments.