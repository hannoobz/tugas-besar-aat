#!/bin/bash

echo "======================================"
echo "  Cleaning up Kubernetes resources"
echo "======================================"
echo ""

kubectl delete -f k8s-all-in-one.yaml

echo ""
echo "Waiting for resources to be deleted..."
sleep 5

echo ""
echo "Remaining resources:"
kubectl get all

echo ""
echo "✅ Cleanup complete!"
