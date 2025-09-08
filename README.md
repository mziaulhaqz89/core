# Core Project - Power Platform Solutions

This repository contains the core Power Platform solutions for the project, including automated deployment workflows and solution management scripts.

## 🏗️ Solution Architecture

This project manages multiple Power Platform solutions organized in separate folders:

### 📁 Solution Folders Structure

```
├── mainsolution/          # Main application solution
│   ├── managed/          # Managed solution exports
│   └── unmanaged/        # Unmanaged solution exports (source control)
├── flows/                # Power Automate flows solution
│   ├── managed/          # Managed flow exports
│   └── unmanaged/        # Unmanaged flow exports (source control)
├── webresources/         # Web resources solution
│   ├── managed/          # Managed web resource exports
│   └── unmanaged/        # Unmanaged web resource exports (source control)
└── .github/workflows/    # GitHub Actions deployment pipelines
```

### 🔧 Solution Components

#### Main Solution (`mainsolution`)
- **HousingUnit** (`cicd_housingunit`) - Manages housing unit information
- **Lease** (`cicd_lease`) - Handles lease agreements and contracts  
- **Tenant** (`cicd_tenant`) - Stores tenant information and details
- **App Modules** - Core application modules and site maps
- **Relationships** - Entity relationships and business logic

#### Flows Solution (`flows`)
- **AddTenantwhenhousingunitadded** - Automated tenant creation workflow
- **CreateContactWhenAccountCreated** - Contact creation automation

#### WebResources Solution (`webresources`)
- **cicd_mzh_accountform** - Account form customizations
- **cicd_stw_account** - Account-related web resources

## 🚀 Developer Onboarding Guide

### Prerequisites
- **Git** - Version control system
- **Power Platform CLI** - Microsoft Power Platform command-line interface
- **PowerShell 5.1+** - For running automation scripts
- **Visual Studio Code** (recommended) - Code editor with Power Platform extensions

### 📋 Development Workflow

#### 1. Repository Setup
```bash
# Clone the repository
git clone https://github.com/mziaulhaqz89/core.git
cd core

# Pull the latest main branch
git checkout main
git pull origin main
```

#### 2. Create Development Branch
```bash
# Create a new feature branch
git checkout -b feature/your-feature-name
```

#### 3. Solution Export and Development

##### Using the PowerShell Automation Script

The repository includes an automated PowerShell script (`export-solution.ps1`) that handles solution versioning and export:

```powershell
# Run the script for any solution
.\export-solution.ps1 -SolutionName "mainsolution"
.\export-solution.ps1 -SolutionName "flows" 
.\export-solution.ps1 -SolutionName "webresources"

# Optional: Specify version increment type
.\export-solution.ps1 -SolutionName "mainsolution" -VersionType "minor"
```

##### What the PowerShell Script Does:

1. **🔍 Version Check**: Retrieves the current version of the specified solution from Power Platform
2. **⬆️ Version Increment**: Automatically increments the version (patch, minor, or major)
3. **🔄 Version Update**: Updates the solution version in Power Platform
4. **📦 Export Solutions**: Exports both managed and unmanaged versions
5. **📂 Unpack & Organize**: Unpacks solutions into organized folder structure
6. **🧹 Cleanup**: Removes temporary files

**Script Parameters:**
- `SolutionName` - Name of the solution to export (default: "main")
- `VersionType` - Version increment type: "patch", "minor", "major" (default: "patch")

#### 4. Making Changes

After exporting, you can:
- Modify solution components in the `unmanaged` and `managed` folders
- Update workflows, entities, or web resources
- Test changes in your development environment

#### 5. Commit and Deploy

```bash
# Stage your changes
git add .

# Commit with descriptive message
git commit -m "feat: add new housing unit validation workflow"

# Push to your branch
git push origin feature/your-feature-name

# Create pull request to main branch
```

## 🔄 Automated Deployment Pipeline

The repository includes GitHub Actions workflows for automated deployment:

- **`02-deploy-main-solution.yml`** - Deploys main solution changes
- **`03-deploy-flows-solution.yml`** - Deploys Power Automate flows
- **`04-deploy-webresources-solution.yml`** - Deploys web resources

### Deployment Triggers
- **Manual**: Use GitHub Actions UI to trigger deployments
- **Automatic**: Deployments trigger on push to `main` branch when solution files change

## 🛠️ Development Best Practices

### Version Management
- Use **patch** increment for bug fixes and minor changes
- Use **minor** increment for new features
- Use **major** increment for breaking changes

### Branch Strategy
- `main` - Production-ready code
- `feature/*` - Feature development branches
- `hotfix/*` - Critical bug fixes

### Solution Management
- Always work with **unmanaged** solutions for source control
- **Managed** solutions are generated for deployment
- Keep solution components organized by functional area

## 🆘 Troubleshooting

### Common Issues

#### PowerShell Script Errors
```powershell
# If you encounter encoding issues, run:
Get-Content .\export-solution.ps1 -Encoding UTF8 | Set-Content .\export-solution.ps1 -Encoding UTF8
```

#### Power Platform CLI Authentication
```bash
# Authenticate with Power Platform
pac auth create --url https://your-environment.crm.dynamics.com
```

#### Solution Not Found
- Verify solution name exists in your Power Platform environment
- Check authentication and environment connection
- Ensure proper permissions for solution export

## 📞 Support

For questions or issues:
1. Check existing GitHub Issues
2. Create new issue with detailed description
3. Contact the development team

## 🔗 Useful Links

- [Power Platform CLI Documentation](https://docs.microsoft.com/en-us/power-platform/developer/cli/introduction)
- [Solution Concepts](https://docs.microsoft.com/en-us/power-platform/alm/solution-concepts-alm)
- [GitHub Actions for Power Platform](https://github.com/microsoft/powerplatform-actions)
