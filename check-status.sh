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
echo "  Access URLs (via Ingress)"
echo "======================================"
echo ""
echo "- User Portal: http://localhost/user"
echo "- Admin Portal: http://localhost/admin"
echo ""
echo "API Endpoints:"
echo "- User Auth: http://localhost/api/warga/auth/*"
echo "- User Reports: http://localhost/api/warga/laporan"
echo "- Admin Auth: http://localhost/api/admin/auth/*"
echo "- Admin Reports: http://localhost/api/admin/laporan"
echo ""
echo "Check Ingress:"
echo "  kubectl get ingress"
echo ""
