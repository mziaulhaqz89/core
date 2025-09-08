
param()

<#
.SYNOPSIS
    Dynamics 365 Solution Component Migration Script

.DESCRIPTION
    This script retrieve        # Display components in a formatted table
        $ComponentsData.value | ForEach-Object {
            $displayName = if ($_.msdyn_displayname) { $_.msdyn_displayname } else { "(No display name)" }
            $schemaName = if ($_.msdyn_schemaname) { $_.msdyn_schemaname } else { "(No schema name)" }
            $componentType = $_.msdyn_componenttype
            $componentTypeName = if ($_.msdyn_componenttypename) { $_.msdyn_componenttypename } else { "(No type name)" }
            $objectId = if ($_.msdyn_objectid) { $_.msdyn_objectid } else { "(No object ID)" }
            
            Write-Host "🔧 $displayName" -ForegroundColor White
            Write-Host "   Schema: $schemaName" -ForegroundColor Gray
            Write-Host "   Object ID: $objectId" -ForegroundColor Gray
            Write-Host "   Type: $componentType ($componentTypeName)" -ForegroundColor Gray
            Write-Host ""
        }ution components from a Dynamics 365 environment and 
    automatically migrates them to appropriate target solutions based on component type:
    
    - Component Type 1 (Entity) -> main solution
    - Component Type 10112 (Connection Reference) -> connectionreference solution  
    - Component Type 29 (Process/Flow) -> flows solution
    - Component Type 61 (Web Resource) -> webresources solution
    - Component Type 91,92 (Plugin Assembly/SDK Message) -> plugins solution

.REQUIREMENTS
    - MSAL.PS PowerShell module
    - Microsoft Power Platform CLI (PAC)
    - Access to Dynamics 365 environment
    - Target solutions must exist in the environment

.AUTHOR
    Generated for solution component management
#>

# Dynamics 365 base endpoint
$D365BaseEndpoint = "https://mzhdev.crm4.dynamics.com/api/data/v9.0"

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

function Get-SolutionId {
    <#
    .SYNOPSIS
    Gets the solution ID from Dataverse by solution unique name
    #>
    param(
        [string]$SolutionName,
        [string]$AccessToken,
        [string]$BaseEndpoint
    )
    
    try {
        Write-Host "🔍 Looking up solution ID for '$SolutionName'..." -ForegroundColor Cyan
        
        $solutionEndpoint = "$BaseEndpoint/solutions?`$filter=uniquename eq '$SolutionName'&`$select=solutionid,uniquename,friendlyname"
        $solutionResponse = Invoke-D365WebApi -Endpoint $solutionEndpoint -AccessToken $AccessToken
        
        if ($solutionResponse.value -and $solutionResponse.value.Count -gt 0) {
            $solution = $solutionResponse.value[0]
            $solutionId = $solution.solutionid
            Write-Host "✅ Found solution: $($solution.friendlyname) (ID: $solutionId)" -ForegroundColor Green
            return $solutionId
        } else {
            throw "Solution '$SolutionName' not found in the environment"
        }
    }
    catch {
        Write-Host "❌ Failed to get solution ID: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Format-ComponentsOutput {
    <#
    .SYNOPSIS
    Formats and displays the solution components data
    #>
    param($ComponentsData)
    
    Write-Host "`n📋 Solution Components Retrieved:" -ForegroundColor Magenta
    Write-Host "=================================" -ForegroundColor Magenta
    
    if ($ComponentsData.value -and $ComponentsData.value.Count -gt 0) {
        Write-Host "Total components found: $($ComponentsData.value.Count)" -ForegroundColor Yellow
        Write-Host ""
        
        # Display components in a formatted table
        $ComponentsData.value | ForEach-Object {
            $displayName = if ($_.msdyn_displayname) { $_.msdyn_displayname } else { "(No display name)" }
            $schemaName = if ($_.msdyn_schemaname) { $_.msdyn_schemaname } else { "(No schema name)" }
            $componentType = $_.msdyn_componenttype
            $componentTypeName = if ($_.msdyn_componenttypename) { $_.msdyn_componenttypename } else { "(No type name)" }
            
            Write-Host "� $displayName" -ForegroundColor White
            Write-Host "   Schema: $schemaName" -ForegroundColor Gray
            Write-Host "   Type: $componentType ($componentTypeName)" -ForegroundColor Gray
            Write-Host ""
        }
        
        Write-Host "📊 Detailed JSON Response:" -ForegroundColor Cyan
        Write-Host "==========================" -ForegroundColor Cyan
        $ComponentsData | ConvertTo-Json -Depth 10 | Write-Host
    }
    else {
        Write-Host "No components found." -ForegroundColor Yellow
    }
}

function Test-TargetSolutionsExist {
    <#
    .SYNOPSIS
    Checks if target solutions exist in the environment
    #>
    
    Write-Host "`n🔍 Checking if target solutions exist..." -ForegroundColor Cyan
    
    $targetSolutions = @("main", "connectionreference", "flows", "webresources", "plugins")
    $existingSolutions = @()
    $missingSolutions = @()
    
    try {
        # Get list of solutions
        $solutionListOutput = pac solution list --json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $solutions = $solutionListOutput | ConvertFrom-Json
            $existingSolutionNames = $solutions | ForEach-Object { $_.SolutionUniqueName }
            
            foreach ($targetSolution in $targetSolutions) {
                if ($existingSolutionNames -contains $targetSolution) {
                    $existingSolutions += $targetSolution
                    Write-Host "✅ Found: $targetSolution" -ForegroundColor Green
                } else {
                    $missingSolutions += $targetSolution
                    Write-Host "❌ Missing: $targetSolution" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "⚠️ Could not retrieve solution list. Proceeding anyway..." -ForegroundColor Yellow
            return $true
        }
    }
    catch {
        Write-Host "⚠️ Error checking solutions: $($_.Exception.Message). Proceeding anyway..." -ForegroundColor Yellow
        return $true
    }
    
    if ($missingSolutions.Count -gt 0) {
        Write-Host "`n⚠️ Missing Solutions:" -ForegroundColor Yellow
        $missingSolutions | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
        Write-Host "`n💡 You may need to create these solutions first or update the script with correct solution names." -ForegroundColor Yellow
        
        Write-Host "`n❓ Do you want to continue anyway? (Y/N): " -ForegroundColor Yellow -NoNewline
        $continueResponse = Read-Host
        return ($continueResponse -eq 'Y' -or $continueResponse -eq 'y')
    }
    
    Write-Host "`n✅ All target solutions found!" -ForegroundColor Green
    return $true
}

function Get-TargetSolutionName {
    <#
    .SYNOPSIS
    Maps component types to target solution names
    #>
    param($ComponentType)
    
    switch ($ComponentType) {
        10112 { return "connectionreference" }  # Connection Reference -> connectionreference solution
        29 { return "flows" }         # Process -> flows solution
        61 { return "webresources" }  # Web Resource -> webresources solution
        91 { return "plugins" }       # Plugin Assembly -> plugins solution
        92 { return "plugins" }       # SDK Message Processing Step -> plugins solution
        default { return "main" }      # Unknown type -> main solution
    }
}

function Move-ComponentToSolution {
    <#
    .SYNOPSIS
    Moves a component to the appropriate target solution using PAC CLI
    Uses ObjectId as the primary identifier for reliability
    #>
    param(
        [string]$ComponentType,
        [string]$TargetSolution,
        [string]$DisplayName,
        [string]$ObjectId
    )
    
    try {
        Write-Host "🔄 Moving component '$DisplayName' to solution '$TargetSolution'..." -ForegroundColor Cyan
        
        # Validate ObjectId is available
        if (-not $ObjectId -or $ObjectId -eq "(No object ID)" -or [string]::IsNullOrWhiteSpace($ObjectId)) {
            Write-Host "❌ No ObjectId available for component '$DisplayName'" -ForegroundColor Red
            return $false
        }
        
        Write-Host "Using ObjectId as identifier: $ObjectId" -ForegroundColor Gray
        
        # Build PAC CLI command - use special handling for Connection Reference
        $pacCommand = if ($ComponentType -eq 10112) {
            "pac solution add-solution-component --solutionUniqueName `"$TargetSolution`" --component `"$ObjectId`" --componentType `"ConnectionReference`""
        } else {
            "pac solution add-solution-component --solutionUniqueName `"$TargetSolution`" --component `"$ObjectId`" --componentType $ComponentType"
        }
        
        Write-Host "Executing: $pacCommand" -ForegroundColor Gray
        
        # Execute the PAC CLI command
        $result = Invoke-Expression $pacCommand 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully moved '$DisplayName' to '$TargetSolution' solution" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Failed to move '$DisplayName' to '$TargetSolution' solution" -ForegroundColor Red
            Write-Host "Error output: $result" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Exception while moving component '$DisplayName': $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Process-ComponentMigration {
    <#
    .SYNOPSIS
    Processes all components and moves them to appropriate solutions
    #>
    param($ComponentsData)
    
    Write-Host "`n🚀 Starting Component Migration Process..." -ForegroundColor Magenta
    Write-Host "==========================================" -ForegroundColor Magenta
    
    if (-not $ComponentsData.value -or $ComponentsData.value.Count -eq 0) {
        Write-Host "No components to migrate." -ForegroundColor Yellow
        return
    }
    
    $migrationResults = @{
        Total = 0
        Successful = 0
        Failed = 0
        Skipped = 0
        ByTarget = @{}
    }
    
    foreach ($component in $ComponentsData.value) {
        $migrationResults.Total++
        
        $componentType = $component.msdyn_componenttype
        $displayName = if ($component.msdyn_displayname) { $component.msdyn_displayname } else { "Unknown Component" }
        $schemaName = $component.msdyn_schemaname
        $objectId = $component.msdyn_objectid
        $targetSolution = Get-TargetSolutionName -ComponentType $componentType
        
        Write-Host "`n📦 Processing: $displayName (Type: $componentType)" -ForegroundColor White
        
        if ($targetSolution) {
            # Initialize counter for target solution if not exists
            if (-not $migrationResults.ByTarget.ContainsKey($targetSolution)) {
                $migrationResults.ByTarget[$targetSolution] = @{ Success = 0; Failed = 0 }
            }
            
            $success = Move-ComponentToSolution -ComponentType $componentType -TargetSolution $targetSolution -DisplayName $displayName -ObjectId $objectId
            
            if ($success) {
                $migrationResults.Successful++
                $migrationResults.ByTarget[$targetSolution].Success++
            } else {
                $migrationResults.Failed++
                $migrationResults.ByTarget[$targetSolution].Failed++
            }
        } else {
            Write-Host "⚠️ No target solution mapping found for component type $componentType. Skipping..." -ForegroundColor Yellow
            $migrationResults.Skipped++
        }
    }
    
    # Display migration summary
    Write-Host "`n📊 Migration Summary:" -ForegroundColor Magenta
    Write-Host "====================" -ForegroundColor Magenta
    Write-Host "Total Components: $($migrationResults.Total)" -ForegroundColor White
    Write-Host "Successful: $($migrationResults.Successful)" -ForegroundColor Green
    Write-Host "Failed: $($migrationResults.Failed)" -ForegroundColor Red
    Write-Host "Skipped: $($migrationResults.Skipped)" -ForegroundColor Yellow
    
    Write-Host "`n📈 By Target Solution:" -ForegroundColor Cyan
    foreach ($target in $migrationResults.ByTarget.Keys) {
        $stats = $migrationResults.ByTarget[$target]
        Write-Host "  $target`: Success=$($stats.Success), Failed=$($stats.Failed)" -ForegroundColor Gray
    }
}

# Main script execution
try {
    Write-Host "🚀 Starting Dynamics 365 Solution Component Migration with MSAL Authentication..." -ForegroundColor Magenta
    Write-Host ""
    
    # Check if PAC CLI is available
    try {
        $pacVersion = pac help | Select-Object -First 1
        Write-Host "✅ PAC CLI detected" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ PAC CLI not found. Please install Microsoft Power Platform CLI first." -ForegroundColor Red
        Write-Host "💡 Download from: https://aka.ms/PowerPlatformCLI" -ForegroundColor Yellow
        exit 1
    }
    
    # Prompt for feature solution name
    Write-Host "`n📝 Please provide the feature solution details:" -ForegroundColor Yellow
    Write-Host "Enter the unique name of the feature solution (e.g., 'FeatureSolution1'):" -ForegroundColor Cyan -NoNewline
    $featureSolutionName = Read-Host " "
    
    if ([string]::IsNullOrWhiteSpace($featureSolutionName)) {
        throw "Feature solution name is required. Please provide a valid solution name."
    }
    
    Write-Host "Using feature solution: '$featureSolutionName'" -ForegroundColor Green
    
    # Get access token for API calls
    $accessToken = Get-AccessTokenForDataverse
    
    # Get the solution ID from Dataverse
    $solutionId = Get-SolutionId -SolutionName $featureSolutionName -AccessToken $accessToken -BaseEndpoint $D365BaseEndpoint
    
    # Build the endpoint for solution components
    $componentsEndpoint = "$D365BaseEndpoint/msdyn_solutioncomponentsummaries?`$filter=(msdyn_solutionid eq $solutionId)&`$select=msdyn_displayname,msdyn_schemaname,msdyn_componenttype,msdyn_componenttypename,msdyn_objectid&`$orderby=msdyn_componenttype"
    
    # Make the API call to get solution components
    $componentsData = Invoke-D365WebApi -Endpoint $componentsEndpoint -AccessToken $accessToken
    
    # Format and display results
    Format-ComponentsOutput -ComponentsData $componentsData
    
    # Ask user if they want to proceed with migration
    Write-Host "`n❓ Do you want to proceed with component migration? (Y/N): " -ForegroundColor Yellow -NoNewline
    $userResponse = Read-Host
    
    if ($userResponse -eq 'Y' -or $userResponse -eq 'y') {
        # Check if target solutions exist
        $shouldContinue = Test-TargetSolutionsExist
        
        if ($shouldContinue) {
            # Process component migration
            Process-ComponentMigration -ComponentsData $componentsData
        } else {
            Write-Host "Migration cancelled due to missing solutions." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Migration cancelled by user." -ForegroundColor Yellow
    }
    
    Write-Host "`n🎉 Script completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n💡 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Install MSAL.PS module: Install-Module MSAL.PS" -ForegroundColor Gray
    Write-Host "2. Install PAC CLI: https://aka.ms/PowerPlatformCLI" -ForegroundColor Gray
    Write-Host "3. Ensure you have access to the Dynamics 365 environment" -ForegroundColor Gray
    Write-Host "4. Make sure you can sign in interactively when prompted" -ForegroundColor Gray
    Write-Host "5. Verify target solutions exist in your environment" -ForegroundColor Gray
    exit 1
}
