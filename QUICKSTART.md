# Quick Start Guide

## 🚀 Fastest Way to Deploy

```bash
# Make sure Docker Desktop is running with Kubernetes enabled
./deploy.sh
```

That's it! The script will:
1. Build all 4 Docker images
2. Deploy to Kubernetes
3. Wait for all pods to be ready
4. Show you the URLs to access

## 🌐 Access URLs

- **User Portal**: http://localhost:30080
- **Admin Dashboard**: http://localhost:30081

## 🧪 Quick Test Scenario

1. Open User Portal (localhost:30080)
2. Create a new report:
   - Title: "Broken Street Light"
   - Description: "Street light on Main St is not working"
3. Go to Admin Dashboard (localhost:30081)
4. See your report appear
5. Click "In Progress" button to update status
6. Status updates in real-time!

## 🔥 Test Reliability

```bash
# Delete admin pod to simulate crash
kubectl delete pod -l app=client-admin

# User service still works!
# Go to localhost:30080 and create another report
# Admin pod will auto-restart
```

## 📊 Test Scalability

```bash
# See 3 replicas of Go service
kubectl get pods -l app=service-pembuat-laporan

# Delete one
kubectl delete pod <pod-name>

# Service still works! Other 2 replicas handle traffic
# Kubernetes will auto-create a new pod
```

## 🧹 Cleanup

```bash
./cleanup.sh
```

## 📝 Useful Commands

```bash
# View all pods
kubectl get pods

# View all services
kubectl get services

# View logs from Go service
kubectl logs -l app=service-pembuat-laporan

# View logs from Node service
kubectl logs -l app=service-penerima-laporan

# Describe a specific pod
kubectl describe pod <pod-name>

# Port forward to database (if needed)
kubectl port-forward service/postgres 5432:5432
```

## 🎯 Demo Flow for Presentation

1. Show the architecture diagram (5 components)
2. Run `./deploy.sh` and explain what's happening
3. Show `kubectl get pods` - point out 3 Go replicas
4. Demo User Portal - create 2-3 reports
5. Demo Admin Dashboard - update statuses
6. **Reliability**: Delete admin pod, show user still works
7. **Scalability**: Show 3 Go replicas handling requests
8. Show logs to prove everything is working
9. Run `./cleanup.sh`

## 🐛 Troubleshooting

### Pods not starting?
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Can't access frontend?
```bash
# Check if services are running
kubectl get services

# Check if Docker Desktop Kubernetes is enabled
# Docker Desktop > Preferences > Kubernetes > Enable
```

### Database connection errors?
```bash
# Check if postgres pod is running
kubectl get pods -l app=postgres

# Check logs
kubectl logs -l app=postgres
```

## 📚 What to Explain in Presentation

### Reliability
- **Isolation**: 5 separate deployments
- **Auto-healing**: Kubernetes restarts failed pods
- **Health checks**: Liveness and readiness probes
- **Demo**: Delete admin pod, user still works

### Scalability
- **Horizontal scaling**: 3 replicas of Go service
- **Load balancing**: Kubernetes distributes traffic
- **Stateless design**: Easy to scale up/down
- **Demo**: Show 3 pods handling requests

### Kubernetes Benefits
- **Service Discovery**: Services find each other by name
- **ConfigMaps**: Centralized configuration
- **Declarative**: Describe desired state, K8s handles it
- **Self-healing**: Automatic pod replacement

---
