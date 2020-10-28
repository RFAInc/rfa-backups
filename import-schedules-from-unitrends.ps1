<#
.SYNOPSIS
    This script will poll all the unitrends appliances in ADI for recent jobs, and create schedules for them in ADI if they dont already exist.
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
$UniServersQuery = "
SELECT name, url, user_name, password
FROM devices
WHERE device_type_id = 1
"
$UniSchedulesQuery = "
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
    dev.device_type_id = 1
"

# Initialize results array
$CreatedSchedules = @()

# Result file paths
$LogPath = "\\rfabatch\Reports\Backups\unitrends-imports_$(Get-Date -format "MM-dd-yy_HH-mm").log"
$CsvPath = "\\rfabatch\Reports\Backups\unitrends-imports_$(Get-Date -format "MM-dd-yy_HH-mm").csv"

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
$MonitoredUniAssets = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBName -Query $UniSchedulesQuery

# Gets auth token from ADI
$ADIToken = (Get-ADIToken -Server $ADIAPIServer -User $ADIAPIUser -Pass $ADIAPIPass).accessToken

# Reset progress counter
$c = 0

# Querys Unitrends Appliances for Protected and Available Assets
foreach ($i in $ConnectedUniServers){
    $UniServer = (($i.url).Trim("http://")).Trim()
    $UniUser = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.user_name))
    $UniPass = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.password))
    try {
        # Connect to Unitrends server and retrieve auth token
        $AuthToken = (Get-UniToken -Server $UniServer -User $UniUser -Pass $UniPass).auth_token    
    } catch {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format HH:mm)`: Could not connect to $UniServer. Check Credentials."
        Write-Output "Could not connect to $UniServer. Check Credentials or API access."
        Continue
    }
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
    # Create schedules if not already in ADI
    foreach ($x in $JobHistory){
        foreach ($y in $x.backups){
            $Asset = $y.asset_name
            $Server = $x.system_ip
            $Appliance = $x.system_name
            $JobFrequency = $x.frequency
            if ($Asset -notin $MonitoredUniAssets.schedule_name){
                $UniFrequency = $JobFrequency -split "; "
                $ADIDeviceID = ($MonitoredUniAssets | Where-Object {$_.device_name -like $Appliance}).device_id[0] # .device_name field from db is user populated. If they mispelled the appliance this will result in a null, causing the backups for that appliance to not get imported. consider using system_ip
                $ADIBackupName = $Asset
                $ADIClient = '469' # RFA is the dumping ground. Needed as there currently isnt a client mapping mechanism.
                $ADIScheduleType = 'days_of_week'
                $ADIScheduleStatus = '1'
                foreach ($i in $UniFrequency){
                    $ADIFrequency = Normalize-UniFrequencyString -CalendarString $i
                    $ADIStartTime = $ADIFrequency.StartTime
                    $ADIWeekDays = $ADIFrequency.WeekDays
                    if ($ADIWeekDays -ne $null){
                        $CreateResult = New-ADISchedule -Server $ADIAPIServer -Token $ADIToken -Enabled $ADIScheduleStatus -ClientID $ADIClient -DeviceID $ADIDeviceID -BackupName $ADIBackupName -StartTime $ADIStartTime -Type $ADIScheduleType -WeekDays $ADIWeekDays
                        $CreatedSchedules += $CreateResult 
                    }
                }
                # Re-poll ADI
                $MonitoredUniAssets = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBNAME -Query $UniSchedulesQuery
            }
        }  
    }
    # Output progress
    $c++ 
    Write-Progress -Activity "Importing schedules from Unitrends devices..." -Status "Units Queried: $c of $($ConnectedUniServers.Count)" -PercentComplete (($c / $ConnectedUniServers.Count) * 100)

}

$CreatedSchedules | Export-Csv -Path $CsvPath -NoTypeInformation