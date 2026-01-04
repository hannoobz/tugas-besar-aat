#!/bin/bash

echo "======================================"
echo "  Deploying Laporan System (k0s)"
echo "======================================"
echo ""

echo "Detected k0s environment"
echo "Note: k0s uses containerd, not Docker daemon"
echo ""

# Check if NGINX Ingress Controller is installed
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
echo "Step 2: Importing images to k0s containerd..."

# Create temp directory for image tars
mkdir -p /tmp/k0s-images

# Save Docker images to tar files
echo "Saving Docker images to tar files..."
docker save service-auth-admin:latest -o /tmp/k0s-images/service-auth-admin.tar
docker save service-auth-warga:latest -o /tmp/k0s-images/service-auth-warga.tar
docker save service-pembuat-laporan:latest -o /tmp/k0s-images/service-pembuat-laporan.tar
docker save service-penerima-laporan:latest -o /tmp/k0s-images/service-penerima-laporan.tar
docker save client-user:latest -o /tmp/k0s-images/client-user.tar
docker save client-admin:latest -o /tmp/k0s-images/client-admin.tar

# Import images to k0s containerd
echo "Importing images to k0s containerd..."
sudo k0s ctr images import /tmp/k0s-images/service-auth-admin.tar
sudo k0s ctr images import /tmp/k0s-images/service-auth-warga.tar
sudo k0s ctr images import /tmp/k0s-images/service-pembuat-laporan.tar
sudo k0s ctr images import /tmp/k0s-images/service-penerima-laporan.tar
sudo k0s ctr images import /tmp/k0s-images/client-user.tar
sudo k0s ctr images import /tmp/k0s-images/client-admin.tar

# Cleanup tar files
echo "Cleaning up temporary tar files..."
rm -rf /tmp/k0s-images

echo "Images imported successfully!"
echo ""

# Verify images
echo "Verifying images in containerd..."
sudo k0s ctr images ls | grep -E "service-auth|service-pembuat|service-penerima|client-"
echo ""

echo "Step 3: Deploying to Kubernetes..."
kubectl apply -f k8s-all-in-one.yaml

echo ""
echo "Step 4: Waiting for deployments to be ready..."

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
echo "Step 5: Checking deployment status..."
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

# Get ingress NodePort
INGRESS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
SERVER_IP=$(hostname -I | awk '{print $1}')

if [ -n "$INGRESS_PORT" ]; then
    echo "Access your applications via Ingress:"
    echo "- User Portal: http://${SERVER_IP}:${INGRESS_PORT}/user"
    echo "- Admin Portal: http://${SERVER_IP}:${INGRESS_PORT}/admin"
    echo ""
    echo "API Endpoints:"
    echo "- User Auth: http://${SERVER_IP}:${INGRESS_PORT}/api/warga/auth/*"
    echo "- User Reports: http://${SERVER_IP}:${INGRESS_PORT}/api/warga/laporan"
    echo "- Admin Auth: http://${SERVER_IP}:${INGRESS_PORT}/api/admin/auth/*"
    echo "- Admin Reports: http://${SERVER_IP}:${INGRESS_PORT}/api/admin/laporan"
else
    echo "Could not detect Ingress NodePort."
    echo "Run: kubectl get svc -n ingress-nginx"
fi
echo ""

echo "Direct NodePort access (bypass ingress):"
echo "- User Portal: http://${SERVER_IP}:30086"
echo "- Admin Portal: http://${SERVER_IP}:30081"
echo ""

echo "To check logs:"
echo "  kubectl logs -l app=service-auth-warga"
echo "  kubectl logs -l app=service-auth-admin"
echo "  kubectl logs -l app=service-pembuat-laporan"
echo "  kubectl logs -l app=service-penerima-laporan"
echo ""
echo "To check Ingress status:"
echo "  kubectl get ingress"
echo "  kubectl get svc -n ingress-nginx"
echo ""
