#!/bin/bash

echo "======================================"
echo "  Cleaning up old deployments"
echo "======================================"
echo ""

# Delete only Laporan system deployments (by label or specific names)
echo "Removing Laporan system deployments..."
kubectl delete deployment client-user --ignore-not-found=true
kubectl delete deployment client-admin --ignore-not-found=true
kubectl delete deployment service-pembuat-laporan --ignore-not-found=true
kubectl delete deployment service-penerima-laporan --ignore-not-found=true
kubectl delete deployment service-auth-warga --ignore-not-found=true
kubectl delete deployment service-auth-admin --ignore-not-found=true
kubectl delete deployment postgres-laporan --ignore-not-found=true
kubectl delete deployment postgres-warga --ignore-not-found=true
kubectl delete deployment postgres-admin --ignore-not-found=true

# Delete only Laporan system services
echo "Removing Laporan system services..."
kubectl delete service client-user --ignore-not-found=true
kubectl delete service client-admin --ignore-not-found=true
kubectl delete service service-pembuat-laporan --ignore-not-found=true
kubectl delete service service-penerima-laporan --ignore-not-found=true
kubectl delete service service-auth-warga --ignore-not-found=true
kubectl delete service service-auth-admin --ignore-not-found=true
kubectl delete service postgres-laporan --ignore-not-found=true
kubectl delete service postgres-warga --ignore-not-found=true
kubectl delete service postgres-admin --ignore-not-found=true

# Delete only Laporan system configmaps
echo "Removing Laporan system configmaps..."
kubectl delete configmap warga-db-config --ignore-not-found=true
kubectl delete configmap admin-db-config --ignore-not-found=true
kubectl delete configmap laporan-db-config --ignore-not-found=true
kubectl delete configmap jwt-config --ignore-not-found=true
kubectl delete configmap warga-db-init --ignore-not-found=true
kubectl delete configmap admin-db-init --ignore-not-found=true
kubectl delete configmap laporan-db-init --ignore-not-found=true

# Delete only Laporan system HPA
echo "Removing Laporan system HPA..."
kubectl delete hpa service-pembuat-laporan-hpa --ignore-not-found=true

# Delete only Laporan system ingress
echo "Removing Laporan system ingress..."
kubectl delete ingress laporan-system-ingress --ignore-not-found=true
kubectl delete ingress laporan-root-ingress --ignore-not-found=true
kubectl delete ingress laporan-api-ingress --ignore-not-found=true

# Delete old deployments if they exist (legacy names)
echo "Removing legacy deployments..."
kubectl delete deployment postgres --ignore-not-found=true
kubectl delete service postgres --ignore-not-found=true
kubectl delete deployment postgres-auth --ignore-not-found=true
kubectl delete service postgres-auth --ignore-not-found=true
kubectl delete configmap db-config --ignore-not-found=true
kubectl delete configmap auth-db-config --ignore-not-found=true
kubectl delete configmap postgres-init-script --ignore-not-found=true
kubectl delete configmap postgres-auth-init-script --ignore-not-found=true

echo ""
echo "Waiting for resources to be deleted..."
sleep 5

