function Skip-InvalidCertErrors{
    Add-Type "
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }"
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls12
}

function Invoke-MySqlMethod{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] 
        [String] $Server,
        [Parameter(Mandatory=$true)] 
        [String] $User,
        [Parameter(Mandatory=$true)] 
        [String] $Pass,
        [Parameter(Mandatory=$true)] 
        [String] $DataBase,
        [Parameter(Mandatory=$true)] 
        [String] $Query
    )

    # Loads MySql dependancy file 
    if (Test-Path "$env:SystemRoot/MySql.Data.dll"){
        Add-Type -Path "$env:SystemRoot/MySql.Data.dll"
    }elseif (Test-Path "./MySql.Data.dll") {
        Add-Type -Path "./MySql.Data.dll"
    }else {
        Invoke-WebRequest "https://github.com/RFAInc/rfa-backups/blob/main/MySql.Data.dll?raw=true" -Outfile "./MySql.Data.dll"
        Add-Type -Path "./MySql.Data.dll"
    }

    # Builds Connection
    $ConnectionString = "server=" + $Server + "; port=3306; uid=" + $User + "; pwd=" + $Pass + "; database="+$DataBase
    $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
    $Connection.ConnectionString = $ConnectionString
    
    # Connects to DB
    $Connection.Open()

    #Builds Command, and populates DataSet
    $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
    $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
    $DataSet = New-Object System.Data.DataSet
    $null = $DataAdapter.Fill($DataSet, "data")

    # Stores DataSet
    $Result = $DataSet.Tables[0]

    # Disconnects from DB
    $Connection.Close()

    # Returns result
    Write-Output $Result 
}
