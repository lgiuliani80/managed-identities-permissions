# Requirement: AzureAD

param(
    [string][Parameter(Mandatory = $true)]$TenantID,
    [string][Parameter(Mandatory = $true)]$ManagedIdentityName,
    [string][Parameter(Mandatory = $true)]$GraphPermissionName
)

$ErrorActionPreference = "Stop"

# Graph API Client Id (Fixed)
$GraphAppId = "00000003-0000-0000-c000-000000000000"

# Get the Graph API Service Principal for this tenant to retrieve its AppRoles [= Application Permissions] and Object Id
$GraphAPISP = az ad sp show --id $GraphAppId | ConvertFrom-Json
$AllPermissions = $GraphAPISP.appRoles
# Get the AppRole Id for the requested permission
$GraphPermissionId = $AllPermissions | Where-Object {$_.value -eq $GraphPermissionName} | Select-Object -ExpandProperty id
Write-Host "Graph API Service Principal Object Id: $($GraphAPISP.id)" -ForegroundColor DarkCyan
Write-Host "The AppRole Id for the requested permission is: $GraphPermissionId" -ForegroundColor DarkCyan


# Get the Service Principal object that represents the specified Managed Identity
$MSISP = az ad sp list --display-name $ManagedIdentityName | ConvertFrom-Json | Select-Object -First 1

$response = az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$($MSISP.id)/appRoleAssignments" | ConvertFrom-Json
$alreadyAssigned = $response.value | Where-Object { $_.principalId -eq $MSISP.id -and $_.resourceId -eq $GraphAPISP.id -and $_.appRoleId -eq $GraphPermissionId }

Write-Host "Current permission assignments for the Managed Identity:" -ForegroundColor DarkCyan
$response.value | Format-Table resourceId,appRoleId,createdDateTime -AutoSize

if (-not $alreadyAssigned) {
    # Prepare the payload for the AppRoleAssignment Graph API Call
    $AppRoleAssignmentPayload = @{
        principalId = $MSISP.id          # The Object Id of the Managed Identity Service Principal
        resourceId = $GraphAPISP.id      # The Object Id of the Graph API Service Principal
        appRoleId = $GraphPermissionId   # The AppRole Id of the requested Graph API permission
    }
    $BodyFile = [System.IO.Path]::GetTempFileName()  # Write the payload to a temporary file
    $AppRoleAssignmentPayload | ConvertTo-Json -Compress | Out-File -Encoding ascii -FilePath $BodyFile
    $response = az rest --method post --headers "content-type=application/json" `
                    --url "https://graph.microsoft.com/v1.0/servicePrincipals/$($MSISP.id)/appRoleAssignments" `
                    --body `@$BodyFile | ConvertFrom-Json  # Execute the AppRoleAssignment Graph API Call
    Write-Output $response
    Remove-Item -Path $BodyFile -Force  # Clean up the temporary file
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to grant the requested permission to the Managed Identity"
    }

    Write-Host "The requested permission has been successfully assigned to the Managed Identity" -ForegroundColor DarkGreen
} else {
    Write-Host "The requested permission is already assigned to the Managed Identity" -ForegroundColor Green
}