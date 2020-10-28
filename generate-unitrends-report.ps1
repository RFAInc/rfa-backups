<#
.SYNOPSIS
    This script will reach out to each Unitrends appliance configured in ADI and collect data to build a report. 
.INPUTS
    None
.OUTPUTS
    Log file stored in $LogPath
.NOTES
    Version:        1.2
    Author:         Andy Escolastico
    Creation Date:  9/11/2019
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Requires -RunAsAdministrator
# Requires -Version 5

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$LogPath = "\\rfabatch\Reports\Backups\unitrends-report_$(Get-Date -format "MM-dd-yy_HH-mm").log"
$CsvPath = "\\rfabatch\Reports\Backups\unitrends-report_$(Get-Date -format "MM-dd-yy_HH-mm").csv"
#$LogPath = "$ENV:UserProfile\Desktop\backup-report_$(Get-Date -format "MM-dd-yy_HH-mm").log"
#$CsvPath = "$ENV:UserProfile\Desktop\backup-report_$(Get-Date -format "MM-dd-yy_HH-mm").csv"

# DB queries for ADI
$UniServersQuery = "
SELECT name, url, user_name, password
FROM devices
WHERE device_type_id = 1
"
$UniAssetsQuery = "
SELECT sch.id,
    sch.backup_name, 
    cli.name AS client_name
FROM schedules AS sch
    JOIN devices AS dev ON sch.device_id = dev.id
    JOIN clients AS cli ON sch.client_id = cli.id
WHERE
    sch.is_active = 1
        AND
    dev.device_type_id = 1
"

# Array Declarations 
$AvailableUniAssets = New-Object -TypeName System.Collections.ArrayList
$AssignedUniAssets = New-Object -TypeName System.Collections.ArrayList
$FinalDataSet = New-Object -TypeName System.Collections.ArrayList

#-----------------------------------------------------------[Functions]------------------------------------------------------------
. .\unitrends-functions.ps1
. .\general-functions.ps1
. .\adi-functions.ps1
. .\credentials.ps1
#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Ignores invalid certificate errors
Skip-InvalidCertErrors

# Querys Data from ADI
$ConnectedUniServers = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBName -Query $UniServersQuery
$MonitoredUniAssets = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBName -Query $UniAssetsQuery

# Reset progress counter
$c = 0

# Querys Unitrends Appliances for Protected and Available Assets
foreach ($i in $ConnectedUniServers){
    $UniServer = (($i.url).Trim("http://")).Trim()
    $UniUser = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.user_name))
    $UniPass = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.password))
    try {
        # Connect to Unitrends server and retrieve auth token
        $AuthToken = (Get-UniSession -Server $UniServer -User $UniUser -Pass $UniPass).auth_token
        # Collect Job data
        $JobHistory = (Invoke-UniRest -Server $UniServer -AuthToken $AuthToken -Method "GET" -Endpoint "/jobs/history/backup").data
        $JobConfigs = (Invoke-UniRest -Server $UniServer -AuthToken $AuthToken -Method "GET" -Endpoint "/joborders").data
        # Add server ip and frequency datapoint to Job objects
        foreach ($i in $JobHistory) {
            $Frequency = $JobConfigs | Where-Object {$_.name -eq $i.name} | Select-Object calendar_str
            $Frequency = $Frequency.calendar_str | Where-Object {$_ -Notlike "*/*/*"}
            if (@($Frequency).Count -gt 1){
                $Frequency = $Frequency -Join "; "
            }
            $i | Add-Member -NotePropertyName "frequency" -NotePropertyValue $Frequency
            $i | Add-Member -NotePropertyName "system_ip" -NotePropertyValue $UniServer
        }
        # Add modified objects array list
        $JobHistory | ForEach-Object { 
            $null = ($AssignedUniAssets).Add($_) 
        }
        # Collect Asset-Source data
        $Sources = (Invoke-UniRest -Server $UniServer -AuthToken $AuthToken -Method "GET" -Endpoint "/assets").data
        # Build Asset Custom Objects
        $Assets = @()
        foreach ($x in $Sources) {
            foreach ($y in $x.children){
                $obj = [PSCustomObject]@{
                    Asset = $y.name
                    Source = $x.name
                }
                $Assets += $obj
            }
        }
        # Add custom objects to array list
        foreach ($i in $Assets){
            if ($i.Asset -notin $AvailableUniAssets.Asset){
                $null = ($AvailableUniAssets).Add($i) 
            }
        }
        # Output progress
        $c++ 
        Write-Progress -Activity "Collecting data from Unitrends devices..." -Status "Units Queried: $c of $($ConnectedUniServers.Count)" -PercentComplete (($c / $ConnectedUniServers.Count) * 100)
        
    } catch {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format HH:mm)`: Could not connect to $UniServer. Check Credentials."
        Write-Output "Could not connect to $UniServer. Check Credentials or API access."
    }
}

# Reset progress counter
$c = 0

# Builds Objects for Assigned Assets
$arr = @()
foreach ($x in $AssignedUniAssets){
    foreach ($y in $x.backups){
        $obj = [PSCustomObject]@{
            Asset = $y.asset_name
            Source = $y.client_name
            Client = "Unknown"
            Server = $x.system_ip
            Solution = "Unitrends"
            Appliance = $x.system_name
            JobName = $x.name
            JobType = $x.type
            JobApp = $x.app_name
            JobFrequency = $x.frequency
            BackupStatus = $y.status
            BackupStart = $y.start_time
            BackupType = $y.mode
            BackupSize = $y.size
            BackupID = $y.backup_id
            BackupGUID = "$($x.system_name)"+"_"+"$($y.backup_id)"
            isAssigned = "True"
            isMonitored = "default-value"
            isDecommed = "False"
        }
        if ($obj.Asset -notin $MonitoredUniAssets.backup_name) {
            $obj.isMonitored = "False"
        }
        else {
            $obj.isMonitored = "True"
        }
        $arr += $obj
    }  
    $c++ 
    Write-Progress -Activity "Building objects from Dataset..." -Status "Objects tested: $c of $($AssignedUniAssets.Count)" -PercentComplete (($c / $AssignedUniAssets.Count) * 100)
}

# Reset progress counter
$c = 0

$arr | ForEach-Object { 
    if ($_.BackupGUID -notin $FinalDataSet.BackupGUID){
        $null = ($FinalDataSet).Add($_)
    }
    $c++ 
    Write-Progress -Activity "Adding Objects to Final Dataset..." -Status "Objects tested: $c of $($arr.Count)" -PercentComplete (($c / $arr.Count) * 100)
}

# Reset progress counter
$c = 0

# Builds Objects for Unnasigned Assets
$arr = @()
foreach ($i in $AvailableUniAssets) {    
    if ($i.Asset -notin $FinalDataSet.Asset) {
        $obj = [PSCustomObject]@{
            Asset = $i.Asset
            Source = $i.Source
            Client = "Unknown"
            Server = "N/A"
            Solution = "N/A"
            Appliance = "N/A"
            JobName = "N/A"
            JobType = "N/A"
            JobApp = "N/A"
            JobFrequency = "N/A"
            BackupStatus = "N/A"
            BackupStart = "N/A"
            BackupType = "N/A"
            BackupSize = "N/A"
            BackupID = "N/A"
            BackupGUID = "N/A"
            isAssigned = "False"
            isMonitored = "default-value"
            isDecommed = "False"
        }
        if ($obj.Asset -notin $MonitoredUniAssets.backup_name) {
            $obj.isMonitored = "False"
        }
        else {
            $obj.isMonitored = "True"
        }
        $arr += $obj
    }
    $c++ 
    Write-Progress -Activity "Building objects from Dataset..." -Status "Objects tested: $c of $($AvailableUniAssets.Count)" -PercentComplete (($c / $AvailableUniAssets.Count) * 100)
}

# Reset progress counter
$c = 0

$arr | ForEach-Object { 
    $null = ($FinalDataSet).Add($_) 
    $c++ 
    Write-Progress -Activity "Adding Objects to Final Dataset" -Status "Objects tested: $c of $($arr.Count)" -PercentComplete (($c / $arr.Count) * 100)
}

# Reset progress counter
$c = 0

# Builds Objects for Decommed Assets
$arr = @()
foreach ($i in $MonitoredUniAssets){
        if ($i.backup_name -notin $AvailableUniAssets.Asset) {
            $obj = [PSCustomObject]@{
                Asset = $i.backup_name
                Source = "N/A"
                Client = "Unknown"
                Server = "N/A"
                Solution = "N/A"
                Appliance = "N/A"
                JobName = "N/A"
                JobType = "N/A"
                JobApp = "N/A"
                JobFrequency = "N/A"
                BackupStatus = "N/A"
                BackupStart = "N/A"
                BackupType = "N/A"
                BackupSize = "N/A"
                BackupID = "N/A"
                BackupGUID = "N/A"
                isAssigned = "False"
                isMonitored = "True"
                isDecommed = "True"
            }
        $arr += $obj
    }
    $c++ 
    Write-Progress -Activity "Building objects from Dataset..." -Status "Objects tested: $c of $($MonitoredUniAssets.Count)" -PercentComplete (($c / $MonitoredUniAssets.Count) * 100)
}

# Reset progress counter
$c = 0

$arr | ForEach-Object { 
    $null = ($FinalDataSet).Add($_) 
    $c++ 
    Write-Progress -Activity "Adding Objects to Final Dataset" -Status "Objects tested: $c of $($arr.Count)" -PercentComplete (($c / $arr.Count) * 100)
}

# Reset progress counter
$c = 0

#Add client if found in ADI - UNRELIABLE. Data in ADI can be innacurate, and an asset may match multiple companies.
foreach ($x in $FinalDataSet) {
    $Client = $MonitoredUniAssets | Where-Object { $_.backup_name -eq $x.Asset} | Select-Object -ExpandProperty client_name
    if (@($Client).Count -gt 1){
        $Client = $Client -Join ", "
    } elseif ($null -eq $Client){
        $Client = "Not in ADI"
    } 
    $x.Client = $Client
    $c++ 
    Write-Progress -Activity "Processing final dataset..." -Status "Objects tested: $c of $($FinalDataSet.Count)" -PercentComplete (($c / $FinalDataSet.Count) * 100)
}

# Outputs Final Dataset 
$FinalDataSet | Export-Csv -Path $CsvPath -NoTypeInformation

Write-Output "The Script has finished. The report has been placed at $CsvPath and the error log can be found at $LogPath"

<#################
Calculated Fields Key
    isAssigned = Whether the Asset is Assigned to Job that has run in the past 7 days
    isMonitored = Whether the Asset is configured to alert in ADI
    isDecommed = Whether the Asset has been delted from a vCenter or disconnected from the Unitrnds appliance
#################>
<#################
TO DO
    [/] Add client names from ADI DB to objects with matching asset names
        [x] Change query to include name column from devices table as device_name
        [ ] Add logic to add based on backup_name AND device_name (appliance) and not just backup_name
    [ ] Add more ADI data for decommed and unnasigned assets 
    [x] Dedupe objects based on backupguid
    [x] Section off code into functions
    [ ] Improve comments
        [ ] Add the why for my logic
        [ ] Add descriptions and examples to functions
    [x] Improve useability
        [x] Add progress bars to loops. 
#################>
