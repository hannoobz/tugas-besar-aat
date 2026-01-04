#!/bin/bash

echo "======================================"
echo "  Checking Deployment Status"
echo "======================================"
echo ""

echo "=== Deployments ==="
kubectl get deployments -o wide
echo ""

echo "=== Pods ==="
kubectl get pods -o wide
echo ""

echo "=== Services ==="
kubectl get services
echo ""

echo "=== ConfigMaps ==="
kubectl get configmaps
echo ""

echo "=== HPA ==="
kubectl get hpa
echo ""

echo "======================================"
echo "  Checking Pod Status Details"
echo "======================================"
echo ""

# Check if any pods are not running
NOT_RUNNING=$(kubectl get pods --field-selector=status.phase!=Running --no-headers 2>/dev/null)
if [ ! -z "$NOT_RUNNING" ]; then
    echo "⚠️  WARNING: Some pods are not running:"
    echo "$NOT_RUNNING"
    echo ""
    echo "To check pod details:"
    echo "  kubectl describe pod <POD_NAME>"
    echo "  kubectl logs <POD_NAME>"
else
    echo "✅ All pods are running!"
fi

echo ""
echo "======================================"
echo "  Access URLs"
echo "======================================"
echo ""
echo "- User Portal: http://localhost:30080"
echo "- Admin Portal: http://localhost:30081"
echo "- Service Pembuat Laporan API: http://localhost:30082"
echo "- Service Penerima Laporan API: http://localhost:30083"
echo "- Service Auth Warga API: http://localhost:30084"
echo "- Service Auth Admin API: http://localhost:30085"
echo ""
