# Load Testing & Autoscaling Demo

This directory contains scripts to demonstrate Kubernetes Horizontal Pod Autoscaling (HPA) for the Service Pembuat Laporan.

## Prerequisites

1. **Metrics Server** (will be enabled automatically by the scripts)
2. **K6** (optional, for advanced load testing)

## What Gets Tested

The autoscaler is configured to:
- **Minimum replicas**: 2
- **Maximum replicas**: 10
- **Target CPU utilization**: 50%
- **Scale up**: Fast (can double capacity every 15 seconds)
- **Scale down**: Gradual (50% reduction every 15 seconds, with 60s stabilization)

## Option 1: Full Load Test with K6 (Recommended)

### Install K6

**macOS:**
```bash
brew install k6
```

**Linux:**
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

**Windows:**
```bash
choco install k6
```

### Run the Test

```bash
./run-load-test.sh
```

**What happens:**
1. Enables metrics-server if needed
2. Applies HPA configuration
3. Runs 8-minute load test with varying load:
   - Ramp up to 50 users (1 min)
   - Maintain 50 users (2 min) → **Triggers scale-up**
   - Spike to 100 users (1.5 min) → **More scaling**
   - Ramp down to 20 users (1 min)
   - Low load (2 min) → **Triggers scale-down**
4. Live monitoring of pod count and HPA status
5. Generates `load-test-results.json` with detailed metrics

## Option 2: Simple Load Test (No K6 Required)

Uses curl to send HTTP requests:

```bash
./simple-load-test.sh
```

**What happens:**
1. Phase 1: Light load (1 req/s for 30s)
2. Phase 2: Heavy load (10 req/s for 60s) → **Triggers scale-up**
3. Phase 3: Cool down (60s) → **Triggers scale-down**

## Manual Testing

### Watch Autoscaling in Real-Time

```bash
watch -n 2 'kubectl get hpa && echo && kubectl get pods -l app=service-pembuat-laporan'
```

### Check Current Status

```bash
# View HPA status
kubectl get hpa service-pembuat-laporan-hpa

# View pods
kubectl get pods -l app=service-pembuat-laporan

# View detailed HPA info
kubectl describe hpa service-pembuat-laporan-hpa

# View events
kubectl get events --sort-by='.lastTimestamp' | grep service-pembuat-laporan
```

### Manual Load Generation

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Send single request
curl -X POST "http://$MINIKUBE_IP:30082/laporan" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Report","description":"Testing autoscaling"}'

# Send burst of requests
for i in {1..100}; do
  curl -s -X POST "http://$MINIKUBE_IP:30082/laporan" \
    -H "Content-Type: application/json" \
    -d '{"title":"Load Test '$i'","description":"Burst test"}' &
done
```

## Expected Behavior

### Scale Up Triggers:
- **CPU usage > 50%**: When enough requests come in to stress the Go service
- **Response**: New pods are created quickly (up to doubling every 15s)
- **Max replicas**: Will not exceed 10 pods

### Scale Down Triggers:
- **CPU usage < 50%**: When load decreases significantly
- **Stabilization**: Waits 60 seconds to ensure load is consistently low
- **Response**: Gradually removes pods (50% reduction every 15s)
- **Min replicas**: Will not go below 2 pods

### Timeline Example:
```
0:00 - Start: 3 pods (initial deployment)
0:30 - Apply HPA: Scales down to 2 pods (min replicas)
1:00 - Heavy load starts
1:15 - CPU usage rises → Scale to 3 pods
1:30 - Still high CPU → Scale to 4 pods
2:00 - Very high load → Scale to 6-8 pods
3:00 - Load decreases
4:00 - CPU normalized → Still at high pod count (stabilization window)
5:00 - Consistently low CPU → Start scaling down
5:15 - Scale to 4 pods
5:30 - Scale to 3 pods
6:00 - Scale to 2 pods (min replicas)
```

## Troubleshooting

### HPA shows "unknown" for CPU
```bash
# Check if metrics-server is running
kubectl get pods -n kube-system | grep metrics-server

# Enable if not running
minikube addons enable metrics-server

# Wait 30-60 seconds for metrics to be collected
```

### Pods not scaling
```bash
# Check HPA status
kubectl describe hpa service-pembuat-laporan-hpa

# Check pod resource requests/limits
kubectl get pods -l app=service-pembuat-laporan -o yaml | grep -A 5 resources

# Check current CPU usage
kubectl top pods -l app=service-pembuat-laporan
```

### Load test fails
```bash
# Verify service is accessible
MINIKUBE_IP=$(minikube ip)
curl "http://$MINIKUBE_IP:30082/health"

# Check pod logs
kubectl logs -l app=service-pembuat-laporan --tail=50
```

## Cleanup

To remove the HPA and reset to static 3 replicas:

```bash
kubectl delete hpa service-pembuat-laporan-hpa
kubectl scale deployment service-pembuat-laporan --replicas=3
```

## Architecture Notes

The Service Pembuat Laporan (Golang) is the best candidate for autoscaling because:
1. **Stateless**: Each pod can handle requests independently
2. **High traffic**: Designed to handle report creation (write-heavy)
3. **CPU-bound**: Go compilation and database writes use CPU
4. **Horizontally scalable**: Load balancer distributes requests evenly

The other services (Node.js admin, frontends) have lower traffic and don't benefit as much from autoscaling in this POC.
