function Get-SkykickSession { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] 
        [String] $User,
        [Parameter(Mandatory=$true)] 
        [String] $Key
    )
    $Headers = @{
        'Ocp-Apim-Subscription-Key' = $Key
        'Content-Type' = 'application/x-www-form-urlencoded'
        'Accept' = 'application/json'
        'Authorization' = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($User + ':' + $Key)))"
    }
    $Body = "grant_type=client_credentials&scope=Partner"
    $Response = Invoke-RestMethod -Uri "https://apis.skykick.com/auth/token" -Method "Post" -Headers $Headers -Body $Body
    Write-Output $Response
}

function Get-SkykickSubscriptions {
    param (
        [Parameter(Mandatory=$true)] 
        [String] $User,
        [Parameter(Mandatory=$true)] 
        [String] $Key
    )
    try {
        $AuthToken = (Get-SkykickSession -User $User -Key $Key).access_token
        $Headers = @{
            'Authorization' = "Bearer $AuthToken"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
            'Ocp-Apim-Subscription-Key' = $Key
        }
        $Subscriptions = Invoke-RestMethod -Uri "https://apis.skykick.com/Backup" -Headers $Headers -Method "Get"
    }
    catch {
        throw $_
    }
    Write-Output $Subscriptions
}