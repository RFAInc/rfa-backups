<#
.SYNOPSIS
    This script will poll all the rubrik appliances in ADI for recent jobs, and create schedules for them in ADI if they dont already exist.
.NOTES
    Version:        1.0
    Author:         Andy Escolastico
    Creation Date:  8/17/2020
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Requires -RunAsAdministrator
# Requires -Version 5

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# DB queries for ADI
$RubrikServersQuery = "
SELECT name, url, user_name, password
FROM devices
WHERE device_type_id = 3
"
$RubrikSchedulesQuery = "
SELECT sch.id as schedule_id,
    sch.backup_name AS schedule_name, 
    dev.name AS device_name,
    dev.id AS device_id,
    dev.url as device_url
FROM schedules AS sch
    JOIN devices AS dev ON sch.device_id = dev.id
    JOIN clients AS cli ON sch.client_id = cli.id
WHERE
    sch.is_active = 1
        AND
    dev.device_type_id = 3
"

# Initialize results array
$CreatedSchedules = @()

# Result file paths
$LogPath = "\\rfabatch\Reports\Backups\rubrik-imports_$(Get-Date -format "MM-dd-yy_HH-mm").log"
$CsvPath = "\\rfabatch\Reports\Backups\rubrik-imports_$(Get-Date -format "MM-dd-yy_HH-mm").csv"

#-----------------------------------------------------------[Functions]------------------------------------------------------------
. .\rubrik-functions.ps1
. .\general-functions.ps1
. .\adi-functions.ps1
. .\credentials.ps1
#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Ignores invalid certificate errors
Skip-InvalidCertErrors

# Querys Data from ADI
$ConnectedRubrikServers = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBName -Query $RubrikServersQuery
$MonitoredRubrikAssets = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBName -Query $RubrikSchedulesQuery

# Gets auth token from ADI
$ADIToken = (Get-ADIToken -Server $ADIAPIServer -User $ADIAPIUser -Pass $ADIAPIPass).accessToken

# Querys Rubrik Appliances for Protected and Available Assets
foreach ($i in $ConnectedRubrikServers){
    $RubrikServer = ((($i.url).Trim("https://")).Trim("http://")).Trim()
    $RubrikUser = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.user_name))
    $RubrikPass = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.password))
    try {
        # Connect to Rubrik server and retrieve auth token
        $Session = Get-RubrikSession -Server $RubrikServer -User $RubrikUser -Pass $RubrikPass  
    } catch {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format HH:mm)`: Could not connect to $RubrikServer. Check Credentials."
        Write-Output "Could not connect to $RubrikServer. Check Credentials or API access."
        Continue
    }
    # Collect Job data
    $RubrikData = Get-RubrikMonitoringObject -Server $RubrikServer -User $RubrikUser -Pass $RubrikPass
    # Create schedules if not already in ADI
    foreach ($x in $RubrikData){
        $Asset = $x.ObjectName
        if ($Asset -notin $MonitoredRubrikAssets.schedule_name){
            $ADIDeviceID = ($MonitoredRubrikAssets | Where-Object {$_.device_url -like "*$($Session.server)*"}).device_id[0]
            $ADIBackupName = $Asset
            $ADIClient = '469' # RFA is the dumping ground. Needed as there currently isnt a client mapping mechanism.
            $ADIScheduleType = 'days_of_week'
            $ADIScheduleStatus = '1'
            $ADIWeekDays = (Normalize-RubrikFrequencyString $x.FrequencyConfig).Weekdays
            $ADIStartTime = (Normalize-RubrikFrequencyString $x.WindowConfig).StartTime
            if ($ADIWeekDays -ne $null){
                $CreateResult = New-ADISchedule -Server $ADIAPIServer -Token $ADIToken -Enabled $ADIScheduleStatus -ClientID $ADIClient -DeviceID $ADIDeviceID -BackupName $ADIBackupName -StartTime $ADIStartTime -Type $ADIScheduleType -WeekDays $ADIWeekDays
                Write-Output "POST:" $Asset
                $CreatedSchedules += $CreateResult 
            }
            # Re-poll ADI
            $MonitoredRubrikAssets = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBNAME -Query $RubrikSchedulesQuery
        }
    }
}

$CreatedSchedules | Export-Csv -Path $CsvPath -NoTypeInformation