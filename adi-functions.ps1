function Normalize-UniFrequencyString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$CalendarString
    )
    $map = @(
        [PSCustomObject]@{
            adi = 1
            uni = "Mon"
        },
        [PSCustomObject]@{
            adi = 2
            uni = "Tue"
        },
        [PSCustomObject]@{
            adi = 3
            uni = "Wed"
        },
        [PSCustomObject]@{
            adi = 4
            uni = "Thu"
        },
        [PSCustomObject]@{
            adi = 5
            uni = "Fri"
        },
        [PSCustomObject]@{
            adi = 6
            uni = "Sat"
        },
        [PSCustomObject]@{
            adi = 7
            uni = "Sun"
        },
        [PSCustomObject]@{
            adi = 8
            uni = "Mon"
        },
        [PSCustomObject]@{
            adi = 9
            uni = "Tue"
        },
        [PSCustomObject]@{
            adi = 10
            uni = "Wed"
        },
        [PSCustomObject]@{
            adi = 11
            uni = "Thu"
        },
        [PSCustomObject]@{
            adi = 12
            uni = "Fri"
        },
        [PSCustomObject]@{
            adi = 13
            uni = "Sat"
        },
        [PSCustomObject]@{
            adi = 14
            uni = "Sun"
        }
    )
    $i = $CalendarString

    if ($i -match "Full:\s+\w{3}\s+at\s+\d{1,2}:\d{2}\s+\w{2}|Incremental:\s+\w{3}\s+at\s+\d{1,2}:\d{2}\s+\w{2}"){
        if ($i -like "*Full*"){
            $uni_days = @([regex]::Match($i, "Full:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[1].Value)
            $uni_time = [regex]::Match($i, "Full:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[2].Value    
        } else{
            $uni_days = @([regex]::Match($i, "Full:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[3].Value)
            $uni_time = [regex]::Match($i, "Full:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[4].Value    
        }
        $adi_days = @()
        foreach ($x in $uni_days){
            $adi_day = (($map | Where-Object {$_.uni -eq $x}).adi| Sort-Object)[0]
            $adi_days += $adi_day
        }
        if ($uni_time -like "*pm*"){
            $adi_time = (($uni_time -replace ":" -replace "pm" -as [int]) + 1200) -as [string]
        } else {
            $adi_time = $uni_time -replace ":" -replace "am" -as [int]
            if ($adi_time -lt 960){
                $adi_time = "0" + $adi_time -as [string]
            }
        }
        $adi_time = $adi_time.Insert(2,":")
    }elseif ($i -match "Full:\s+\w{3},.*\s+at\s+\d{1,2}:\d{2}\s+\w{2}|Incremental:\s+\w{3},.*\s+at\s+\d{1,2}:\d{2}\s+\w{2}"){
        if ($i -like "*Full*"){
            $uni_days = ([regex]::Match($i, "Full:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[1].Value) -split ","
            $uni_time = [regex]::Match($i, "Full:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[2].Value    
        } else {
            $uni_days = ([regex]::Match($i, "Full:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[3].Value) -split ","
            $uni_time = [regex]::Match($i, "Full:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3},.*)\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[4].Value    
        }
        $adi_days = @()
        foreach ($x in $uni_days){
            $adi_day = (($map | Where-Object {$_.uni -eq $x}).adi| Sort-Object)[0]
            $adi_days += $adi_day
        }
        if ($uni_time -like "*pm*"){
            $adi_time = (($uni_time -replace ":" -replace "pm" -as [int]) + 1200) -as [string]
        } else {
            $adi_time = $uni_time -replace ":" -replace "am" -as [int]
            if ($adi_time -lt 960){
                $adi_time = "0" + $adi_time -as [string]
            }
        }
        $adi_time = $adi_time.Insert(2,":")
    }elseif ($i -match "Full:\s+\w{3}-\w{3}\s+at\s+\d{1,2}:\d{2}\s+\w{2}|Incremental:\s+\w{3}-\w{3}\s+at\s+\d{1,2}:\d{2}\s+\w{2}"){
        if ($i -like "*Full*"){
            $start_uni_day = [regex]::Match($i, "Full:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[1].Value
            $end_uni_day = [regex]::Match($i, "Full:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[2].Value
            $uni_time = [regex]::Match($i, "Full:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[3].Value    
        }else{
            $start_uni_day = [regex]::Match($i, "Full:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[4].Value
            $end_uni_day = [regex]::Match($i, "Full:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[5].Value
            $uni_time = [regex]::Match($i, "Full:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+(\w{3})-(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[6].Value    
        }
        $uni_days = @()
        $adi_days = @()
        $start_adi_day = (($map | Where-Object {$_.uni -eq $start_uni_day}).adi | Sort-Object)[0]
        $end_adi_day   = (($map | Where-Object {$_.uni -eq $end_uni_day}).adi | Sort-Object)[0]
        if ($end_adi_day -lt $start_adi_day) {$end_adi_day = $end_adi_day + 7}
        foreach ($i in @(0..13)) {
            $thisDay = $map | Where-Object {$_.adi -eq $i}
            if (
                $thisDay.adi -ge $start_adi_day -and
                $thisDay.adi -le $end_adi_day
            ) {
                $uni_days += $thisDay.uni
            }
        }
        foreach ($x in $uni_days){
            $adi_day = (($map | Where-Object {$_.uni -eq $x}).adi| Sort-Object)[0]
            $adi_days += $adi_day
        }
        if ($uni_time -like "*pm*"){
            $adi_time = (($uni_time -replace ":" -replace "pm" -as [int]) + 1200) -as [string]
        } else {
            $adi_time = $uni_time -replace ":" -replace "am" -as [int]
            if ($adi_time -lt 960){
                $adi_time = "0" + $adi_time -as [string]
            }
        }
        $adi_time = $adi_time.Insert(2,":")
    }elseif ($i -match "Full:\s+Every\sother\s\w{3}\s+at\s+\d{1,2}:\d{2}\s+\w{2}|Incremental:\s+Every\sother\s\w{3}\s+at\s+\d{1,2}:\d{2}\s+\w{2}") {
        if ($i -like "*Full*"){
            $uni_days = @([regex]::Match($i, "Full:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[1].Value)
            $uni_time = [regex]::Match($i, "Full:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[2].Value
        }else {
            $uni_days = @([regex]::Match($i, "Full:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[3].Value)
            $uni_time = [regex]::Match($i, "Full:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})|Incremental:\s+Every\sother\s(\w{3})\s+at\s+(\d{1,2}:\d{2}\s+\w{2})").Groups[4].Value
        }
        $adi_days = @()
        foreach ($x in $uni_days){
            $adi_day = (($map | Where-Object {$_.uni -eq $x}).adi| Sort-Object)[0]
            $adi_days += $adi_day
        }
        if ($uni_time -like "*pm*"){
            $adi_time = (($uni_time -replace ":" -replace "pm" -as [int]) + 1200) -as [string]
        } else {
            $adi_time = $uni_time -replace ":" -replace "am" -as [int]
            if ($adi_time -lt 960){
                $adi_time = "0" + $adi_time -as [string]
            }
        }
        $adi_time = $adi_time.Insert(2,":")
    }else{
        Write-Host "no match found"
    }

    $FormattedString = [PSCustomObject]@{
        StartTime = $adi_time
        WeekDays = $adi_days | Sort-Object
    }
    Write-Output $FormattedString
}

function Normalize-RubrikFrequencyString{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$CalendarString
    )
    $map = @(
        [PSCustomObject]@{
            adi = 1
            rubrik = "Monday"
        },
        [PSCustomObject]@{
            adi = 2
            rubrik = "Tuesday"
        },
        [PSCustomObject]@{
            adi = 3
            rubrik = "Wednesday"
        },
        [PSCustomObject]@{
            adi = 4
            rubrik = "Thursday"
        },
        [PSCustomObject]@{
            adi = 5
            rubrik = "Friday"
        },
        [PSCustomObject]@{
            adi = 6
            rubrik = "Saturday"
        },
        [PSCustomObject]@{
            adi = 7
            rubrik = "Sunday"
        }
    )
    $i = $CalendarString
    $FormattedString = [PSCustomObject]@{
        StartTime = ""
        WeekDays = ""
    }
    if ($i -match "StartTime=") {
        $rubrik_time = [regex]::Match($i, "StartTime=(\w+:\w+)").Groups[1].Value
        $adi_time = $rubrik_time
        $FormattedString.StartTime = $adi_time
    }
    if (($i -match "hourly") -or ($i -match "daily")) {
        $FormattedString.WeekDays = @(1, 2, 3, 4, 5, 6, 7)
        #Daily checks, no need to add other frequencys to ADI
    } else{
        #Not daily, each schedule should be added as seperate  entry
        if ($i -contains "weekly"){
            $rubrik_day = [regex]::Match($i, "weeklydayOfWeek=(\w+)").Groups[1].Value
            $adi_day = @( ($map | Where-Object {$_.rubrik -eq $rubrik_day}).adi)
            $FormattedString = [PSCustomObject]@{
                WeekDays = $adi_day
            }
        }
        if ($i -contains "monthly"){
            #TODO: Write logic, need: example of string format.
        }
        if ($i -contains "monthly") {
            #ADI doesnt support quarterly.
        }
        if ($i -contains "yearly") {
            #TODO: Write logic, need: example of string format.
        }
    
    }
    
    Write-Output $FormattedString
}

function Get-ADIToken { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] 
        [String] $Server,
        [Parameter(Mandatory=$true)] 
        [String] $User,
        [Parameter(Mandatory=$true)] 
        [String] $Pass
    )
    $Body =  @{
        email=$User;
        password=$Pass;
    } | ConvertTo-Json
    $Response = Invoke-RestMethod -Uri "http://$Server/api/v1/users/login" -Method "Post" -ContentType "application/json" -Body $Body
    Write-Output $Response
}

function New-ADISchedule { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Server,
        [Parameter(Mandatory=$true)]
        [String]$Token,
        [Parameter(Mandatory=$true)]
        [String]$Enabled,
        [Parameter(Mandatory=$true)]
        [String]$ClientID,
        [Parameter(Mandatory=$true)]
        [String]$DeviceID,
        [Parameter(Mandatory=$true)]
        [String]$BackupName,
        [Parameter(Mandatory=$true)]
        [String]$StartTime,
        [Parameter(Mandatory=$true)]
        [String]$Type,
        [Parameter(Mandatory=$true)]
        $WeekDays
    )
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", "$Token")
    $Body =  @{
        is_active=$Enabled
        client_id=$ClientID
        device_id=$DeviceID
        backup_name=$BackupName
        time=$StartTime
        type=$Type
        days_week=@($WeekDays)
    } | ConvertTo-Json
    $response = Invoke-RestMethod "http://$Server/api/v1/schedules" -Method 'POST' -ContentType 'application/json' -Headers $Headers -Body $Body
    Write-Output $response
}

function Update-ADISchedule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Server,
        [Parameter(Mandatory=$true)]
        [String]$Token,
        [Parameter(Mandatory=$true)]
        [String]$ScheduleID,
        [Parameter(Mandatory=$true)]
        [String]$Enabled,
        [Parameter(Mandatory=$true)]
        [String]$ClientID,
        [Parameter(Mandatory=$true)]
        [String]$DeviceID,
        [Parameter(Mandatory=$true)]
        [String]$BackupName,
        [Parameter(Mandatory=$true)]
        [String]$StartTime,
        [Parameter(Mandatory=$true)]
        [String]$Type,
        [Parameter(Mandatory=$true)]
        $WeekDays
    )
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", "$Token")
    $Body =  @{
        is_active=$Enabled
        client_id=$ClientID
        device_id=$DeviceID
        backup_name=$BackupName
        time=$StartTime
        type=$Type
        days_week=@($WeekDays)
    } | ConvertTo-Json
    $response = Invoke-RestMethod "http://$Server/api/v1/schedules/$ScheduleID" -Method 'PUT' -ContentType 'application/json' -Headers $Headers -Body $Body
    Write-Output $response
}
function New-ADIDevice { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Server,
        [Parameter(Mandatory=$true)]
        [String]$Token,
        [Parameter(Mandatory=$true)]
        [String]$DeviceName,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Azure Backup","Rubrik", "Unitrends", "Cloudberry")]
        [String]$DeviceTypeName,
        [Parameter(Mandatory=$false)]
        [ValidateSet("1","0")]
        [String]$Enabled = "1",
        [Parameter(Mandatory=$false)]
        [String]$Threshold = "4",
        [Parameter(Mandatory=$false)]
        [String]$AllowRangeFrom = "240",
        [Parameter(Mandatory=$false)]
        [String]$AllowRangeTo = "240",
        [Parameter(Mandatory=$false)]
        [String]$Url = "",
        [Parameter(Mandatory=$false)]
        [String]$Username = "",
        [Parameter(Mandatory=$false)]
        [String]$Password = "",
        [Parameter(Mandatory=$false)]
        [String]$CustomReportId = "",
        [Parameter(Mandatory=$false)]
        [String]$TenantId = "",
        [Parameter(Mandatory=$false)]
        [String]$SubscriptionId = "",
        [Parameter(Mandatory=$false)]
        [String]$ClientId = "",
        [Parameter(Mandatory=$false)]
        [String]$ClientSecret = ""
    )
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", "$Token")
    $Body =  @{
        is_active=$Enabled
        name = $DeviceName
        device_type_name = $DeviceTypeName
        threshold = $Threshold
        allow_range_from = $AllowRangeFrom
        allow_range_to = $AllowRangeTo
    } | ConvertTo-Json
    $response = Invoke-RestMethod "http://$Server/api/v1/devices" -Method 'POST' -ContentType 'application/json' -Headers $Headers -Body $Body
    $Body =  @{
        is_active=$Enabled
        name = $DeviceName
        device_type_name = $DeviceTypeName
        threshold = $Threshold
        allow_range_from = $AllowRangeFrom
        allow_range_to = $AllowRangeTo
        url = $Url
        username = $Username
        password = $Password
        custom_report_id = $CustomReportId
        tenant_id = $TenantId
        subscription_id = $SubscriptionId
        client_id = $ClientId
        client_secret = $ClientSecret
    
    } | ConvertTo-Json
    $response = Invoke-RestMethod "http://$Server/api/v1/devices/$($response.id)" -Method 'PUT' -ContentType 'application/json' -Headers $Headers -Body $Body
    Write-Output $response
}
