# ===============================================
# FLEET-WIDE MANAGEMENT DEMONSTRATION
# ===============================================
# Fusion enables management across all arrays in the fleet from a single connection
# This eliminates the need to connect to each array individually
$ArrayName = 'sn1-x90r2-f06-27.puretec.purestorage.com'    
$Credential = Import-CliXml -Path "$HOME\FA_Cred.xml"
$FlashArray = Connect-Pfa2Array -EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError -Verbose



# Connect to our Fusion-enabled FlashArray and get a listing of all of the members of our fleet
Get-Pfa2FleetMember -Array $FlashArray 


# Get all fleet members. The FlashBlade (sn1-s200-c09-33) is excluded as it uses different object types
$FleetMembers = Get-Pfa2FleetMember -Array $FlashArray -Filter "Member.Name!='sn1-s200-c09-33'"
$FleetMembers.Member.Name


# List all arrays in the fleet by connecting to each array and running the cmdlet Get-Pfa2Array
Get-Pfa2Array -Array $FlashArray -ContextNames $FleetMembers.Member.Name | Format-List


# List existing snapshots for the protection group, this listing is all of the snapshots from THIS FlashArray
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Filter "name='$($PGName.Name)*'" -Sort "created-"


# Search the entire fleet for protection group snapshots
# The ContextNames parameter enables fleet-wide queries
# These snapshots are from any protection group snapshot, not just the ones managed by our fusion created workloads.
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Filter "name='*sql*'" -Sort "created-" -Limit 10 | 
    Format-Table -AutoSize

# But we cannot do array side filtering using sort...
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames $FleetMembers.Member.Name -Filter "name='*sql*'" -Limit 10 | 
    Format-Table -AutoSize

# ===============================================
# INDIVIDUAL ARRAY QUERIES (FOR COMPARISON)
# ===============================================
# These commands show how to query specific arrays in the fleet
# Useful when you need to isolate operations to a single array

# Query snapshots on the C60 array (typically used for dev/test)
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[0].Member.Name)" -Limit 10  -Sort "created-" -Verbose |
    Format-Table -AutoSize


# Query snapshots on the primary X90 array
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[1].Member.Name)" -Limit 10 -Sort "created-" | 
    Format-Table -AutoSize


# Query snapshots on the secondary X90 array
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -ContextNames "$($FleetMembers[2].Member.Name)" -Limit 10 -Sort "created-" | 
    Format-Table -AutoSize


# ===============================================
# CROSS-ARRAY WORKLOAD DEPLOYMENT
# ===============================================
# Deploy a workload on a different array (if connected)
# This demonstrates Fusion's ability to manage workloads regardless of which array you're connected to
# The scope of the preset is the whole fleet

$workloadParams1 = @{
    Array        = $FlashArray
    ContextNames = ($FleetMembers.Member.Name) | Where-Object { $_ -eq 'sn1-x90r2-f06-33' }
    Name         = "Production-SQL-03"
    PresetNames  = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}

New-Pfa2Workload @workloadParams1

# Create another workload with the same name in a different context
$workloadParams2 = @{
    Array        = $FlashArray
    ContextNames = ($FleetMembers.Member.Name) | Where-Object { $_ -eq 'sn1-x90r2-f06-27' }
    Name         = "Production-SQL-03"
    PresetNames  = @("fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized")
}

New-Pfa2Workload @workloadParams2

# Get all workloads across all arrays using the SQL Server preset
Get-Pfa2Workload -Array $FlashArray -ContextNames $FleetMembers.Member.Name | 
    Where-Object { $_.Preset.Name -eq 'fsa-lab-fleet1:SQL-Server-MultiDisk-Optimized' } | Sort-Object -Property Name | Format-Table -AutoSize


# Query all arrays in the fleet for protection groups associated with our workload
# This returns both local snapshot PGs on all arrays in our fleet
$PGNames = Get-Pfa2ProtectionGroup -Array $PrimaryArray -ContextNames $FleetMembers.Member.Name -Filter "workload.name='Production-SQL-03'"
$PGNames | Format-Table -AutoSize



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


# Remove workloads by finding the workloads array, then using remote execution to remove the workload from that array
$SQLInstances = @("Production-SQL-02", "DR-SQL-01", "Test-SQL-01", "Dev-SQL-01")

foreach ($instance in $SQLInstances) {
    $ContextName = (Get-Pfa2Workload -Array $FlashArray -Name $instance -ContextNames $FleetMembers.Member.Name).Context.Name
    Write-output "Context for $instance is $ContextName"

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

