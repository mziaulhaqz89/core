
param()

# Dynamics 365 endpoint
#$D365Endpoint = "https://mzhdev.crm4.dynamics.com/api/data/v9.0/contacts?`$select=firstname,lastname"
$D365Endpoint = "https://mzhdev.crm4.dynamics.com/api/data/v9.0/msdyn_solutioncomponentsummaries?`$filter=(msdyn_solutionid%20eq%20d792f061-a28c-f011-b4cc-7c1e52362bef)&`$select=msdyn_displayname,msdyn_schemaname,msdyn_componenttype,msdyn_componenttypename&`$orderby=msdyn_componenttype"

function Get-AccessTokenForDataverse {
    try {
        Write-Host "🔑 Getting access token for Dataverse using MSAL..." -ForegroundColor Cyan
        
        if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
            throw "MSAL.PS module not available. Please install it with: Install-Module MSAL.PS"
        }
        
        Import-Module MSAL.PS -Force
        
        # Get token using MSAL
        $clientId = "51f81489-12ee-4a9e-aaae-a2591f45987d" # PowerShell client ID
        $authority = "https://login.microsoftonline.com/common"
        $scopes = @("https://mzhdev.crm4.dynamics.com/.default")
        
        $token = Get-MsalToken -ClientId $clientId -Authority $authority -Scopes $scopes -Interactive
        
        if ($token) {
            Write-Host "✅ Access token obtained via MSAL" -ForegroundColor Green
            return $token.AccessToken
        } else {
            throw "Failed to obtain access token from MSAL"
        }
    }
    catch {
        throw "Failed to get access token: $($_.Exception.Message)"
    }
}

function Invoke-D365WebApi {
    param(
        [string]$Endpoint,
        [string]$AccessToken
    )
    
    try {
        Write-Host "🌐 Calling Dynamics 365 Web API..." -ForegroundColor Cyan
        Write-Host "Endpoint: $Endpoint" -ForegroundColor Gray
        
        # REST API call with bearer token
        $headers = @{
            "Accept" = "application/json"
            "OData-MaxVersion" = "4.0"
            "OData-Version" = "4.0"
            "Prefer" = "odata.include-annotations=*"
            "Authorization" = "Bearer $AccessToken"
        }
        
        $response = Invoke-RestMethod -Uri $Endpoint -Method Get -Headers $headers
        
        Write-Host "✅ API call successful!" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "❌ API call failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        }
        throw
    }
}

function Format-ContactsOutput {
    <#
    .SYNOPSIS
    Formats and displays the contacts data
    #>
    param($ContactsData)
    
    Write-Host "`n📋 Contacts Retrieved:" -ForegroundColor Magenta
    Write-Host "======================" -ForegroundColor Magenta
    
    if ($ContactsData.value -and $ContactsData.value.Count -gt 0) {
        Write-Host "Total contacts found: $($ContactsData.value.Count)" -ForegroundColor Yellow
        Write-Host ""
        
        # Display contacts in a formatted table
        $ContactsData.value | ForEach-Object {
            $firstName = if ($_.firstname) { $_.firstname } else { "(No first name)" }
            $lastName = if ($_.lastname) { $_.lastname } else { "(No last name)" }
            
            Write-Host "👤 $firstName $lastName" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "📊 Detailed JSON Response:" -ForegroundColor Cyan
        Write-Host "==========================" -ForegroundColor Cyan
        $ContactsData | ConvertTo-Json -Depth 10 | Write-Host
    }
    else {
        Write-Host "No contacts found." -ForegroundColor Yellow
    }
}

# Main script execution
try {
    Write-Host "🚀 Starting Dynamics 365 Contacts Retrieval with MSAL Authentication..." -ForegroundColor Magenta
    Write-Host ""
    
    # Get access token for API calls
    $accessToken = Get-AccessTokenForDataverse
    
    # Make the API call
    $contactsData = Invoke-D365WebApi -Endpoint $D365Endpoint -AccessToken $accessToken
    
    # Format and display results
    Format-ContactsOutput -ContactsData $contactsData
    
    Write-Host "`n🎉 Script completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n💡 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Install MSAL.PS module: Install-Module MSAL.PS" -ForegroundColor Gray
    Write-Host "2. Ensure you have access to the Dynamics 365 environment" -ForegroundColor Gray
    Write-Host "3. Make sure you can sign in interactively when prompted" -ForegroundColor Gray
    exit 1
}
