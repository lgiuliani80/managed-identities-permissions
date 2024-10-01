<#
.SYNOPSIS
Assign a specific Application Permission to a Managed Identity in Azure AD.

.DESCRIPTION
The cmdlet *grants* a specific Application Permission to a Managed Identity in Azure AD.

REQUIREMENTS:
- the running user needs to have administrative permissions on the tenant
- the Azure CLI must be installed and authenticated in the tenant
- the specified Managed Identity must exist in the tenant

.PARAMETER TenantId
MANDATORY. The Tenant Id of the Azure AD tenant where the Managed Identity is located.

.PARAMETER ManagedIdentityName
MANDATORY. The display name of the Managed Identity to which the permission will be granted.

.PARAMETER APIAppId
OPTIONAL. The Client Id of the API Service Principal that represents the target API. Default is the Graph API Client Id.

.PARAMETER APIPermissionName
MANDATORY. The name of the Application Permission, inside the API specified in APIAppId, to be granted to the Managed Identity.
In most of the cases it will be a Graph API application permission name.

.EXAMPLE
PS> .\Grant-MIRole.ps1 -TenantID "your-tenant-id" -ManagedIdentityName "appservice-name" -GraphPermissionName Directory.Read.All

This example grants the "Directory.Read.All" permission to the Managed Identity named "appservice-name" in the specified tenant.

.NOTES
Author: Luca Giuliani (giulianil@microdoft.com)
Date: 2024-10-01
Version: 1.0
#>
param(
    [string][Parameter(Mandatory = $true)]$TenantID,
    [string][Parameter(Mandatory = $true)]$ManagedIdentityName,
    [string][Parameter(Mandatory = $false)]$APIAppId = "00000003-0000-0000-c000-000000000000", # default is Graph API Client Id (Fixed)
    [string][Parameter(Mandatory = $true)]$APIPermissionName
)

$ErrorActionPreference = "Stop"

# Get the API Service Principal from its Client Id for this tenant to retrieve its AppRoles [= Application Permissions] and Object Id
$GraphAPISP = az ad sp show --id $APIAppId | ConvertFrom-Json  # ==> GET https://graph.microsoft.com/v1.0/servicePrincipals(appid='<api-app-id>')
if ($LASTEXITCODE -ne 0) {
    throw "Failed to retrieve the API Service Principal"
}
$AllPermissions = $GraphAPISP.appRoles
# Get the AppRole Id for the requested permission
$GraphPermissionId = $AllPermissions | Where-Object {$_.value -eq $APIPermissionName} | Select-Object -ExpandProperty id
Write-Host "API Service Principal Object Id: $($GraphAPISP.id)" -ForegroundColor DarkCyan
Write-Host "The AppRole Id for the requested permission is: $GraphPermissionId" -ForegroundColor DarkCyan

# Get the Service Principal object that represents the specified Managed Identity
$MSISP = az ad sp list --display-name $ManagedIdentityName | ConvertFrom-Json | Select-Object -First 1  # ==> GET https://graph.microsoft.com/v1.0/servicePrincipals?$filter=displayName eq '$ManagedIdentityName'
if ($LASTEXITCODE -ne 0) {
    throw "Failed to retrieve the Managed Identity Service Principal"
}

$response = az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$($MSISP.id)/appRoleAssignments" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to retrieve the current permission assignments for the Managed Identity"
}
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