#!/bin/bash

echo "======================================"
echo "  Simple Load Test (without K6)"
echo "======================================"
echo ""

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
API_URL="http://$MINIKUBE_IP:30082/laporan"

echo "Target: $API_URL"
echo ""

# Check if metrics-server is enabled
echo "Checking metrics-server..."
if ! minikube addons list | grep -q "metrics-server.*enabled"; then
    echo "📊 Enabling metrics-server addon..."
    minikube addons enable metrics-server
    echo "⏳ Waiting for metrics-server to be ready..."
    sleep 30
fi

# Apply HPA configuration
echo ""
echo "Applying HPA configuration..."
kubectl apply -f k8s-all-in-one.yaml

echo ""
echo "Initial status:"
kubectl get hpa service-pembuat-laporan-hpa 2>/dev/null || echo "HPA not ready yet..."
kubectl get pods -l app=service-pembuat-laporan

echo ""
echo "======================================"
echo "  Phase 1: Light Load (30 seconds)"
echo "======================================"
echo "Sending 1 request per second..."
echo ""

for i in {1..30}; do
    curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d '{"title":"Test Report '$i'","description":"Load test report"}' \
        > /dev/null &
    echo -n "."
    sleep 1
done

echo ""
echo ""
kubectl get hpa service-pembuat-laporan-hpa
kubectl get pods -l app=service-pembuat-laporan

echo ""
echo "======================================"
echo "  Phase 2: Heavy Load (60 seconds)"
echo "======================================"
echo "Sending 10 concurrent requests per second..."
echo ""

# Function to send burst of requests
send_burst() {
    for j in {1..10}; do
        curl -s -X POST "$API_URL" \
            -H "Content-Type: application/json" \
            -d '{"title":"Heavy Load Test","description":"Concurrent request"}' \
            > /dev/null &
    done
}

for i in {1..60}; do
    send_burst
    echo -n "."
    if [ $((i % 10)) -eq 0 ]; then
        echo " [$i/60]"
        kubectl get hpa service-pembuat-laporan-hpa 2>/dev/null | tail -n 1
        kubectl get pods -l app=service-pembuat-laporan --no-headers | wc -l | xargs echo "Pods:"
    fi
    sleep 1
done

echo ""
echo ""
echo "Status after heavy load:"
kubectl get hpa service-pembuat-laporan-hpa
kubectl get pods -l app=service-pembuat-laporan

echo ""
echo "======================================"
echo "  Phase 3: Cooling Down (60 seconds)"
echo "======================================"
echo "Waiting for scale-down..."
echo ""

for i in {1..6}; do
    echo "Checking status... [$((i*10))/60 seconds]"
    kubectl get hpa service-pembuat-laporan-hpa
    kubectl get pods -l app=service-pembuat-laporan --no-headers | wc -l | xargs echo "Active pods:"
    echo ""
    sleep 10
done

echo ""
echo "======================================"
echo "  Final Status"
echo "======================================"
kubectl get hpa service-pembuat-laporan-hpa
echo ""
kubectl get pods -l app=service-pembuat-laporan

echo ""
echo "✅ Load test complete!"
echo ""
echo "To see detailed HPA events:"
echo "  kubectl describe hpa service-pembuat-laporan-hpa"
echo ""
