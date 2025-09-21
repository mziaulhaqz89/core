param(
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    [Parameter(Mandatory=$false)]
    [string]$ClientId,
    [Parameter(Mandatory=$false)]
    [string]$ClientSecret,
    [Parameter(Mandatory=$false)]
    [string]$D365BaseEndpoint
)

# Function to load environment variables from .env file
function Load-EnvFile {
    param([string]$Path = ".\.env")
    
    if (Test-Path $Path) {
        Write-Host "📄 Loading environment variables from $Path" -ForegroundColor Green
        Get-Content $Path | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$' -and !$_.StartsWith('#')) {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                [Environment]::SetEnvironmentVariable($name, $value, [EnvironmentVariableTarget]::Process)
                Write-Host "  ✅ Loaded: $name" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "⚠️ No .env file found at $Path" -ForegroundColor Yellow
        Write-Host "💡 Create a .env file from .env.example and add your credentials" -ForegroundColor Yellow
    }
}

# Load environment variables from .env file
Load-EnvFile

# Set configuration with precedence: Parameter > Environment Variable > Default
if (-not $TenantId) { $TenantId = $env:AZURE_TENANT_ID ?? "d7d483b3-60d3-4211-a15e-9c2a090d2136" }
if (-not $ClientId) { $ClientId = $env:AZURE_CLIENT_ID }
if (-not $ClientSecret) { $ClientSecret = $env:AZURE_CLIENT_SECRET }
if (-not $D365BaseEndpoint) { $D365BaseEndpoint = $env:D365_BASE_ENDPOINT ?? "https://mzhdev.crm4.dynamics.com/api/data/v9.0" }

# Validate required credentials
if (-not $ClientId -or -not $ClientSecret) {
    Write-Host "❌ Missing required credentials!" -ForegroundColor Red
    Write-Host "Please provide ClientId and ClientSecret via:" -ForegroundColor Yellow
    Write-Host "  1. Parameters: -ClientId 'your-id' -ClientSecret 'your-secret'" -ForegroundColor Gray
    Write-Host "  2. Environment variables: AZURE_CLIENT_ID and AZURE_CLIENT_SECRET" -ForegroundColor Gray
    Write-Host "  3. .env file with AZURE_CLIENT_ID and AZURE_CLIENT_SECRET" -ForegroundColor Gray
    Write-Host "💡 Copy .env.example to .env and fill in your values" -ForegroundColor Cyan
    exit 1
}

function Get-AccessTokenForDataverse {
    <#
    .SYNOPSIS
    Gets access token for Dataverse using Service Principal (Client Credentials flow)
    #>
    try {
        Write-Host "🔑 Getting access token for Dataverse using Service Principal..." -ForegroundColor Cyan
        
        # Azure AD token endpoint
        $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        
        # Resource URL for Dataverse
        $resource = "https://mzhdev.crm4.dynamics.com/.default"
        
        # Prepare the request body
        $body = @{
            client_id = $ClientId
            client_secret = $ClientSecret
            scope = $resource
            grant_type = "client_credentials"
        }
        
        Write-Host "Requesting token from Azure AD..." -ForegroundColor Gray
        Write-Host "Tenant ID: $TenantId" -ForegroundColor Gray
        Write-Host "Client ID: $ClientId" -ForegroundColor Gray
        Write-Host "Resource: $resource" -ForegroundColor Gray
        
        # Make the token request
        $response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        
        if ($response.access_token) {
            Write-Host "✅ Access token obtained via Service Principal" -ForegroundColor Green
            Write-Host "Token expires in: $($response.expires_in) seconds" -ForegroundColor Gray
            return $response.access_token
        } else {
            throw "No access token received in response"
        }
    }
    catch {
        Write-Host "❌ Failed to get access token: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorDetails = $reader.ReadToEnd()
            Write-Host "Error details: $errorDetails" -ForegroundColor Red
        }
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
    param(
        $ComponentsData,
        [bool]$UseRootComponentsOnly = $false
    )
    
    Write-Host "`n📋 Solution Components Retrieved:" -ForegroundColor Magenta
    Write-Host "=================================" -ForegroundColor Magenta
    
    # Handle different data formats based on the API endpoint used
    $components = @()
    if ($UseRootComponentsOnly) {
        # Data from solutioncomponents table
        if ($ComponentsData.value -and $ComponentsData.value.Count -gt 0) {
            $components = $ComponentsData.value | ForEach-Object {
                [PSCustomObject]@{
                    DisplayName = "(Root Component - $(Get-ComponentTypeName -ComponentType $_.componenttype))"
                    ComponentType = $_.componenttype
                    ComponentTypeName = Get-ComponentTypeName -ComponentType $_.componenttype
                    ObjectId = $_.objectid
                    CreatedOn = $_.createdon
                    ModifiedOn = $_.modifiedon
                    RootComponentBehavior = $_.rootcomponentbehavior
                }
            }
        }
    } else {
        # Data from msdyn_solutioncomponentsummaries table
        if ($ComponentsData.value -and $ComponentsData.value.Count -gt 0) {
            $components = $ComponentsData.value | ForEach-Object {
                [PSCustomObject]@{
                    DisplayName = if ($_.msdyn_displayname) { $_.msdyn_displayname } else { "(No display name)" }
                    ComponentType = $_.msdyn_componenttype
                    ComponentTypeName = if ($_.msdyn_componenttypename) { $_.msdyn_componenttypename } else { "(No type name)" }
                    ObjectId = $_.msdyn_objectid
                    CreatedOn = $_.msdyn_createdon
                    ModifiedOn = $_.msdyn_modifiedon
                }
            }
        }
    }
    
    if ($components.Count -gt 0) {
        Write-Host "Total components found: $($components.Count)" -ForegroundColor Yellow
        
        if ($UseRootComponentsOnly) {
            Write-Host "✅ Filtered to root components only (explicitly added to solution)" -ForegroundColor Green
        }
        
        Write-Host ""
        
        # Prepare data for table formatting
        $tableData = $components | ForEach-Object {
            $displayName = $_.DisplayName
            $componentType = $_.ComponentType
            $componentTypeName = $_.ComponentTypeName
            
            # Truncate long names for better table display
            $truncatedDisplayName = if ($displayName.Length -gt 60) { $displayName.Substring(0, 57) + "..." } else { $displayName }
            $truncatedTypeName = if ($componentTypeName.Length -gt 35) { $componentTypeName.Substring(0, 32) + "..." } else { $componentTypeName }
            
            [PSCustomObject]@{
                "Display Name" = $truncatedDisplayName
                "Type ID" = $componentType
                "Type Name" = $truncatedTypeName
                "Object ID" = $_.ObjectId
            }
        }
        
        # Display the table with colors
        $headerFormat = "┌──────────────────────────────────────────────────────────────┬─────────┬─────────────────────────────────────┐"
        
        Write-Host $headerFormat -ForegroundColor Cyan
        Write-Host "│ Display Name                                                 │ Type ID │ Type Name                           │" -ForegroundColor Cyan
        
        $separatorFormat = "├──────────────────────────────────────────────────────────────┼─────────┼─────────────────────────────────────┤"
        
        Write-Host $separatorFormat -ForegroundColor Cyan
        
        foreach ($row in $tableData) {
            $displayNameFormatted = $row."Display Name".PadRight(60)
            $typeIdFormatted = $row."Type ID".ToString().PadRight(7)
            $typeNameFormatted = $row."Type Name".PadRight(35)
            
            Write-Host "│ " -ForegroundColor Cyan -NoNewline
            Write-Host $displayNameFormatted -ForegroundColor White -NoNewline
            Write-Host " │ " -ForegroundColor Cyan -NoNewline
            Write-Host $typeIdFormatted -ForegroundColor Yellow -NoNewline
            Write-Host " │ " -ForegroundColor Cyan -NoNewline
            Write-Host $typeNameFormatted -ForegroundColor Green -NoNewline
            Write-Host " │" -ForegroundColor Cyan
        }
        
        $footerFormat = "└──────────────────────────────────────────────────────────────┴─────────┴─────────────────────────────────────┘"
        
        Write-Host $footerFormat -ForegroundColor Cyan
        
        # Display component type summary
        Write-Host "`n📊 Component Type Summary:" -ForegroundColor Cyan
        Write-Host "─────────────────────────" -ForegroundColor Cyan
        $components | Group-Object ComponentType | Sort-Object Name | ForEach-Object {
            $typeName = ($_.Group[0].ComponentTypeName -replace "Customization\.Type_", "")
            Write-Host "  📦 Type $($_.Name): $($_.Count) components ($typeName)" -ForegroundColor White
        }
        
        Write-Host "`n💡 Tip: Use 'Y' to proceed with migration or 'N' to cancel" -ForegroundColor Yellow
        
        # Return the components for further processing
        return $components
    }
    else {
        Write-Host "No components found." -ForegroundColor Yellow
        return @()
    }
}

function Get-ComponentTypeName {
    <#
    .SYNOPSIS
    Gets a friendly name for component type IDs
    #>
    param($ComponentType)
    
    switch ($ComponentType) {
        1 { return "Entity" }
        2 { return "Attribute" }
        9 { return "Option Set" }
        10 { return "Entity Relationship" }
        16 { return "Display String" }
        20 { return "Role" }
        21 { return "Role Privilege" }
        24 { return "Form" }
        25 { return "Organization" }
        26 { return "Saved Query" }
        29 { return "Process/Flow" }
        31 { return "Report" }
        35 { return "Web Resource" }
        36 { return "Article Template" }
        37 { return "Contract Template" }
        38 { return "E-mail Template" }
        39 { return "Mail Merge Template" }
        44 { return "Duplicate Rule" }
        45 { return "Duplicate Rule Condition" }
        46 { return "Entity Map" }
        47 { return "Attribute Map" }
        48 { return "Ribbon Command" }
        50 { return "View" }
        59 { return "Chart" }
        60 { return "Form" }
        61 { return "Web Resource" }
        62 { return "Sitemap" }
        70 { return "Field Security Profile" }
        90 { return "Plugin Type" }
        91 { return "Plugin Assembly" }
        92 { return "SDK Message Processing Step" }
        93 { return "SDK Message Processing Step Image" }
        95 { return "Service Endpoint" }
        10112 { return "Connection Reference" }
        default { return "Unknown Type ($ComponentType)" }
    }
}

function Test-TargetSolutionsExist {
    <#
    .SYNOPSIS
    Checks if target solutions exist in the environment
    #>
    
    Write-Host "`n🔍 Checking if target solutions exist..." -ForegroundColor Cyan
    
    $targetSolutions = @("core", "connectionreference", "flows", "webresources", "plugins")
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
        default { return "core" }      # Unknown type -> core solution
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
    
    # Return affected solutions for export prompt
    return $migrationResults
}

# Main script execution
try {
    Write-Host "🚀 Starting Dynamics 365 Solution Component Migration with Service Principal Authentication..." -ForegroundColor Magenta
    Write-Host ""
    
    # Display authentication information
    Write-Host "🔐 Authentication Details:" -ForegroundColor Cyan
    Write-Host "  Tenant ID: $TenantId" -ForegroundColor Gray
    Write-Host "  Client ID: $ClientId" -ForegroundColor Gray
    Write-Host "  Authentication Method: Service Principal (Client Credentials)" -ForegroundColor Gray
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
    
    # Display component migration mapping
    Write-Host "`n🗺️  Component Migration Mapping:" -ForegroundColor Magenta
    Write-Host "══════════════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "This script will automatically migrate components from your feature solution to target solutions" -ForegroundColor Cyan
    Write-Host "based on their component types as follows:" -ForegroundColor Cyan
    Write-Host ""
    
    # Create a beautiful table showing the mapping
    Write-Host "┌─────────────┬─────────────────────────────────────────┬─────────────────────────────────┐" -ForegroundColor DarkCyan
    Write-Host "│ Component   │ Component Type                          │ Target Solution                 │" -ForegroundColor DarkCyan
    Write-Host "│ Type ID     │                                         │                                 │" -ForegroundColor DarkCyan
    Write-Host "├─────────────┼─────────────────────────────────────────┼─────────────────────────────────┤" -ForegroundColor DarkCyan
    
    # Connection Reference
    Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "10112".PadRight(11) -ForegroundColor Yellow -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "Connection Reference".PadRight(39) -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "connectionreference".PadRight(31) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    
    # Process/Flow
    Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "29".PadRight(11) -ForegroundColor Yellow -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "Process/Flow".PadRight(39) -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "flows".PadRight(31) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    
    # Web Resource
    Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "61".PadRight(11) -ForegroundColor Yellow -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "Web Resource".PadRight(39) -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "webresources".PadRight(31) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    
    # Plugin Assembly
    Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "91".PadRight(11) -ForegroundColor Yellow -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "Plugin Assembly".PadRight(39) -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "plugins".PadRight(31) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    
    # SDK Message Processing Step
    Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "92".PadRight(11) -ForegroundColor Yellow -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "SDK Message Processing Step".PadRight(39) -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "plugins".PadRight(31) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    
    # Default (All other types)
    Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "Others".PadRight(11) -ForegroundColor Yellow -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "All Other Component Types".PadRight(39) -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host "core".PadRight(31) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    
    Write-Host "└─────────────┴─────────────────────────────────────────┴─────────────────────────────────┘" -ForegroundColor DarkCyan
    
    Write-Host "`n📋 Migration Process:" -ForegroundColor Cyan
    Write-Host "  1️⃣  Retrieve components from your specified feature solution" -ForegroundColor Gray
    Write-Host "  2️⃣  Analyze each component's type" -ForegroundColor Gray
    Write-Host "  3️⃣  Move components to appropriate target solutions using PAC CLI" -ForegroundColor Gray
    Write-Host "  4️⃣  Provide detailed migration summary" -ForegroundColor Gray
    
    Write-Host "`n⚠️  Prerequisites:" -ForegroundColor Yellow
    Write-Host "  • Target solutions (core, connectionreference, flows, webresources, plugins) must exist" -ForegroundColor Gray
    Write-Host "  • Service principal must have appropriate permissions to modify solutions" -ForegroundColor Gray
    
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
    
    # Prompt user for component filtering option
    Write-Host "`n🔍 Component Filtering Options:" -ForegroundColor Magenta
    Write-Host "===============================" -ForegroundColor Magenta
    Write-Host "When you add components to a solution, Dynamics 365 can automatically include dependencies." -ForegroundColor Cyan
    Write-Host "For example, adding a form might also pull in the entire entity, views, and other components." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose how to filter the components for migration:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. " -ForegroundColor Green -NoNewline
    Write-Host "Root Components Only " -ForegroundColor White -NoNewline
    Write-Host "(Recommended) - Only migrate components you explicitly added" -ForegroundColor Gray
    Write-Host "2. " -ForegroundColor Yellow -NoNewline
    Write-Host "All Components " -ForegroundColor White -NoNewline
    Write-Host "- Migrate all components including auto-added dependencies" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter your choice (1 or 2): " -ForegroundColor Yellow -NoNewline
    $filterChoice = Read-Host " "
    
    # Validate choice
    while ($filterChoice -notin @('1', '2')) {
        Write-Host "❌ Invalid choice. Please enter 1 or 2: " -ForegroundColor Red -NoNewline
        $filterChoice = Read-Host " "
    }
    
    $useRootComponentsOnly = ($filterChoice -eq '1')
    
    if ($useRootComponentsOnly) {
        Write-Host "✅ Will filter to root components only (explicitly added components)" -ForegroundColor Green
        # Use the solutioncomponents table with rootcomponentbehavior filter for root components only
        # Include components where rootcomponentbehavior is 0, 1, or null (explicitly added components)
        # Exclude rootcomponentbehavior = 2 (shell only/dependencies)
        $componentsEndpoint = "$D365BaseEndpoint/solutioncomponents?`$filter=(_solutionid_value eq '$solutionId') and (rootcomponentbehavior ne 2)&`$select=componenttype,objectid,createdon,modifiedon,rootcomponentbehavior&`$expand=solutionid(`$select=uniquename,friendlyname)&`$orderby=componenttype"
    } else {
        Write-Host "✅ Will include all components (root + dependencies)" -ForegroundColor Green
        # Use the original detailed summary table for all components
        $componentsEndpoint = "$D365BaseEndpoint/msdyn_solutioncomponentsummaries?`$filter=(msdyn_solutionid eq $solutionId)&`$select=msdyn_displayname,msdyn_schemaname,msdyn_componenttype,msdyn_componenttypename,msdyn_objectid&`$orderby=msdyn_componenttype"
    }

    # Make the API call to get solution components
    $componentsData = Invoke-D365WebApi -Endpoint $componentsEndpoint -AccessToken $accessToken
    
    # Format and display results
    $components = Format-ComponentsOutput -ComponentsData $componentsData -UseRootComponentsOnly $useRootComponentsOnly
    
    if ($components.Count -eq 0) {
        Write-Host "No components found to migrate." -ForegroundColor Yellow
        return
    }
    
    # Ask user if they want to proceed with migration
    Write-Host "`n❓ Do you want to proceed with component migration? (Y/N): " -ForegroundColor Yellow -NoNewline
    $userResponse = Read-Host
    
    if ($userResponse -ne 'Y' -and $userResponse -ne 'y') {
        Write-Host "Migration cancelled by user." -ForegroundColor Yellow
        return
    }
    
    # Convert components to the format expected by Process-ComponentMigration
    $componentsDataForMigration = @{
        value = $components | ForEach-Object {
            [PSCustomObject]@{
                msdyn_componenttype = $_.ComponentType
                msdyn_displayname = $_.DisplayName
                msdyn_objectid = $_.ObjectId
            }
        }
    }
    
    # Check if target solutions exist
    $shouldContinue = Test-TargetSolutionsExist
    
    if ($shouldContinue) {
        # Process component migration
        $migrationResults = Process-ComponentMigration -ComponentsData $componentsDataForMigration
        
        # Show affected/updated solutions summary
        Write-Host "`n🎯 Affected Target Solutions Summary:" -ForegroundColor Magenta
        Write-Host "====================================" -ForegroundColor Magenta
        
        $affectedSolutions = @()
        if ($migrationResults.ByTarget -and $migrationResults.ByTarget.Keys.Count -gt 0) {
            Write-Host "The following target solutions have been updated with new components:" -ForegroundColor Cyan
            Write-Host ""
            
            foreach ($solutionName in ($migrationResults.ByTarget.Keys | Sort-Object)) {
                $stats = $migrationResults.ByTarget[$solutionName]
                if ($stats.Success -gt 0) {
                    $affectedSolutions += $solutionName
                    Write-Host "  ✅ " -ForegroundColor Green -NoNewline
                    Write-Host "$solutionName".PadRight(20) -ForegroundColor White -NoNewline
                    Write-Host " → " -ForegroundColor Gray -NoNewline
                    Write-Host "$($stats.Success) components added" -ForegroundColor Green
                }
            }
            
            if ($affectedSolutions.Count -eq 0) {
                Write-Host "  ⚠️  No target solutions were successfully updated." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ⚠️  No target solutions were affected." -ForegroundColor Yellow
        }
        
        # Ask user if they want to export affected solutions
        if ($affectedSolutions.Count -gt 0) {
            Write-Host "`n📦 Solution Export:" -ForegroundColor Magenta
            Write-Host "==================" -ForegroundColor Magenta
            Write-Host "The affected target solutions can now be exported to capture the new changes." -ForegroundColor Cyan
            Write-Host "This will version and export each solution using the export-solution.ps1 script." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Affected solutions to export:" -ForegroundColor Yellow
            foreach ($solution in $affectedSolutions) {
                Write-Host "  📁 $solution" -ForegroundColor White
            }
            Write-Host ""
            Write-Host "❓ Do you want to export the affected solutions now? (Y/N): " -ForegroundColor Yellow -NoNewline
            $exportResponse = Read-Host
            
            if ($exportResponse -eq 'Y' -or $exportResponse -eq 'y') {
                Write-Host "`n🚀 Starting solution export process..." -ForegroundColor Cyan
                
                foreach ($solutionName in $affectedSolutions) {
                    try {
                        Write-Host "`n📦 Exporting solution: $solutionName" -ForegroundColor Magenta
                        Write-Host "═══════════════════════════════════════" -ForegroundColor Magenta
                        
                        # Check if export-solution.ps1 exists
                        $exportScriptPath = "./export-solution.ps1"
                        if (-not (Test-Path $exportScriptPath)) {
                            Write-Host "❌ Export script not found at: $exportScriptPath" -ForegroundColor Red
                            Write-Host "💡 Please ensure export-solution.ps1 is in the current directory." -ForegroundColor Yellow
                            continue
                        }
                        
                        # Execute the export script for this solution
                        $exportCommand = "pwsh `"$exportScriptPath`" -SolutionName `"$solutionName`" -VersionType `"patch`""
                        Write-Host "Executing: $exportCommand" -ForegroundColor Gray
                        
                        $exportResult = Invoke-Expression $exportCommand 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "✅ Successfully exported solution: $solutionName" -ForegroundColor Green
                        } else {
                            Write-Host "❌ Failed to export solution: $solutionName" -ForegroundColor Red
                            Write-Host "Error output: $exportResult" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "❌ Exception while exporting solution '$solutionName': $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                Write-Host "`n🎉 Solution export process completed!" -ForegroundColor Green
            } else {
                Write-Host "`n📝 Solution export skipped." -ForegroundColor Cyan
                Write-Host "💡 You can export solutions later using: ./export-solution.ps1 -SolutionName `"YourSolutionName`"" -ForegroundColor Yellow
            }
        }
        
        # Ask user if they want to delete the feature solution
        Write-Host "`n🗑️  Feature Solution Cleanup:" -ForegroundColor Magenta
        Write-Host "=============================" -ForegroundColor Magenta
        Write-Host "Now that components have been migrated to their respective target solutions," -ForegroundColor Cyan
        Write-Host "you may want to delete the original feature solution '$featureSolutionName'." -ForegroundColor Cyan
        Write-Host ""
            Write-Host "⚠️  Warning: This action cannot be undone!" -ForegroundColor Red
            Write-Host "💡 Only proceed if you're certain all components have been migrated successfully." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "❓ Do you want to delete the feature solution '$featureSolutionName'? (Y/N): " -ForegroundColor Yellow -NoNewline
            $deleteResponse = Read-Host
            
            if ($deleteResponse -eq 'Y' -or $deleteResponse -eq 'y') {
                try {
                    Write-Host "`n🔄 Deleting feature solution '$featureSolutionName'..." -ForegroundColor Cyan
                    
                    # Execute PAC CLI command to delete the solution
                    $deleteCommand = "pac solution delete --solution-name `"$featureSolutionName`""
                    Write-Host "Executing: $deleteCommand" -ForegroundColor Gray
                    
                    $deleteResult = Invoke-Expression $deleteCommand 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✅ Successfully deleted feature solution '$featureSolutionName'" -ForegroundColor Green
                        Write-Host "🎯 All components have been migrated and the original solution has been cleaned up!" -ForegroundColor Green
                    } else {
                        Write-Host "❌ Failed to delete feature solution '$featureSolutionName'" -ForegroundColor Red
                        Write-Host "Error output: $deleteResult" -ForegroundColor Red
                        Write-Host "💡 You may need to delete it manually from the Power Platform admin center." -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "❌ Exception while deleting solution: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "💡 You may need to delete the solution manually from the Power Platform admin center." -ForegroundColor Yellow
                }
            } else {
                Write-Host "`n📝 Feature solution '$featureSolutionName' has been preserved." -ForegroundColor Cyan
                Write-Host "💡 You can delete it manually later if needed from the Power Platform admin center." -ForegroundColor Yellow
            }
    } else {
        Write-Host "Migration cancelled due to missing solutions." -ForegroundColor Yellow
    }
    
    Write-Host "`n🎉 Script completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n💡 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Verify service principal credentials are correct" -ForegroundColor Gray
    Write-Host "2. Ensure service principal has Dataverse permissions" -ForegroundColor Gray
    Write-Host "3. Install PAC CLI: https://aka.ms/PowerPlatformCLI" -ForegroundColor Gray
    Write-Host "4. Check network connectivity to Azure and Dataverse" -ForegroundColor Gray
    Write-Host "5. Verify target solutions exist in your environment" -ForegroundColor Gray
    exit 1
}
