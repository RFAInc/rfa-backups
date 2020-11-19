function Get-CloudberrySession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$User,
        [Parameter(Mandatory=$true)]
        [string]$Pass
    )
    $Body = @{
        "Username" = $User
        "Password" = $Pass
    }
    $Response = Invoke-RestMethod -Uri "http://mspbackups.com/v2.0/api/Provider/Login" -Method "Post" -Headers $Headers -Body $Body
    Write-Output $Response
}
function Get-CloudberryMonitoringObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$User,
        [Parameter(Mandatory=$true)]
        [string]$Pass
    )
    $AuthToken = (Get-CloudberrySession -User $User -Pass $Pass).access_token
    $Headers = @{
        'Authorization' = "Bearer $AuthToken"
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }
    $Response = Invoke-RestMethod -Uri "http://mspbackups.com/v2.0/api/Monitoring" -Method "Get" -Headers $Headers
    Write-Output $Response
}

$ConsistencyTypes = @(
    [PSCustomObject]@{
        Name = 'ConsistencyCheck'
        Code = 13
    }
)
$BackupTypes = @(
    [PSCustomObject]@{
        Name = 'Backup'
        Code = 1
    },
    [PSCustomObject]@{
        Name = 'BackupFiles'
        Code = 3
    },
    [PSCustomObject]@{
        Name = 'VMBackup'
        Code = 5
    },
    [PSCustomObject]@{
        Name = 'SQLBackup'
        Code = 7
    },
    [PSCustomObject]@{
        Name = 'ExchangeBackup'
        Code = 9
    },
    [PSCustomObject]@{
        Name = 'BMSSBackup'
        Code = 11
    },
    [PSCustomObject]@{
        Name = 'EC2Backup'
        Code = 14
    },
    [PSCustomObject]@{
        Name = 'HyperVBackup'
        Code = 16
    }
)
$RecoveryTypes = @(
    [PSCustomObject]@{
        Name = 'Restore'
        Code = 2
    },
    [PSCustomObject]@{
        Name = 'RestoreFiles'
        Code = 4
    },
    [PSCustomObject]@{
        Name = 'VMRestore'
        Code = 6
    },
    [PSCustomObject]@{
        Name = 'SQLRestore'
        Code = 8
    },
    [PSCustomObject]@{
        Name = 'ExchangeRestore'
        Code = 10
    },
    [PSCustomObject]@{
        Name = 'BMSSRestore'
        Code = 12
    },
    [PSCustomObject]@{
        Name = 'EC2Restore'
        Code = 15
    },
    [PSCustomObject]@{
        Name = 'HyperVRestore'
        Code = 17
    }
)