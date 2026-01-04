#!/bin/bash

echo "======================================"
echo "  Deploying Laporan System"
echo "======================================"
echo ""

# Check if using Minikube and configure Docker environment
USING_MINIKUBE=false
if kubectl config current-context | grep -q "minikube"; then
    USING_MINIKUBE=true
    echo "Detected Minikube environment"
    
    # Enable ingress addon for Minikube
    echo "Enabling Ingress addon for Minikube..."
    minikube addons enable ingress
    echo "Ingress addon enabled"
    echo ""
    
    echo "Setting Docker environment to use Minikube's Docker daemon..."
    eval $(minikube docker-env)
    echo "Docker environment configured for Minikube"
    echo ""
else
    # For non-Minikube environments (like Docker Desktop)
    echo "Detected non-Minikube environment"
    echo "Checking if NGINX Ingress Controller is installed..."
    
    if ! kubectl get namespace ingress-nginx &> /dev/null; then
        echo "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
        
        echo "Waiting for Ingress Controller to be ready..."
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=120s
        echo "Ingress Controller ready"
    else
        echo "NGINX Ingress Controller already installed"
    fi
    echo ""
fi

# Step 0: Cleanup old deployments
echo "Step 0: Cleaning up old deployments..."
chmod +x cleanup.sh
./cleanup.sh

# Step 1: Build Docker Images
echo "Step 1: Building Docker Images..."

# Build Service Auth Warga
echo "Building Service Auth Warga..."
cd service-auth-warga
docker build -t service-auth-warga:latest . || exit 1
cd ..

# Build Service Auth Admin
echo "Building Service Auth Admin..."
cd service-auth-admin
docker build -t service-auth-admin:latest . || exit 1
cd ..

# Build Service Pembuat Laporan
echo "Building Service Pembuat Laporan..."
cd service-pembuat-laporan
docker build -t service-pembuat-laporan:latest . || exit 1
cd ..

# Build Service Penerima Laporan
echo "Building Service Penerima Laporan..."
cd service-penerima-laporan
docker build -t service-penerima-laporan:latest . || exit 1
cd ..

# Build Client User
echo "Building Client User..."
cd client-user
docker build -t client-user:latest . || exit 1
cd ..

# Build Client Admin
echo "Building Client Admin..."
cd client-admin
docker build -t client-admin:latest . || exit 1
cd ..

echo ""
echo "Step 2: Deploying to Kubernetes..."
kubectl apply -f k8s-all-in-one.yaml

echo ""
echo "Step 3: Waiting for deployments to be ready..."

# Wait for database deployments
echo "Waiting for database deployments..."
kubectl wait --for=condition=available --timeout=120s deployment/postgres-warga
kubectl wait --for=condition=available --timeout=120s deployment/postgres-admin
kubectl wait --for=condition=available --timeout=120s deployment/postgres-laporan

# Wait for service deployments
echo "Waiting for service deployments..."
kubectl wait --for=condition=available --timeout=120s deployment/service-auth-warga
kubectl wait --for=condition=available --timeout=120s deployment/service-auth-admin
kubectl wait --for=condition=available --timeout=120s deployment/service-pembuat-laporan
kubectl wait --for=condition=available --timeout=120s deployment/service-penerima-laporan

# Wait for client deployments
echo "Waiting for client deployments..."
kubectl wait --for=condition=available --timeout=120s deployment/client-user
kubectl wait --for=condition=available --timeout=120s deployment/client-admin

echo ""
echo "Step 4: Checking deployment status..."
kubectl get deployments
echo ""
kubectl get pods
echo ""
kubectl get services

echo ""
echo "======================================"
echo "  Deployment Complete!"
echo "======================================"
echo ""
echo "Applications are accessible via Ingress at:"
echo "- User Portal: http://localhost/user"
echo "- Admin Portal: http://localhost/admin"
echo ""
echo "API Endpoints (for testing):"
echo "- User Auth API: http://localhost/api/warga/auth/*"
echo "- User Reports API: http://localhost/api/warga/laporan"
echo "- Admin Auth API: http://localhost/api/admin/auth/*"
echo "- Admin Reports API: http://localhost/api/admin/laporan"
echo ""
echo "To check logs:"
echo "  kubectl logs -l app=service-auth-warga"
echo "  kubectl logs -l app=service-auth-admin"
echo "  kubectl logs -l app=service-pembuat-laporan"
echo "  kubectl logs -l app=service-penerima-laporan"
echo ""
echo "To check Ingress status:"
echo "  kubectl get ingress"
echo ""
