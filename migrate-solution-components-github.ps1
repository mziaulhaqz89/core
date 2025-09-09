param(
    [Parameter(Mandatory=$true)]
    [string]$FeatureSolutionName,
    
    [Parameter(Mandatory=$true)]
    [bool]$ProceedWithMigration,
    
    [Parameter(Mandatory=$true)]
    [bool]$ExportAffectedSolutions,
    
    [Parameter(Mandatory=$true)]
    [bool]$DeleteFeatureSolution,
    
    [Parameter(Mandatory=$false)]
    [string]$DataverseUrl = "https://mzhdev.crm4.dynamics.com"
)

# Dynamics 365 base endpoint
$D365BaseEndpoint = "$DataverseUrl/api/data/v9.0"

# GitHub Actions specific: Create log file
$LogFile = "migration-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with color
    Write-Host $Message -ForegroundColor $Color
    
    # Write to log file
    Add-Content -Path $LogFile -Value $logEntry
}

function Get-AccessTokenForDataverse {
    try {
        Write-LogMessage "🔑 Getting access token for Dataverse using MSAL..." "INFO" "Cyan"
        
        if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
            throw "MSAL.PS module not available. Please install it with: Install-Module MSAL.PS"
        }
        
        Import-Module MSAL.PS -Force
        
        # For GitHub Actions, we'll use device code flow or service principal
        # Check if we're in GitHub Actions environment
        if ($env:GITHUB_ACTIONS -eq "true") {
            Write-LogMessage "Running in GitHub Actions environment" "INFO" "Yellow"
            
            # Try to get token using service principal if available
            if ($env:TENANT_ID -and $env:CLIENT_ID -and $env:CLIENT_SECRET) {
                Write-LogMessage "Using service principal authentication..." "INFO" "Yellow"
                
                $clientCredential = [Microsoft.Identity.Client.ClientCredentialProvider]::ForClientSecret($env:CLIENT_SECRET)
                $token = Get-MsalToken -ClientId $env:CLIENT_ID -TenantId $env:TENANT_ID -ClientCredential $clientCredential -Scopes @("$DataverseUrl/.default")
            } else {
                Write-LogMessage "Service principal credentials not available. Using device code flow..." "WARN" "Yellow"
                # For GitHub Actions, this might not work well, but we'll try
                $token = Get-MsalToken -ClientId "51f81489-12ee-4a9e-aaae-a2591f45987d" -TenantId "common" -Scopes @("$DataverseUrl/.default") -DeviceCode
            }
        } else {
            # Interactive authentication for local runs
            $clientId = "51f81489-12ee-4a9e-aaae-a2591f45987d" # PowerShell client ID
            $authority = "https://login.microsoftonline.com/common"
            $scopes = @("$DataverseUrl/.default")
            
            $token = Get-MsalToken -ClientId $clientId -Authority $authority -Scopes $scopes -Interactive
        }
        
        if ($token) {
            Write-LogMessage "✅ Access token obtained via MSAL" "INFO" "Green"
            return $token.AccessToken
        } else {
            throw "Failed to obtain access token from MSAL"
        }
    }
    catch {
        Write-LogMessage "Failed to get access token: $($_.Exception.Message)" "ERROR" "Red"
        throw
    }
}

function Invoke-D365WebApi {
    param(
        [string]$Endpoint,
        [string]$AccessToken
    )
    
    try {
        Write-LogMessage "🌐 Calling Dynamics 365 Web API..." "INFO" "Cyan"
        Write-LogMessage "Endpoint: $Endpoint" "INFO" "Gray"
        
        # REST API call with bearer token
        $headers = @{
            "Accept" = "application/json"
            "OData-MaxVersion" = "4.0"
            "OData-Version" = "4.0"
            "Prefer" = "odata.include-annotations=*"
            "Authorization" = "Bearer $AccessToken"
        }
        
        $response = Invoke-RestMethod -Uri $Endpoint -Method Get -Headers $headers
        
        Write-LogMessage "✅ API call successful!" "INFO" "Green"
        return $response
    }
    catch {
        Write-LogMessage "❌ API call failed: $($_.Exception.Message)" "ERROR" "Red"
        if ($_.Exception.Response) {
            Write-LogMessage "Status Code: $($_.Exception.Response.StatusCode)" "ERROR" "Red"
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
        Write-LogMessage "🔍 Looking up solution ID for '$SolutionName'..." "INFO" "Cyan"
        
        $solutionEndpoint = "$BaseEndpoint/solutions?`$filter=uniquename eq '$SolutionName'&`$select=solutionid,uniquename,friendlyname"
        $solutionResponse = Invoke-D365WebApi -Endpoint $solutionEndpoint -AccessToken $AccessToken
        
        if ($solutionResponse.value -and $solutionResponse.value.Count -gt 0) {
            $solution = $solutionResponse.value[0]
            $solutionId = $solution.solutionid
            Write-LogMessage "✅ Found solution: $($solution.friendlyname) (ID: $solutionId)" "INFO" "Green"
            return $solutionId
        } else {
            throw "Solution '$SolutionName' not found in the environment"
        }
    }
    catch {
        Write-LogMessage "❌ Failed to get solution ID: $($_.Exception.Message)" "ERROR" "Red"
        throw
    }
}

function Format-ComponentsOutput {
    <#
    .SYNOPSIS
    Formats and displays the solution components data
    #>
    param($ComponentsData)
    
    Write-LogMessage "`n📋 Solution Components Retrieved:" "INFO" "Magenta"
    Write-LogMessage "=================================" "INFO" "Magenta"
    
    if ($ComponentsData.value -and $ComponentsData.value.Count -gt 0) {
        Write-LogMessage "Total components found: $($ComponentsData.value.Count)" "INFO" "Yellow"
        Write-LogMessage "" "INFO" "White"
        
        # Create results summary for JSON output
        $componentsSummary = @{
            TotalComponents = $ComponentsData.value.Count
            ComponentsByType = @{}
            Components = @()
        }
        
        # Prepare data for table formatting and JSON output
        $tableData = $ComponentsData.value | ForEach-Object {
            $displayName = if ($_.msdyn_displayname) { $_.msdyn_displayname } else { "(No display name)" }
            $componentType = $_.msdyn_componenttype
            $componentTypeName = if ($_.msdyn_componenttypename) { $_.msdyn_componenttypename } else { "(No type name)" }
            
            # Add to components summary
            $componentsSummary.Components += @{
                DisplayName = $displayName
                ComponentType = $componentType
                ComponentTypeName = $componentTypeName
                ObjectId = $_.msdyn_objectid
            }
            
            # Update component type count
            if (-not $componentsSummary.ComponentsByType.ContainsKey($componentType)) {
                $componentsSummary.ComponentsByType[$componentType] = @{
                    Count = 0
                    TypeName = $componentTypeName
                }
            }
            $componentsSummary.ComponentsByType[$componentType].Count++
            
            # Truncate long names for better table display
            $truncatedDisplayName = if ($displayName.Length -gt 60) { $displayName.Substring(0, 57) + "..." } else { $displayName }
            $truncatedTypeName = if ($componentTypeName.Length -gt 35) { $componentTypeName.Substring(0, 32) + "..." } else { $componentTypeName }
            
            [PSCustomObject]@{
                "Display Name" = $truncatedDisplayName
                "Type ID" = $componentType
                "Type Name" = $truncatedTypeName
            }
        }
        
        # Save components summary to JSON file
        $componentsSummary | ConvertTo-Json -Depth 3 | Out-File -FilePath "migration-results.json" -Encoding UTF8
        
        # Display the table
        Write-LogMessage "┌──────────────────────────────────────────────────────────────┬─────────┬─────────────────────────────────────┐" "INFO" "Cyan"
        Write-LogMessage "│ Display Name                                                 │ Type ID │ Type Name                           │" "INFO" "Cyan"
        Write-LogMessage "├──────────────────────────────────────────────────────────────┼─────────┼─────────────────────────────────────┤" "INFO" "Cyan"
        
        foreach ($row in $tableData) {
            $displayNameFormatted = $row."Display Name".PadRight(60)
            $typeIdFormatted = $row."Type ID".ToString().PadRight(7)
            $typeNameFormatted = $row."Type Name".PadRight(35)
            
            Write-LogMessage "│ $displayNameFormatted │ $typeIdFormatted │ $typeNameFormatted │" "INFO" "White"
        }
        
        Write-LogMessage "└──────────────────────────────────────────────────────────────┴─────────┴─────────────────────────────────────┘" "INFO" "Cyan"
        
        # Display component type summary
        Write-LogMessage "`n📊 Component Type Summary:" "INFO" "Cyan"
        Write-LogMessage "─────────────────────────" "INFO" "Cyan"
        $ComponentsData.value | Group-Object msdyn_componenttype | Sort-Object Name | ForEach-Object {
            $typeName = ($_.Group[0].msdyn_componenttypename -replace "Customization\.Type_", "")
            Write-LogMessage "  📦 Type $($_.Name): $($_.Count) components ($typeName)" "INFO" "White"
        }
    }
    else {
        Write-LogMessage "No components found." "INFO" "Yellow"
    }
}

function Test-TargetSolutionsExist {
    <#
    .SYNOPSIS
    Checks if target solutions exist in the environment
    #>
    
    Write-LogMessage "`n🔍 Checking if target solutions exist..." "INFO" "Cyan"
    
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
                    Write-LogMessage "✅ Found: $targetSolution" "INFO" "Green"
                } else {
                    $missingSolutions += $targetSolution
                    Write-LogMessage "❌ Missing: $targetSolution" "WARN" "Red"
                }
            }
        } else {
            Write-LogMessage "⚠️ Could not retrieve solution list. Proceeding anyway..." "WARN" "Yellow"
            return $true
        }
    }
    catch {
        Write-LogMessage "⚠️ Error checking solutions: $($_.Exception.Message). Proceeding anyway..." "WARN" "Yellow"
        return $true
    }
    
    if ($missingSolutions.Count -gt 0) {
        Write-LogMessage "`n⚠️ Missing Solutions:" "WARN" "Yellow"
        $missingSolutions | ForEach-Object { Write-LogMessage "   - $_" "WARN" "Gray" }
        Write-LogMessage "`n💡 You may need to create these solutions first or update the script with correct solution names." "WARN" "Yellow"
        
        # In GitHub Actions, we don't prompt - we proceed based on the workflow input
        if ($env:GITHUB_ACTIONS -eq "true") {
            Write-LogMessage "Running in GitHub Actions - continuing with migration despite missing solutions..." "WARN" "Yellow"
            return $true
        }
    }
    
    Write-LogMessage "`n✅ All target solutions found!" "INFO" "Green"
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
        Write-LogMessage "🔄 Moving component '$DisplayName' to solution '$TargetSolution'..." "INFO" "Cyan"
        
        # Validate ObjectId is available
        if (-not $ObjectId -or $ObjectId -eq "(No object ID)" -or [string]::IsNullOrWhiteSpace($ObjectId)) {
            Write-LogMessage "❌ No ObjectId available for component '$DisplayName'" "ERROR" "Red"
            return $false
        }
        
        Write-LogMessage "Using ObjectId as identifier: $ObjectId" "INFO" "Gray"
        
        # Build PAC CLI command - use special handling for Connection Reference
        $pacCommand = if ($ComponentType -eq 10112) {
            "pac solution add-solution-component --solutionUniqueName `"$TargetSolution`" --component `"$ObjectId`" --componentType `"ConnectionReference`""
        } else {
            "pac solution add-solution-component --solutionUniqueName `"$TargetSolution`" --component `"$ObjectId`" --componentType $ComponentType"
        }
        
        Write-LogMessage "Executing: $pacCommand" "INFO" "Gray"
        
        # Execute the PAC CLI command
        $result = Invoke-Expression $pacCommand 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "✅ Successfully moved '$DisplayName' to '$TargetSolution' solution" "INFO" "Green"
            return $true
        } else {
            Write-LogMessage "❌ Failed to move '$DisplayName' to '$TargetSolution' solution" "ERROR" "Red"
            Write-LogMessage "Error output: $result" "ERROR" "Red"
            return $false
        }
    }
    catch {
        Write-LogMessage "❌ Exception while moving component '$DisplayName': $($_.Exception.Message)" "ERROR" "Red"
        return $false
    }
}

function Process-ComponentMigration {
    <#
    .SYNOPSIS
    Processes all components and moves them to appropriate solutions
    #>
    param($ComponentsData)
    
    Write-LogMessage "`n🚀 Starting Component Migration Process..." "INFO" "Magenta"
    Write-LogMessage "==========================================" "INFO" "Magenta"
    
    if (-not $ComponentsData.value -or $ComponentsData.value.Count -eq 0) {
        Write-LogMessage "No components to migrate." "WARN" "Yellow"
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
        
        Write-LogMessage "`n📦 Processing: $displayName (Type: $componentType)" "INFO" "White"
        
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
            Write-LogMessage "⚠️ No target solution mapping found for component type $componentType. Skipping..." "WARN" "Yellow"
            $migrationResults.Skipped++
        }
    }
    
    # Display migration summary
    Write-LogMessage "`n📊 Migration Summary:" "INFO" "Magenta"
    Write-LogMessage "====================" "INFO" "Magenta"
    Write-LogMessage "Total Components: $($migrationResults.Total)" "INFO" "White"
    Write-LogMessage "Successful: $($migrationResults.Successful)" "INFO" "Green"
    Write-LogMessage "Failed: $($migrationResults.Failed)" "INFO" "Red"
    Write-LogMessage "Skipped: $($migrationResults.Skipped)" "INFO" "Yellow"
    
    Write-LogMessage "`n📈 By Target Solution:" "INFO" "Cyan"
    foreach ($target in $migrationResults.ByTarget.Keys) {
        $stats = $migrationResults.ByTarget[$target]
        Write-LogMessage "  $target`: Success=$($stats.Success), Failed=$($stats.Failed)" "INFO" "Gray"
    }
    
    # Save migration results to JSON
    $migrationResults | ConvertTo-Json -Depth 3 | Out-File -FilePath "migration-summary.json" -Encoding UTF8
    
    # Return affected solutions for export prompt
    return $migrationResults
}

# Main script execution
try {
    Write-LogMessage "🚀 Starting Dynamics 365 Solution Component Migration for GitHub Actions..." "INFO" "Magenta"
    Write-LogMessage "" "INFO" "White"
    
    # Log the parameters received
    Write-LogMessage "📋 Script Parameters:" "INFO" "Cyan"
    Write-LogMessage "  Feature Solution Name: $FeatureSolutionName" "INFO" "White"
    Write-LogMessage "  Proceed with Migration: $ProceedWithMigration" "INFO" "White"
    Write-LogMessage "  Export Affected Solutions: $ExportAffectedSolutions" "INFO" "White"
    Write-LogMessage "  Delete Feature Solution: $DeleteFeatureSolution" "INFO" "White"
    Write-LogMessage "  Dataverse URL: $DataverseUrl" "INFO" "White"
    Write-LogMessage "" "INFO" "White"
    
    # Check if PAC CLI is available
    try {
        $pacVersion = pac help | Select-Object -First 1
        Write-LogMessage "✅ PAC CLI detected" "INFO" "Green"
    }
    catch {
        Write-LogMessage "❌ PAC CLI not found. Please install Microsoft Power Platform CLI first." "ERROR" "Red"
        Write-LogMessage "💡 Download from: https://aka.ms/PowerPlatformCLI" "INFO" "Yellow"
        exit 1
    }
    
    # Display component migration mapping
    Write-LogMessage "`n🗺️  Component Migration Mapping:" "INFO" "Magenta"
    Write-LogMessage "══════════════════════════════════════════════════════════════════════════════════════════════" "INFO" "Magenta"
    Write-LogMessage "This script will automatically migrate components from your feature solution to target solutions" "INFO" "Cyan"
    Write-LogMessage "based on their component types as follows:" "INFO" "Cyan"
    Write-LogMessage "" "INFO" "White"
    
    # Create a table showing the mapping
    Write-LogMessage "┌─────────────┬─────────────────────────────────────────┬─────────────────────────────────┐" "INFO" "DarkCyan"
    Write-LogMessage "│ Component   │ Component Type                          │ Target Solution                 │" "INFO" "DarkCyan"
    Write-LogMessage "│ Type ID     │                                         │                                 │" "INFO" "DarkCyan"
    Write-LogMessage "├─────────────┼─────────────────────────────────────────┼─────────────────────────────────┤" "INFO" "DarkCyan"
    
    # Connection Reference
    Write-LogMessage "│ 10112       │ Connection Reference                    │ connectionreference             │" "INFO" "White"
    Write-LogMessage "│ 29          │ Process/Flow                            │ flows                           │" "INFO" "White"
    Write-LogMessage "│ 61          │ Web Resource                            │ webresources                    │" "INFO" "White"
    Write-LogMessage "│ 91          │ Plugin Assembly                         │ plugins                         │" "INFO" "White"
    Write-LogMessage "│ 92          │ SDK Message Processing Step             │ plugins                         │" "INFO" "White"
    Write-LogMessage "│ Others      │ All Other Component Types               │ main                            │" "INFO" "White"
    
    Write-LogMessage "└─────────────┴─────────────────────────────────────────┴─────────────────────────────────┘" "INFO" "DarkCyan"
    
    # Validate feature solution name
    if ([string]::IsNullOrWhiteSpace($FeatureSolutionName)) {
        throw "Feature solution name is required. Please provide a valid solution name."
    }
    
    Write-LogMessage "Using feature solution: '$FeatureSolutionName'" "INFO" "Green"
    
    # Get access token for API calls
    $accessToken = Get-AccessTokenForDataverse
    
    # Get the solution ID from Dataverse
    $solutionId = Get-SolutionId -SolutionName $FeatureSolutionName -AccessToken $accessToken -BaseEndpoint $D365BaseEndpoint
    
    # Build the endpoint for solution components
    $componentsEndpoint = "$D365BaseEndpoint/msdyn_solutioncomponentsummaries?`$filter=(msdyn_solutionid eq $solutionId)&`$select=msdyn_displayname,msdyn_schemaname,msdyn_componenttype,msdyn_componenttypename,msdyn_objectid&`$orderby=msdyn_componenttype"
    
    # Make the API call to get solution components
    $componentsData = Invoke-D365WebApi -Endpoint $componentsEndpoint -AccessToken $accessToken
    
    # Format and display results
    Format-ComponentsOutput -ComponentsData $componentsData
    
    # Process migration based on workflow input
    if ($ProceedWithMigration) {
        Write-LogMessage "`n✅ Proceeding with component migration as requested..." "INFO" "Green"
        
        # Check if target solutions exist
        $shouldContinue = Test-TargetSolutionsExist
        
        if ($shouldContinue) {
            # Process component migration
            $migrationResults = Process-ComponentMigration -ComponentsData $componentsData
            
            # Show affected/updated solutions summary
            Write-LogMessage "`n🎯 Affected Target Solutions Summary:" "INFO" "Magenta"
            Write-LogMessage "====================================" "INFO" "Magenta"
            
            $affectedSolutions = @()
            if ($migrationResults.ByTarget -and $migrationResults.ByTarget.Keys.Count -gt 0) {
                Write-LogMessage "The following target solutions have been updated with new components:" "INFO" "Cyan"
                Write-LogMessage "" "INFO" "White"
                
                foreach ($solutionName in ($migrationResults.ByTarget.Keys | Sort-Object)) {
                    $stats = $migrationResults.ByTarget[$solutionName]
                    if ($stats.Success -gt 0) {
                        $affectedSolutions += $solutionName
                        Write-LogMessage "  ✅ $solutionName → $($stats.Success) components added" "INFO" "Green"
                    }
                }
                
                if ($affectedSolutions.Count -eq 0) {
                    Write-LogMessage "  ⚠️  No target solutions were successfully updated." "WARN" "Yellow"
                }
            } else {
                Write-LogMessage "  ⚠️  No target solutions were affected." "WARN" "Yellow"
            }
            
            # Export affected solutions if requested
            if ($ExportAffectedSolutions -and $affectedSolutions.Count -gt 0) {
                Write-LogMessage "`n📦 Solution Export:" "INFO" "Magenta"
                Write-LogMessage "==================" "INFO" "Magenta"
                Write-LogMessage "Exporting affected target solutions to capture the new changes..." "INFO" "Cyan"
                Write-LogMessage "" "INFO" "White"
                
                foreach ($solutionName in $affectedSolutions) {
                    try {
                        Write-LogMessage "`n📦 Exporting solution: $solutionName" "INFO" "Magenta"
                        Write-LogMessage "═══════════════════════════════════════" "INFO" "Magenta"
                        
                        # Check if export-solution.ps1 exists
                        $exportScriptPath = "./export-solution.ps1"
                        if (-not (Test-Path $exportScriptPath)) {
                            Write-LogMessage "❌ Export script not found at: $exportScriptPath" "ERROR" "Red"
                            Write-LogMessage "💡 Please ensure export-solution.ps1 is in the current directory." "WARN" "Yellow"
                            continue
                        }
                        
                        # Execute the export script for this solution
                        $exportCommand = "pwsh `"$exportScriptPath`" -SolutionName `"$solutionName`" -VersionType `"patch`""
                        Write-LogMessage "Executing: $exportCommand" "INFO" "Gray"
                        
                        $exportResult = Invoke-Expression $exportCommand 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-LogMessage "✅ Successfully exported solution: $solutionName" "INFO" "Green"
                        } else {
                            Write-LogMessage "❌ Failed to export solution: $solutionName" "ERROR" "Red"
                            Write-LogMessage "Error output: $exportResult" "ERROR" "Red"
                        }
                    }
                    catch {
                        Write-LogMessage "❌ Exception while exporting solution '$solutionName': $($_.Exception.Message)" "ERROR" "Red"
                    }
                }
                
                Write-LogMessage "`n🎉 Solution export process completed!" "INFO" "Green"
            } else {
                Write-LogMessage "`n📝 Solution export skipped." "INFO" "Cyan"
            }
            
            # Delete feature solution if requested
            if ($DeleteFeatureSolution) {
                Write-LogMessage "`n🗑️  Feature Solution Cleanup:" "INFO" "Magenta"
                Write-LogMessage "=============================" "INFO" "Magenta"
                Write-LogMessage "Deleting the original feature solution '$FeatureSolutionName'..." "INFO" "Cyan"
                
                try {
                    Write-LogMessage "`n🔄 Deleting feature solution '$FeatureSolutionName'..." "INFO" "Cyan"
                    
                    # Execute PAC CLI command to delete the solution
                    $deleteCommand = "pac solution delete --solution-name `"$FeatureSolutionName`""
                    Write-LogMessage "Executing: $deleteCommand" "INFO" "Gray"
                    
                    $deleteResult = Invoke-Expression $deleteCommand 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-LogMessage "✅ Successfully deleted feature solution '$FeatureSolutionName'" "INFO" "Green"
                        Write-LogMessage "🎯 All components have been migrated and the original solution has been cleaned up!" "INFO" "Green"
                    } else {
                        Write-LogMessage "❌ Failed to delete feature solution '$FeatureSolutionName'" "ERROR" "Red"
                        Write-LogMessage "Error output: $deleteResult" "ERROR" "Red"
                        Write-LogMessage "💡 You may need to delete it manually from the Power Platform admin center." "WARN" "Yellow"
                    }
                }
                catch {
                    Write-LogMessage "❌ Exception while deleting solution: $($_.Exception.Message)" "ERROR" "Red"
                    Write-LogMessage "💡 You may need to delete the solution manually from the Power Platform admin center." "WARN" "Yellow"
                }
            } else {
                Write-LogMessage "`n📝 Feature solution '$FeatureSolutionName' has been preserved." "INFO" "Cyan"
            }
        } else {
            Write-LogMessage "Migration cancelled due to missing solutions." "WARN" "Yellow"
            exit 1
        }
    } else {
        Write-LogMessage "Migration not executed - ProceedWithMigration was set to false." "INFO" "Yellow"
    }
    
    Write-LogMessage "`n🎉 Script completed successfully!" "INFO" "Green"
}
catch {
    Write-LogMessage "`n❌ Error: $($_.Exception.Message)" "ERROR" "Red"
    Write-LogMessage "`n💡 Troubleshooting tips:" "INFO" "Yellow"
    Write-LogMessage "1. Install MSAL.PS module: Install-Module MSAL.PS" "INFO" "Gray"
    Write-LogMessage "2. Install PAC CLI: https://aka.ms/PowerPlatformCLI" "INFO" "Gray"
    Write-LogMessage "3. Ensure you have access to the Dynamics 365 environment" "INFO" "Gray"
    Write-LogMessage "4. Set up service principal credentials in GitHub secrets" "INFO" "Gray"
    Write-LogMessage "5. Verify target solutions exist in your environment" "INFO" "Gray"
    exit 1
}
