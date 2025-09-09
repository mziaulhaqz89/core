# GitHub Action: Migrate Solution Components

This GitHub Action allows you to run the solution component migration process manually through GitHub's web interface, eliminating the need for interactive prompts while maintaining full control over the migration process.

## 🚀 Features

- **Manual Workflow Dispatch**: Run the migration on-demand through GitHub UI
- **Parameterized Inputs**: All interactive prompts converted to workflow inputs
- **Service Principal Authentication**: Secure, non-interactive authentication
- **Comprehensive Logging**: Detailed logs and artifacts for troubleshooting
- **Component Migration**: Automatically moves components to appropriate target solutions
- **Solution Export**: Optionally export affected solutions after migration
- **Feature Solution Cleanup**: Optionally delete the source feature solution

## 📋 Prerequisites

### 1. Repository Secrets and Variables Setup

You need to configure secrets and variables in your GitHub repository:

1. Go to your repository → Settings → Secrets and variables → Actions

2. Add the following **Repository Variables** (Variables tab):

| Variable Name | Description | Example |
|---------------|-------------|---------|
| `TENANT_ID` | Your Azure AD Tenant ID | `12345678-1234-1234-1234-123456789012` |
| `CLIENT_ID` | Service Principal Application ID | `87654321-4321-4321-4321-210987654321` |

3. Add the following **Repository Secret** (Secrets tab):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `CLIENT_SECRET` | Service Principal Secret | `your-service-principal-secret` |

### 2. Service Principal Setup

Create a service principal with appropriate permissions:

```powershell
# Connect to Azure
Connect-AzAccount

# Create service principal
$sp = New-AzADServicePrincipal -DisplayName "GitHub-Actions-PowerPlatform" -Role "Contributor"

# Output the required values
Write-Host "TENANT_ID: $(Get-AzContext).Tenant.Id"
Write-Host "CLIENT_ID: $($sp.ApplicationId)"
Write-Host "CLIENT_SECRET: $($sp.Secret | ConvertFrom-SecureString -AsPlainText)"
```

### 3. Power Platform Permissions

Ensure your service principal has the following permissions in your Power Platform environment:

- **System Administrator** role in Dataverse
- **Environment Maker** role in Power Platform
- Access to modify solutions and components

## 🎯 Target Solutions Required

The migration process expects these target solutions to exist in your environment:

- `main` - For general components (entities, forms, views, etc.)
- `connectionreference` - For connection references
- `flows` - For Power Automate flows
- `webresources` - For web resources
- `plugins` - For plugin assemblies and steps

## 🔧 How to Use

### 1. Navigate to Actions Tab

1. Go to your repository on GitHub
2. Click on the **Actions** tab
3. Find "Migrate Solution Components" workflow
4. Click **Run workflow**

### 2. Fill in Parameters

The workflow will prompt you for the following inputs:

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| **Feature Solution Name** | Unique name of the source solution | ✅ | - |
| **Proceed with Migration** | Actually perform the migration | ✅ | `false` |
| **Export Affected Solutions** | Export target solutions after migration | ✅ | `false` |
| **Delete Feature Solution** | Delete source solution after migration | ✅ | `false` |
| **Dataverse Environment URL** | Your Dataverse environment URL | ✅ | `https://mzhdev.crm4.dynamics.com` |

### 3. Example Usage

**Scenario 1: Preview Migration (Safe)**
- Feature Solution Name: `MyFeatureSolution`
- Proceed with Migration: `false`
- Export Affected Solutions: `false`
- Delete Feature Solution: `false`

**Scenario 2: Full Migration with Export**
- Feature Solution Name: `MyFeatureSolution`
- Proceed with Migration: `true`
- Export Affected Solutions: `true`
- Delete Feature Solution: `false`

**Scenario 3: Complete Migration with Cleanup**
- Feature Solution Name: `MyFeatureSolution`
- Proceed with Migration: `true`
- Export Affected Solutions: `true`
- Delete Feature Solution: `true`

## 📊 Component Type Mapping

The action automatically maps components to target solutions:

| Component Type ID | Component Type | Target Solution |
|-------------------|----------------|-----------------|
| 10112 | Connection Reference | `connectionreference` |
| 29 | Process/Flow | `flows` |
| 61 | Web Resource | `webresources` |
| 91 | Plugin Assembly | `plugins` |
| 92 | SDK Message Processing Step | `plugins` |
| Others | All Other Types | `main` |

## 📁 Artifacts and Logs

After each run, the action provides downloadable artifacts:

- **Migration Logs**: Detailed execution logs with timestamps
- **Component Summary**: JSON file with all discovered components
- **Migration Results**: JSON file with migration statistics

## 🔍 Monitoring the Run

1. **Real-time Logs**: Watch the action execution in real-time
2. **Step-by-Step Progress**: Each step shows detailed progress
3. **Error Handling**: Clear error messages and troubleshooting tips
4. **Summary Reports**: Component counts and migration statistics

## 🛠️ Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify CLIENT_SECRET is correctly set in GitHub secrets
   - Verify TENANT_ID and CLIENT_ID are correctly set in GitHub variables
   - Ensure service principal has proper Power Platform permissions
   - Check tenant ID is correct

2. **Missing Target Solutions**
   - Create required target solutions in your environment
   - Verify solution names match exactly (case-sensitive)

3. **PAC CLI Issues**
   - The action automatically installs PAC CLI
   - Ensure your environment is accessible from GitHub runners

4. **Component Migration Failures**
   - Check component dependencies
   - Verify component isn't already in target solution
   - Review detailed logs in the action output

### Debug Mode

To enable additional debugging:

1. Go to repository Settings → Secrets and variables → Actions
2. Add a **Repository Variable** named `ACTIONS_RUNNER_DEBUG` with value `true`
3. Re-run the workflow for detailed debug logs

## 🔄 Local Testing

You can test the GitHub-specific script locally:

```powershell
# Test the GitHub Actions version locally
./migrate-solution-components-github.ps1 `
    -FeatureSolutionName "MyFeatureSolution" `
    -ProceedWithMigration $true `
    -ExportAffectedSolutions $false `
    -DeleteFeatureSolution $false `
    -DataverseUrl "https://yourorg.crm4.dynamics.com"
```

## 📝 Best Practices

1. **Always Preview First**: Run with `ProceedWithMigration: false` to see what will be migrated
2. **Test in Development**: Use a development environment before production
3. **Backup Solutions**: Export solutions before major migrations
4. **Incremental Migration**: Process smaller batches of components when possible
5. **Monitor Dependencies**: Check for component dependencies before migration

## 🔗 Related Files

- `migrate-solution-components.ps1` - Original interactive script
- `migrate-solution-components-github.ps1` - GitHub Actions version
- `export-solution.ps1` - Solution export script (called automatically)
- `.github/workflows/migrate-solution-components.yml` - GitHub Action workflow

## 📞 Support

If you encounter issues:

1. Check the action logs and artifacts
2. Review the troubleshooting section
3. Verify all prerequisites are met
4. Test the process in a development environment first
