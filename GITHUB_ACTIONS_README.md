# Core Power Platform Solution - GitHub Actions

This repository contains automated CI/CD workflows for the **main** Power Platform solution using GitHub Actions.

## 🎯 What This Repository Does

✅ **Export Solutions**: Automated export from DEV environment with custom branch naming  
✅ **Quality Gates**: Solution checker validation at every deployment stage  
✅ **Deployment Pipeline**: Automated TEST → UAT → PRODUCTION deployment with approval gates  
✅ **Version Management**: Automated version increments using semantic versioning  
✅ **Artifact Management**: Solution artifacts with retention

## 🚀 Quick Start

### 1. Configure Secrets & Variables

**Required Repository Secrets** (Settings → Secrets and variables → Actions):
```
PowerPlatformSPN = your-service-principal-secret
```

**Repository Variables** (Settings → Secrets and variables → Actions → Variables):
```
DEV_ENVIRONMENT_URL = https://mzhdev.crm4.dynamics.com
TEST_ENVIRONMENT_URL = https://mzhtest.crm4.dynamics.com  
UAT_ENVIRONMENT_URL = https://mzhuat.crm4.dynamics.com
PRODUCTION_ENVIRONMENT_URL = https://mzhprod.crm11.dynamics.com
CLIENT_ID = c07145b8-e4f8-48ad-8a7c-9fe5d3827e52
TENANT_ID = d7d483b3-60d3-4211-a15e-9c2a090d2136
```

**GitHub Environments** (Settings → Environments):
```
TEST = Testing environment with approval gates
UAT = User Acceptance Testing environment  
PRODUCTION = Production environment with approval gates
```

### 2. Solution Structure

This repository manages the **main** solution containing:
- **HousingUnit** (`cicd_housingunit`) - Housing unit management
- **Lease** (`cicd_lease`) - Lease agreements and contracts  
- **Tenant** (`cicd_tenant`) - Tenant information and details

## 📋 Available Workflows

### 1. 🔄 Export Main Solution From Dev
**File**: `01-export-main-solution.yml`  
**Purpose**: Export main solution from DEV environment and create PR

**Features**:
- Automated export of main solution (unmanaged)
- Optional managed solution export
- Custom branch naming or auto-generated timestamps
- Automatic PR creation with detailed summary

**Usage**:
1. Actions → "Export Main Solution From Dev" → Run workflow
2. Choose solution options (managed/unmanaged)
3. Optionally provide custom branch name
4. Creates PR with solution changes

### 2. 🚢 Deploy Main Solution  
**File**: `02-deploy-main-solution.yml`  
**Purpose**: Deploy main solution through all environments

**Triggers**:
- **Push to `main`** when `mainsolution/**` changes (automatic)
- Manual workflow dispatch

**Deployment Flow**:
1. **Pack Solution**: Creates managed solution from source
2. **Deploy to TEST**: Automatic deployment to test environment
3. **Deploy to UAT**: Deployment with approval gate
4. **Deploy to PRODUCTION**: Final deployment with approval gate

### 3. 🏗️ Shared Deployment Pipeline
**File**: `shared-deployment-pipeline.yml`  
**Purpose**: Reusable deployment workflow with intelligent import logic

**Features**:
- Smart solution existence checking
- Intelligent import mode selection (update vs upgrade)
- Environment-specific deployment strategies
- Comprehensive error handling and logging

## 🔧 PowerShell Export Script

The repository includes `export-solution.ps1` for local development:

```powershell
# Basic usage (patch increment)
pwsh ./export-solution.ps1

# Minor version increment  
pwsh ./export-solution.ps1 -VersionType "minor"

# Major version increment
pwsh ./export-solution.ps1 -VersionType "major"
```

**Script Features**:
- Automatic version checking and incrementing
- Exports both managed and unmanaged solutions  
- Unpacks solutions for source control
- Colored output with progress indicators

## 🎛️ Environment Setup

### GitHub Environments Configuration

1. **TEST Environment**
   - **Variables**: `TEST_ENVIRONMENT_URL`
   - **Protection**: Optional approval gates

2. **UAT Environment**  
   - **Variables**: `UAT_ENVIRONMENT_URL`
   - **Protection**: Approval gates recommended
   
3. **PRODUCTION Environment**
   - **Variables**: `PRODUCTION_ENVIRONMENT_URL`
   - **Protection**: Approval gates required

### Service Principal Setup

1. **Azure AD App Registration**: Create app registration for GitHub Actions
2. **Configure Permissions**: Add Dynamics CRM user_impersonation permission  
3. **Create Secret**: Generate client secret and add to GitHub secrets
4. **Power Platform Access**: Add app user to all environments with System Administrator role

## 🔍 Development Workflow

### Export Process:
1. **Make Changes**: Develop in Power Platform DEV environment
2. **Export**: Run "Export Main Solution From Dev" workflow
3. **Review**: Review PR changes and validate solution components
4. **Merge**: Merge PR to trigger automatic deployment

### Deployment Process:
1. **Automatic Trigger**: Deployment starts when PR is merged to main
2. **Pack Solution**: Creates managed solution package
3. **Deploy to TEST**: Automatic deployment for testing
4. **Deploy to UAT**: Manual approval required
5. **Deploy to PRODUCTION**: Final manual approval required

## 🚨 Troubleshooting

### Common Issues:

#### 🔐 Authentication Failed
- Verify PowerPlatformSPN secret is correct
- Check service principal has access to all environments
- Validate CLIENT_ID and TENANT_ID variables

#### 🏗️ Solution Export Failed  
- Ensure solution "main" exists in DEV environment
- Check solution name spelling (case-sensitive)
- Verify no concurrent edits in Power Platform

#### ⏸️ Approval Gate Issues
- Ensure GitHub environments are configured
- Verify required reviewers are assigned
- Check reviewers have repository access

## 🎯 Best Practices

### Development:
- Test changes in DEV environment before export
- Use meaningful commit messages
- Review solution components before merging PRs

### Deployment:
- Schedule PRODUCTION deployments during maintenance windows
- Test in UAT before PRODUCTION approval
- Document significant changes in PR descriptions

### Security:
- Regularly rotate service principal secrets
- Use least privilege access principles
- Monitor workflow runs for suspicious activity

---

🎉 **Your Power Platform solution is now ready for automated CI/CD!**
