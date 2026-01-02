#!/bin/bash

echo "======================================"
echo "  Kubernetes Autoscaling Demo with K6"
echo "======================================"
echo ""

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo "❌ K6 is not installed!"
    echo ""
    echo "Please install K6 first:"
    echo "  macOS:   brew install k6"
    echo "  Linux:   sudo gpg -k && sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69 && echo 'deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list && sudo apt-get update && sudo apt-get install k6"
    echo "  Windows: choco install k6"
    echo ""
    echo "Or download from: https://k6.io/docs/get-started/installation/"
    exit 1
fi

# Check if metrics-server is installed
echo "Checking if metrics-server is enabled in Minikube..."
if ! minikube addons list | grep -q "metrics-server.*enabled"; then
    echo "📊 Enabling metrics-server addon..."
    minikube addons enable metrics-server
    echo "⏳ Waiting for metrics-server to be ready (30 seconds)..."
    sleep 30
else
    echo "✅ Metrics-server is already enabled"
fi

# Apply updated Kubernetes configuration with HPA
echo ""
echo "Step 1: Applying updated Kubernetes configuration with HPA..."
echo "-----------------------------------"
kubectl apply -f k8s-all-in-one.yaml

echo ""
echo "Step 2: Waiting for pods to be ready..."
echo "-----------------------------------"
kubectl wait --for=condition=ready pod -l app=service-pembuat-laporan --timeout=60s

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
echo ""
echo "✅ Minikube IP: $MINIKUBE_IP"

# Display current status
echo ""
echo "Step 3: Current deployment status"
echo "-----------------------------------"
kubectl get hpa service-pembuat-laporan-hpa
echo ""
kubectl get pods -l app=service-pembuat-laporan

echo ""
echo "======================================"
echo "  Starting Load Test"
echo "======================================"
echo ""
echo "The load test will:"
echo "  1. Ramp up to 50 users over 1 minute"
echo "  2. Maintain 50 users for 2 minutes (trigger scale-up)"
echo "  3. Spike to 100 users for 1.5 minutes"
echo "  4. Ramp down to 20 users (trigger scale-down)"
echo "  5. Maintain low load for 2 minutes"
echo ""
echo "Total duration: ~8 minutes"
echo ""
echo "Monitor autoscaling in another terminal with:"
echo "  watch -n 2 'kubectl get hpa && echo && kubectl get pods -l app=service-pembuat-laporan'"
echo ""
read -p "Press ENTER to start the load test..."

# Run K6 load test in background
echo ""
echo "🚀 Starting K6 load test..."
echo ""
MINIKUBE_IP=$MINIKUBE_IP k6 run load-test.js &
K6_PID=$!

# Monitor HPA and pods
echo ""
echo "📊 Monitoring autoscaling (Ctrl+C to stop monitoring, load test will continue)..."
echo ""
sleep 5

# Monitor loop
while kill -0 $K6_PID 2>/dev/null; do
    clear
    echo "======================================"
    echo "  Live Autoscaling Monitor"
    echo "======================================"
    echo ""
    date
    echo ""
    
    echo "HPA Status:"
    echo "-----------------------------------"
    kubectl get hpa service-pembuat-laporan-hpa
    
    echo ""
    echo "Pod Status:"
    echo "-----------------------------------"
    kubectl get pods -l app=service-pembuat-laporan -o wide
    
    echo ""
    echo "Recent Events:"
    echo "-----------------------------------"
    kubectl get events --field-selector involvedObject.name=service-pembuat-laporan-hpa --sort-by='.lastTimestamp' | tail -n 5
    
    echo ""
    echo "Press Ctrl+C to stop monitoring (load test continues in background)"
    echo "K6 PID: $K6_PID"
    
    sleep 10
done

echo ""
echo "======================================"
echo "  Load Test Complete!"
echo "======================================"
echo ""
echo "Final Status:"
kubectl get hpa service-pembuat-laporan-hpa
echo ""
kubectl get pods -l app=service-pembuat-laporan

echo ""
echo "Results saved to: load-test-results.json"
echo ""
