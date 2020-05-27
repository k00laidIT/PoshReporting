<#
.Synopsis
  Generates report of relevant data on all customers known to a given Veeam Service Provider Console Server. Uses the new v3 API so your milage may vary.
.Notes
   Version: 1.0
   Author: Jim Jones
   Modified Date: 5/27/2020

   If running for the first time a new computer You will need to run to store the credentials
    $credpath='c:\users\jim\creds\myadmincred.xml'
    GET-CREDENTIAL –Credential (Get-Credential) | EXPORT-CLIXML $credpath
.EXAMPLE
  .\VACStorageReport.ps1 -vacServer 'vac.mydomain.com' -authPath 'c:\users\jim\creds\myadmincred.xml'
#>

[CmdletBinding()]
Param (
    [string]$vacserver = "vac.mydomain.com",
    [string]$authpath = ".\adminscred.xml"
)

$Credentials = IMPORT-CLIXML -path $authpath
$RESTAPIUser = $Credentials.UserName
$RESTAPIPassword = $Credentials.GetNetworkCredential().Password

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")

$body = "grant_type=password&username=$RestAPIUser&password=$RestAPIPassword"

$response = Invoke-RestMethod "https://$vacserver/api/v3/token" -Method 'POST' -Headers $headers -Body $body
$token = $response.access_token

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $token")

$repos = Invoke-RestMethod "https://$vacserver/api/v3/infrastructure/backupServers/repositories" -Method 'GET' -Headers $headers -Body $body

$repos.data | select-object name,hostname, path, `
    @{Name="CapacityGB";Expression={[math]::round($_.capacity / 1Gb, 2)}}, `
    @{Name="FreeSpaceGB";Expression={[math]::round($_.freeSpace / 1Gb, 2)}}, `
    @{Name="UsedSpaceGB";Expression={[math]::round($_.usedSpace / 1Gb, 2)}}, `
    @{Name="PercentUsed";Expression={($_.usedSpace/$_.capacity).toString("P")}} 
    | Sort-Object -Property PercentFree -Descending `
    | Export-CSV -Path ".\VACRepositoryInfo.CSV" -NoTypeInformation