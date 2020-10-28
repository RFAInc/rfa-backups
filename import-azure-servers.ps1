<#
.SYNOPSIS
.NOTES
    Version:        1.0
    Author:         Andy Escolastico
    Creation Date:  9/24/2020
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Requires -RunAsAdministrator
# Requires -Version 5

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# DB queries for ADI
$AzureQuery = "
SELECT *
FROM devices
WHERE device_type_name = 'Azure Backup'
"
# Initialize results array
$CreatedDevices = @()

# Result file paths
$CsvPath = "\\rfabatch\Reports\Backups\device-imports_$(Get-Date -format "MM-dd-yy_HH-mm").csv"

#-----------------------------------------------------------[Functions]------------------------------------------------------------
. .\general-functions.ps1
. .\adi-functions.ps1
. .\credentials.ps1
. .\azure-accounts.ps1
#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Ignores invalid certificate errors
Skip-InvalidCertErrors

$ADIDBName = "production_new"

# Querys Data from ADI
$ConnectedAzureDevices = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBName -Query $AzureQuery

# Gets auth token from ADI
$ADIToken = (Get-ADIToken -Server $ADIAPIServer -User $ADIAPIUser -Pass $ADIAPIPass).accessToken

# Loop through azure accounts file
foreach ($i in $azure_accounts){
    # Create device if not already in ADI
    if ($i.device_name -notin $ConnectedAzureDevices.name){
        # Set loop variables
        $DeviceName = $i.device_name
        $DeviceTypeName = "Azure Backup"
        $TenantId = $i.tenant_id
        $SubscriptionId = $i.subscription_id
        $ClientId = $i.client_id
        $ClientSecret = $i.client_secret
        # Make request to ADI
        $CreateResult = New-ADIDevice -Server $ADIAPIServer -Token $ADIToken -DeviceName $DeviceName -DeviceTypeName $DeviceTypeName -TenantId $TenantId -SubscriptionId $SubscriptionId -ClientId $ClientId -ClientSecret $ClientSecret
        Write-Host "Adding: $DeviceName" -ForegroundColor "Green" -BackgroundColor "Black" 
        $CreatedDevices += $CreateResult
        # Re-poll ADI
        $ConnectedAzureDevices = Invoke-MySqlMethod -Server $ADIDBServer -User $ADIDBUser -Pass $ADIDBPass -DataBase $ADIDBName -Query $AzureQuery
    }
}
# Export to csv
$CreatedDevices | Export-Csv -Path $CsvPath -NoTypeInformation