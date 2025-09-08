#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Retrieves contacts from Dynamics 365 using Web API with personal credentials
.DESCRIPTION
    This script calls the Dynamics 365 Web API to retrieve contacts with firstname and lastname fields.
    It uses your personal login credentials through the Power Platform CLI (pac) for authentication.
.EXAMPLE
    ./get-contacts.ps1
#>

param()

# Dynamics 365 endpoint
$D365Endpoint = "https://mzhdev.crm4.dynamics.com/api/data/v9.0/contacts?`$select=firstname,lastname"

function Ensure-PacAuthentication {
    <#
    .SYNOPSIS
    Ensures user is authenticated with Power Platform CLI using personal credentials
    #>
    try {
        Write-Host "🔐 Checking Power Platform CLI authentication..." -ForegroundColor Cyan
        
        # Check if PAC CLI is available
        $pacVersion = pac --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Power Platform CLI not found" -ForegroundColor Yellow
            return $null
        }
        
        Write-Host "PAC CLI Version: $pacVersion" -ForegroundColor Gray
        
        # Check if user is authenticated with pac
        $authOutput = pac auth list 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Not authenticated with Power Platform CLI" -ForegroundColor Red
            Write-Host "📝 Starting interactive authentication..." -ForegroundColor Yellow
            
            # Prompt for interactive authentication
            Write-Host "Please authenticate with your personal credentials when prompted." -ForegroundColor Yellow
            pac auth create --url https://mzhdev.crm4.dynamics.com
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "⚠️  PAC authentication failed, continuing with other methods..." -ForegroundColor Yellow
                return $null
            }
        }
        
        # Try to get auth info in JSON format
        try {
            $authList = pac auth list --json 2>$null | ConvertFrom-Json
            $currentAuth = $authList | Where-Object { $_.IsActive -eq $true }
            
            if ($currentAuth) {
                Write-Host "✅ PAC CLI authenticated as: $($currentAuth.FriendlyName)" -ForegroundColor Green
                Write-Host "🏢 Environment: $($currentAuth.Url)" -ForegroundColor Green
                return $currentAuth
            }
        }
        catch {
            Write-Host "⚠️  Could not parse PAC auth info, continuing with other methods..." -ForegroundColor Yellow
        }
        
        return $null
    }
    catch {
        Write-Host "⚠️  PAC CLI error: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-AccessTokenForDataverse {
    <#
    .SYNOPSIS
    Gets access token for Dataverse using personal credentials
    #>
    try {
        Write-Host "🔑 Getting access token for Dataverse..." -ForegroundColor Cyan
        
        # Method 1: Try Azure CLI first
        Write-Host "Trying Azure CLI authentication..." -ForegroundColor Gray
        try {
            # Check if Azure CLI is available and logged in
            $azAccount = az account show --query "user.name" --output tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and $azAccount) {
                Write-Host "✅ Azure CLI authenticated as: $azAccount" -ForegroundColor Green
                
                # Get access token for Dynamics 365
                $tokenResult = az account get-access-token --resource "https://mzhdev.crm4.dynamics.com/" --query "accessToken" --output tsv 2>$null
                
                if ($LASTEXITCODE -eq 0 -and $tokenResult) {
                    Write-Host "✅ Access token obtained via Azure CLI" -ForegroundColor Green
                    return $tokenResult.Trim()
                }
            } else {
                Write-Host "⚠️  Azure CLI not authenticated. Please run: az login" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "⚠️  Azure CLI error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Method 2: Try using Microsoft.Xrm.Data.PowerShell module
        Write-Host "Trying Microsoft.Xrm.Data.PowerShell module..." -ForegroundColor Gray
        try {
            if (Get-Module -ListAvailable -Name Microsoft.Xrm.Data.PowerShell) {
                Import-Module Microsoft.Xrm.Data.PowerShell -Force
                
                # Connect to Dynamics 365
                $conn = Connect-CrmOnlineDiscovery -ServerUrl "https://mzhdev.crm4.dynamics.com" -InteractiveMode
                
                if ($conn) {
                    Write-Host "✅ Connected via Microsoft.Xrm.Data.PowerShell" -ForegroundColor Green
                    # Store connection for later use
                    $global:CrmConnection = $conn
                    return "XRM_MODULE_AUTH"
                }
            } else {
                Write-Host "ℹ️  Microsoft.Xrm.Data.PowerShell module not available" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "⚠️  XRM module error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Method 3: Try using MSAL (Microsoft Authentication Library)
        Write-Host "Trying MSAL.PS module..." -ForegroundColor Gray
        try {
            if (Get-Module -ListAvailable -Name MSAL.PS) {
                Import-Module MSAL.PS -Force
                
                # Get token using MSAL
                $clientId = "51f81489-12ee-4a9e-aaae-a2591f45987d" # PowerShell client ID
                $authority = "https://login.microsoftonline.com/common"
                $scopes = @("https://mzhdev.crm4.dynamics.com/.default")
                
                $token = Get-MsalToken -ClientId $clientId -Authority $authority -Scopes $scopes -Interactive
                
                if ($token) {
                    Write-Host "✅ Access token obtained via MSAL" -ForegroundColor Green
                    return $token.AccessToken
                }
            } else {
                Write-Host "ℹ️  MSAL.PS module not available" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "⚠️  MSAL error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        throw "Unable to obtain access token. Please install and authenticate with Azure CLI (az login) or install required PowerShell modules."
    }
    catch {
        throw "Failed to get access token: $($_.Exception.Message)"
    }
}

function Invoke-D365WebApi {
    <#
    .SYNOPSIS
    Makes a request to Dynamics 365 Web API
    #>
    param(
        [string]$Endpoint,
        [string]$AccessToken = $null
    )
    
    try {
        Write-Host "🌐 Calling Dynamics 365 Web API..." -ForegroundColor Cyan
        Write-Host "Endpoint: $Endpoint" -ForegroundColor Gray
        
        # If using XRM module connection
        if ($AccessToken -eq "XRM_MODULE_AUTH" -and $global:CrmConnection) {
            Write-Host "Using XRM module connection..." -ForegroundColor Gray
            
            # Use XRM module to make the call
            $fetchXml = @"
<fetch>
  <entity name="contact">
    <attribute name="firstname" />
    <attribute name="lastname" />
  </entity>
</fetch>
"@
            
            $result = Get-CrmRecords -conn $global:CrmConnection -EntityLogicalName "contact" -FetchXml $fetchXml
            
            # Convert to Web API format
            $webApiResult = @{
                value = $result.CrmRecords | ForEach-Object {
                    @{
                        firstname = $_.firstname
                        lastname = $_.lastname
                    }
                }
            }
            
            Write-Host "✅ API call successful via XRM module!" -ForegroundColor Green
            return $webApiResult
        }
        
        # Standard REST API call with bearer token
        $headers = @{
            "Accept" = "application/json"
            "OData-MaxVersion" = "4.0"
            "OData-Version" = "4.0"
            "Prefer" = "odata.include-annotations=*"
        }
        
        if ($AccessToken -and $AccessToken -ne "XRM_MODULE_AUTH") {
            $headers["Authorization"] = "Bearer $AccessToken"
        }
        
        $response = Invoke-RestMethod -Uri $Endpoint -Method Get -Headers $headers
        
        Write-Host "✅ API call successful!" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "❌ API call failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            Write-Host "Status Code: $statusCode" -ForegroundColor Red
            
            # Try to get more detailed error information
            try {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorContent = $reader.ReadToEnd()
                Write-Host "Error Details: $errorContent" -ForegroundColor Red
            }
            catch {
                # Ignore if we can't read the error stream
            }
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
    Write-Host "🚀 Starting Dynamics 365 Contacts Retrieval with Personal Credentials..." -ForegroundColor Magenta
    Write-Host ""
    
    # Try PAC authentication (optional)
    $authProfile = Ensure-PacAuthentication
    
    # Get access token for API calls (this is the main authentication method)
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
    Write-Host "1. Install Azure CLI and run: az login" -ForegroundColor Gray
    Write-Host "2. Or install MSAL.PS module: Install-Module MSAL.PS" -ForegroundColor Gray
    Write-Host "3. Or install XRM module: Install-Module Microsoft.Xrm.Data.PowerShell" -ForegroundColor Gray
    Write-Host "4. Ensure you have access to the Dynamics 365 environment" -ForegroundColor Gray
    exit 1
}
