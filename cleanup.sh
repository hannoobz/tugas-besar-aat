#!/bin/bash

echo "======================================"
echo "  Cleaning up old deployments"
echo "======================================"
echo ""

# Delete old postgres deployment if exists
echo "Removing old postgres deployments..."
kubectl delete deployment postgres --ignore-not-found=true
kubectl delete service postgres --ignore-not-found=true
kubectl delete deployment postgres-auth --ignore-not-found=true
kubectl delete service postgres-auth --ignore-not-found=true

# Delete old configmaps
echo "Removing old configmaps..."
kubectl delete configmap db-config --ignore-not-found=true
kubectl delete configmap auth-db-config --ignore-not-found=true
kubectl delete configmap postgres-init-script --ignore-not-found=true
kubectl delete configmap postgres-auth-init-script --ignore-not-found=true

# Delete all existing deployments and services
echo "Removing all existing deployments..."
kubectl delete deployment --all --ignore-not-found=true

echo "Removing all existing services (except kubernetes)..."
kubectl delete service --all --ignore-not-found=true
kubectl delete service kubernetes --ignore-not-found=true

echo "Removing all configmaps..."
kubectl delete configmap --all --ignore-not-found=true

echo "Removing all HPA..."
kubectl delete hpa --all --ignore-not-found=true

echo ""
echo "Waiting for resources to be deleted..."
sleep 5

echo ""
echo "======================================"
echo "  Cleanup complete!"
echo "======================================"
echo ""
