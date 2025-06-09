
# Blue Owl GPS Reporting - Azure Infrastructure

This directory contains the Infrastructure as Code (IaC) for the Blue Owl GPS Reporting system, implemented using Azure Bicep for the **Development (DEV)** environment.

## Architecture

The deployed infrastructure includes:

- **Virtual Network (VNet)** with private subnets  
- **Application Gateway** as the public entry point  
- **App Service Plan** (Basic tier for DEV)  
- **React Frontend** (Web App Service)  
- **FastAPI Backend** (App Service)  
- **Azure SQL Database** (Standard S1)  
- **Blob Storage** for file storage  
- **Application Insights** for monitoring  
- **Communication Services** for email delivery  
- **Network Security Groups** for security  

## Quick Deployment

### Prerequisites

1. **Azure CLI** installed and configured  
2. **Azure Account** with Contributor role  
3. **Azure Subscription ID**

### Deployment Steps

1. **Clone the repository and navigate to the directory**:
   ```bash
   cd iac/deployments/conversation-service
   ```

2. **Make the deployment scripts executable**:
   ```bash
   chmod +x deploy.sh
   chmod +x clean-up.sh
   ```

3. **Set up parameters** (edit `parameters.dev.json`):
   ```json
   {
     "parameters": {
       "yourIpAddress": {
         "value": "YOUR_PUBLIC_IP_HERE"
       }
     }
   }
   ```

4. **Run the deployment**:
   ```bash
   # Option 1: Interactive
   ./deploy.sh -g bo-gpsc-reports-dev -s YOUR_SUBSCRIPTION_ID

   # Option 2: Automated
   ./deploy.sh -g bo-gpsc-reports-dev -s YOUR_SUBSCRIPTION_ID -y
   ```

## Available Commands

### Deployment
```bash
# Basic deployment
./deploy.sh -g <resource-group> -s <subscription-id>

# With custom parameters
./deploy.sh -g bo-gpsc-reports-dev -s 12345678-1234-1234-1234-123456789abc -e dev -l "East US 2"

# Without confirmation
./deploy.sh -g bo-gpsc-reports-dev -s 12345678-1234-1234-1234-123456789abc -y
```

### Cleanup
```bash
# Delete specific resources
./clean-up.sh -g <resource-group> -s <subscription-id>

# Delete entire resource group
./clean-up.sh -g <resource-group> -s <subscription-id> -r -y
```

### Validation
```bash
# Validate template without deploying
az deployment group validate \
  --resource-group bo-gpsc-reports-dev \
  --template-file main.bicep \
  --parameters @parameters.dev.json

# List deployed resources
az resource list --resource-group bo-gpsc-reports-dev --output table

# View deployment outputs
az deployment group show \
  --resource-group bo-gpsc-reports-dev \
  --name <deployment-name> \
  --query "properties.outputs"
```

## 🔧 Post-Deployment Configuration

### 1. Configure Application Settings

After deployment, update the app settings:

```bash
# For React Frontend
az webapp config appsettings set \
  --resource-group bo-gpsc-reports-dev \
  --name bo-gpsc-reports-dev-frontend \
  --settings REACT_APP_API_URL="https://bo-gpsc-reports-dev-backend.azurewebsites.net"

# For FastAPI Backend
az webapp config appsettings set \
  --resource-group bo-gpsc-reports-dev \
  --name bo-gpsc-reports-dev-backend \
  --settings DATABASE_URL="your-connection-string"
```

### 2. Deploy Applications

```bash
# Deploy React Frontend
cd /path/to/react-app
npm run build
az webapp deployment source config-zip \
  --resource-group bo-gpsc-reports-dev \
  --name bo-gpsc-reports-dev-frontend \
  --src build.zip

# Deploy FastAPI Backend
cd /path/to/fastapi-app
zip -r app.zip .
az webapp deployment source config-zip \
  --resource-group bo-gpsc-reports-dev \
  --name bo-gpsc-reports-dev-backend \
  --src app.zip
```

## File Structure

```
conversation-service/
├── main.bicep                 # Main template
├── parameters.dev.json        # DEV parameters
├── parameters.uat.json        # UAT parameters
├── parameters.prod.json       # PROD parameters
├── deploy.sh                  # Deployment script
├── clean-up.sh                # Cleanup script
└── README.md                  # This documentation
```

## Deployed Endpoints

After a successful deployment, you will have access to:

- **Frontend**: `https://bo-gpsc-reports-dev-frontend.azurewebsites.net`  
- **Backend API**: `https://bo-gpsc-reports-dev-backend.azurewebsites.net`  
- **Application Gateway**: `https://bo-gpsc-reports-dev-gateway.eastus2.cloudapp.azure.com`

## Security

- **Network Security Groups** restrict traffic  
- **HTTPS Only** enabled for all applications  
- **TLS 1.2** minimum enforced  
- **Private VNet Integration** for internal communication  
- **SQL Firewall** configured for specific IPs  

## Monitoring

- **Application Insights** for telemetry and logs  
- **Log Analytics** for centralized logging  
- **Health Probes** on the Application Gateway  
- **Configurable alerts** for performance issues  

##  Resource Cleanup

### Delete specific resources:
```bash
./clean-up.sh -g bo-gpsc-reports-dev -s YOUR_SUBSCRIPTION_ID
```

### Delete entire resource group:
```bash
./clean-up.sh -g bo-gpsc-reports-dev -s YOUR_SUBSCRIPTION_ID -r -y
```

##  Troubleshooting

### Common Errors

1. **Authentication error**:
   ```bash
   az login
   az account set --subscription YOUR_SUBSCRIPTION_ID
   ```

2. **Permission error**:
   - Ensure you have the "Contributor" role on the subscription

3. **Template validation error**:
   ```bash
   az deployment group validate \
     --resource-group bo-gpsc-reports-dev \
     --template-file main.bicep \
     --parameters @parameters.dev.json
   ```

4. **SQL IP restriction error**:
   - Update `yourIpAddress` in `parameters.dev.json`

### Useful Logs

```bash
# View deployment logs
az deployment group show \
  --resource-group bo-gpsc-reports-dev \
  --name deployment-name

# View application logs
az webapp log tail \
  --resource-group bo-gpsc-reports-dev \
  --name bo-gpsc-reports-dev-backend
```

## Support

For issues or questions:

1. Check Azure CLI logs  
2. Review Azure Bicep documentation  
3. Inspect deployment outputs for URLs and settings

## Next Steps

1. **Set up CI/CD** with Azure DevOps or GitHub Actions  
2. **Implement custom HTTPS** with SSL certificates  
3. **Configure monitoring alerts**  
4. **Implement database backups**  
5. **Enable autoscaling** for higher environments
