function Get-UniSession {
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
        username=$User;
        password=$Pass;
    }
    $Response = Invoke-RestMethod -Uri "https://$Server/api/login" -Method Post -Body (ConvertTo-Json -InputObject $Body)
    Write-Output $Response
}

function Invoke-UniRest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] 
        [String] $AuthToken,
        [Parameter(Mandatory=$true)] 
        [String] $Server,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.String]$Endpoint,
        [Parameter(Mandatory = $true)]
        [ValidateSET('GET','PUT','PATCH','DELETE','POST','HEAD','OPTIONS')]
        [System.String]$Method,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [PSObject]$Body,
        [Parameter(Mandatory = $false)]
        [Switch]$BodyAsArray
    )
    try {
        $Uri = "https://$Server/api$Endpoint"
        $Headers = @{
            'AuthToken' = $AuthToken
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
