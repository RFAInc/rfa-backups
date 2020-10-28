function Get-RubrikSession { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] 
        [String] $Server,
        [Parameter(Mandatory=$true)] 
        [String] $User,
        [Parameter(Mandatory=$true)] 
        [String] $Pass
    )
    $BasicString =  [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($User + ':' + $Pass))
    $Headers = @{
        'Authorization' = "Basic $BasicString"
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }
    $Response = Invoke-RestMethod -Uri "https://$Server/api/v1/session" -Method "Post" -Headers $Headers
    $Response | Add-Member -NotePropertyName "server" -NotePropertyValue $Server
    Write-Output $Response
}


function Invoke-RubrikRest {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true)]
        [String]$Token,
        [Parameter(Mandatory = $true)]
        [ValidateSET('GET','PUT','PATCH','DELETE','POST','HEAD','OPTIONS')]
        [System.String]$Method,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.String]$Endpoint,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject]$Body,
        [Parameter(Mandatory = $false)]
        [Switch]$BodyAsArray
    )
    try {
        $Uri = "https://$Server/api$Endpoint"
        $Headers = @{
            'Authorization' = "Bearer $Token"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }
        if($Method -ne 'GET' -and $body){
            if ($BodyAsArray) {
                [String]$JsonBody = ConvertTo-Json -InputObject @($Body) -Depth 10
            } else {
                [String]$JsonBody = $Body | ConvertTo-Json -Depth 10
            }
        }
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method -Body $JsonBody
    }
    catch {
        throw $_
    }
    Write-Output $Response
}

function Get-RubrikReportData {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true)]
        [String]$User,
        [Parameter(Mandatory = $true)]
        [String]$Pass,
        [Parameter(Mandatory = $true)]
        [String]$ReportID
    )
    $Session = Get-RubrikSession -Server $Server -User $User -Pass $Pass
    $Body = New-Object -TypeName PSObject -Property @{'limit'=9999}
    $Response = Invoke-RubrikRest -Server $Session.server -Token $Session.token -Endpoint "/internal/report/$ReportID/table" -Method "POST" -Body $Body
    
    if ($Response.hasMore -eq 'true') {
        $NextResponse = $Response
        while ($NextResponse.hasMore -eq 'true'){
            $cursor = $NextResponse.cursor
            $Body = New-Object -TypeName PSObject -Property @{'limit'=9999; 'cursor'=$cursor}
            $NextResponse = Invoke-RubrikRest -Server $Session.server -Token $Session.token -Endpoint "/internal/report/$ReportID/table" -Method "POST" -Body $Body
            $Response.dataGrid += $NextResponse.dataGrid
        }
        $Response.hasMore = 'false'
    }
    $Result = $Response | Select-Object -Property *,@{
        name = 'object'
        expression = {
            $Response.datagrid | ForEach-Object {
                $_ | ForEach-Object -Begin {
                    $Count = 0
                    $HashProps = [ordered]@{}
                } -Process {
                    $HashProps.$($Response.columns[$Count]) = $_
                    $Count++
                } -End {
                    [pscustomobject]$HashProps
                }
            }
        }   
    }
    Write-Output $Result
}
function Get-RubrikSLADomains{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true)]
        [String]$User,
        [Parameter(Mandatory = $true)]
        [String]$Pass
    )
    $Session = Get-RubrikSession -Server $Server -User $User -Pass $Pass
    $Response = Invoke-RubrikRest -Server $Session.server -Token $Session.token -Endpoint "/v2/sla_domain" -Method "GET"
    Write-Output $Response.data
}
function Get-RubrikProtectionStatus {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true)]
        [String]$User,
        [Parameter(Mandatory = $true)]
        [String]$Pass
    )
    #TODO: make api calls to find any available protectionstatus report with the required columns
    $Response = Get-RubrikReportData -Server $Server -User $User -Pass $Pass -ReportID "CustomReport:::8d6585a8-960e-432c-b2a7-c1c788bf313e"
    Write-Output $Response.object
}
function Get-RubrikMonitoringObject{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true)]
        [String]$User,
        [Parameter(Mandatory = $true)]
        [String]$Pass
    )
    $SLADomains = Get-RubrikSLADomains -Server $Server -User $User -Pass $Pass
    $ProtectionStatus = Get-RubrikProtectionStatus -Server $Server -User $User -Pass $Pass
    $objs = @()
    foreach ($i in $ProtectionStatus) {
        $SLAData = $SLADomains | Where-Object {$_.id -eq $i.SlaDomainId}
        $FrequencyData =  $SLAData | Select-Object -ExpandProperty frequencies
        $obj = [PSCustomObject]@{}
        foreach ($x in $FrequencyData.PsObject.Properties) {
            $unit = $x.name  
            $subprops = $x.value.PsObject.Properties
            foreach ($y in $subprops) {
                $obj | Add-Member -NotePropertyName $($unit + $y.Name) -NotePropertyValue $y.Value
            }
        }
        $str = $obj -join "; "
        $i | Add-Member -NotePropertyName "FrequencyConfig" -NotePropertyValue $str
        $WindowData =  $SLAData | Select-Object -ExpandProperty allowedBackupWindows
        if ($WindowData.startTimeAttributes.hour -lt 10) {
            $hour = "0" + ($WindowData.startTimeAttributes.hour -as [string])
        }else{
            $hour = ($WindowData.startTimeAttributes.hour -as [string])
        }
        if ($WindowData.startTimeAttributes.minutes -lt 10) {
            $minute = "0" + ($WindowData.startTimeAttributes.minutes -as [string])
        }else{
            $minute = ($WindowData.startTimeAttributes.minutes -as [string])
        }
        $obj = [PSCustomObject]@{
            StartTime = $hour + ":" + $minute
            Duration=$WindowData.durationInHours
        }
        $str = $obj -join "; "
        $i | Add-Member -NotePropertyName "WindowConfig" -NotePropertyValue $str
        $objs += $i
    }
    $Result = $objs
    Write-Output $Result
}