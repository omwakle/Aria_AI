#!/bin/bash

# Azure Advisor - Container App Deployment Script
set -e

# ── Configuration ──────────────────────────────────────────
RESOURCE_GROUP="Innovation_BFSI"
CONTAINER_APP_NAME="azure-advisor-app"
ACR_NAME="azureadvisorregistry"
CONTAINER_REGISTRY="${ACR_NAME}.azurecr.io"
IMAGE_NAME="azure-advisor"
TAG="${1:-latest}"
LOCATION="eastus2"
ENVIRONMENT_NAME="azure-advisor-env"

echo "🚀 Deploying Azure Advisor to Azure Container Apps"
echo "📌 Resource Group : ${RESOURCE_GROUP}"
echo "📌 ACR            : ${CONTAINER_REGISTRY}"
echo "📌 Image          : ${IMAGE_NAME}:${TAG}"
echo "📌 Location       : ${LOCATION}"

# ── Step 1: Azure Login Check ───────────────────────────────
echo ""
echo "🔑 Checking Azure login..."
az account show > /dev/null 2>&1 || az login

# ── Step 2: ACR Login ───────────────────────────────────────
echo ""
echo "🔐 Logging into Azure Container Registry..."
az acr login --name ${ACR_NAME}

# ── Step 3: Build Docker Image ──────────────────────────────
echo ""
echo "📦 Building Docker image..."
docker build -t ${CONTAINER_REGISTRY}/${IMAGE_NAME}:${TAG} .

# ── Step 4: Push Image to ACR ───────────────────────────────
echo ""
echo "⬆️  Pushing image to ACR..."
docker push ${CONTAINER_REGISTRY}/${IMAGE_NAME}:${TAG}

# ── Step 5: Create Container App Environment if Not Exists ──
echo ""
echo "🔍 Checking Container App Environment..."
ENV_EXISTS=$(az containerapp env list \
    --resource-group ${RESOURCE_GROUP} \
    --query "[?name=='${ENVIRONMENT_NAME}'].name" \
    --output tsv 2>/dev/null || echo "")

if [ -z "$ENV_EXISTS" ]; then
    echo "🆕 Creating Container App Environment in ${LOCATION}..."
    az containerapp env create \
        --name ${ENVIRONMENT_NAME} \
        --resource-group ${RESOURCE_GROUP} \
        --location ${LOCATION}
else
    echo "✅ Environment '${ENVIRONMENT_NAME}' already exists, skipping..."
fi

# ── Step 6: Create or Update Container App ──────────────────
echo ""
echo "🔍 Checking if Container App exists..."
APP_EXISTS=$(az containerapp show \
    --name ${CONTAINER_APP_NAME} \
    --resource-group ${RESOURCE_GROUP} \
    --query name -o tsv 2>/dev/null || echo "")

if [ -z "$APP_EXISTS" ]; then
    echo "🆕 Creating Container App for the first time..."
    az containerapp create \
        --name ${CONTAINER_APP_NAME} \
        --resource-group ${RESOURCE_GROUP} \
        --environment ${ENVIRONMENT_NAME} \
        --image ${CONTAINER_REGISTRY}/${IMAGE_NAME}:${TAG} \
        --registry-server ${CONTAINER_REGISTRY} \
        --target-port 8000 \
        --ingress external \
        --cpu 0.5 \
        --memory 1.0Gi \
        --min-replicas 0 \
        --max-replicas 3
else
    echo "♻️  Container App exists. Updating image..."
    az containerapp update \
        --name ${CONTAINER_APP_NAME} \
        --resource-group ${RESOURCE_GROUP} \
        --image ${CONTAINER_REGISTRY}/${IMAGE_NAME}:${TAG}
fi

# ── Step 7: Fetch Real App URL ───────────────────────────────
echo ""
echo "🌐 Fetching App URL..."
APP_URL=$(az containerapp show \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment complete!"
echo "🔗 App URL : https://${APP_URL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"