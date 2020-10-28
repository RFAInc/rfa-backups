<#
.SYNOPSIS

.NOTES
    Version:        1.0
    Author:         Andy Escolastico
    Creation Date:  8/22/2020
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
    dev.id AS device_id
FROM schedules AS sch
    JOIN devices AS dev ON sch.device_id = dev.id
    JOIN clients AS cli ON sch.client_id = cli.id
WHERE
    sch.is_active = 1
        AND
    dev.device_type_id = 3
"

# Initialize results array
$FinalReport = New-Object -TypeName System.Collections.ArrayList

# Result file paths
$LogPath = "\\rfabatch\Reports\Backups\rubrik-report_$(Get-Date -format "MM-dd-yy_HH-mm").log"
$CsvPath = "\\rfabatch\Reports\Backups\rubrik-report_$(Get-Date -format "MM-dd-yy_HH-mm").csv"

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

foreach ($i in $ConnectedRubrikServers){
    $RubrikServer = ((($i.url).Trim("https://")).Trim("http://")).Trim()
    $RubrikUser = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.user_name))
    $RubrikPass = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($i.password)) 
    try {
        # Connect to Rubrik server and retrieve auth token
        $AuthToken = (Get-RubrikSession -Server $RubrikServer -User $RubrikAPIUser -Pass $RubrikAPIPass).token    
    } catch {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format HH:mm)`: Could not connect to $RubrikServer. Check Credentials."
        Write-Output "Could not connect to $RubrikServer. Check Credentials or API access."
        Continue
    }
    $RubrikData = Get-RubrikMonitoringObject -Server $RubrikServer -User $RubrikUser -Pass $RubrikPass
    $RubrikData | ForEach-Object{
        $null = ($FinalReport).Add($_)
    } 
}

$FinalReport | Export-Csv $CsvPath -NoTypeInformation

<#TODO: 
    Add unprotected / unassigned assets to report
    Add the 3 calculated values I have in unitrends report script (isMonitored, isAssigned, isDecommed)
#>