#!/bin/bash

echo "======================================"
echo "  Laporan System - K8s Deployment"
echo "======================================"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed."
    exit 1
fi

echo "✅ Docker is running"
echo "✅ kubectl is available"
echo ""

# Check if using Minikube
USING_MINIKUBE=false
if kubectl config current-context | grep -q "minikube"; then
    USING_MINIKUBE=true
    echo "🔍 Detected Minikube environment"
    echo "📦 Setting Docker environment to use Minikube's Docker daemon..."
    eval $(minikube docker-env)
    echo "✅ Docker environment configured for Minikube"
    echo ""
fi

echo "Step 1: Building Docker images..."
echo "-----------------------------------"

echo "Building service-pembuat-laporan..."
cd service-pembuat-laporan
docker build -t service-pembuat-laporan:latest . || exit 1
cd ..

echo "Building service-penerima-laporan..."
cd service-penerima-laporan
docker build -t service-penerima-laporan:latest . || exit 1
cd ..

echo "Building client-user..."
cd client-user
docker build -t client-user:latest . || exit 1
cd ..

echo "Building client-admin..."
cd client-admin
docker build -t client-admin:latest . || exit 1
cd ..

echo "✅ All images built successfully!"
echo ""

echo "Step 2: Deploying to Kubernetes..."
echo "-----------------------------------"

kubectl apply -f k8s-all-in-one.yaml

echo ""
echo "✅ Deployment complete!"
echo ""

echo "Step 3: Waiting for pods to be ready..."
echo "-----------------------------------"
echo "This may take a few minutes..."
echo ""

# Wait for all deployments to be ready
kubectl wait --for=condition=available --timeout=300s deployment/postgres
kubectl wait --for=condition=available --timeout=300s deployment/service-pembuat-laporan
kubectl wait --for=condition=available --timeout=300s deployment/service-penerima-laporan
kubectl wait --for=condition=available --timeout=300s deployment/client-user
kubectl wait --for=condition=available --timeout=300s deployment/client-admin

echo ""
echo "✅ All pods are ready!"
echo ""

echo "======================================"
echo "  🎉 Deployment Successful!"
echo "======================================"
echo ""
echo "Access your applications:"
echo "  👤 User Interface:  http://localhost:30080"
echo "  🔧 Admin Interface: http://localhost:30081"
echo ""
echo "Check status:"
echo "  kubectl get pods"
echo "  kubectl get services"
echo ""
echo "View logs:"
echo "  kubectl logs -l app=service-pembuat-laporan"
echo "  kubectl logs -l app=service-penerima-laporan"
echo ""
echo "======================================"
