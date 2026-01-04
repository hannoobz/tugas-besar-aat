# Quick Start Guide

## 🚀 Fastest Way to Deploy

```bash
# 1. Install NGINX Ingress Controller (one-time setup)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# 2. Deploy the application
./deploy.sh
```

That's it! The script will:
1. Build all 6 Docker images (2 auth, 2 report services, 2 frontends)
2. Deploy to Kubernetes with Ingress
3. Wait for all pods to be ready
4. Show you the URLs to access

## 🌐 Access URLs (via Ingress)

- **User Portal**: http://localhost/user
- **Admin Dashboard**: http://localhost/admin

No port numbers needed! Clean URLs through path-based routing.

## 🧪 Quick Test Scenario

### Register & Login (Required)

1. **Register a User Account:**
   - Open http://localhost/user/register.html
   - NIK: 1234567890123456 (16 digits)
   - Nama Lengkap: Test User
   - Email: user@test.com
   - Password: Test@123

2. **Login:**
   - Open http://localhost/user/login.html
   - NIK: 1234567890123456
   - Password: Test@123

### Create Reports

3. Create a new report:
   - Title: "Broken Street Light"
   - Description: "Street light on Main St is not working"

### Admin Dashboard

4. **Register Admin Account:**
   - Open http://localhost/admin/register.html
   - Username: admin
   - Email: admin@test.com
   - Password: Admin@123

5. **Login as Admin:**
   - Open http://localhost/admin/login.html
   - Username: admin
   - Password: Admin@123

6. See your report appear
7. Click "In Progress" button to update status
8. Status updates in real-time!

## 🔥 Test Reliability

```bash
# Delete admin pod to simulate crash
kubectl delete pod -l app=service-penerima-laporan

# User service still works!
# Go to http://localhost/user and create another report
# Admin pod will auto-restart
```

## 📊 Test Scalability

```bash
# See 3 replicas of Go report service
kubectl get pods -l app=service-pembuat-laporan

# Delete one
kubectl delete pod <pod-name>

# Service still works! Other 2 replicas handle traffic
# Kubernetes will auto-create a new pod

# Test auto-scaling (HPA)
# If CPU usage increases, HPA will automatically scale up
kubectl get hpa
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

# View Ingress configuration
kubectl get ingress
kubectl describe ingress laporan-ingress

# View logs from auth services
kubectl logs -l app=service-auth-warga
kubectl logs -l app=service-auth-admin

# View logs from report services
kubectl logs -l app=service-pembuat-laporan
kubectl logs -l app=service-penerima-laporan

# Describe a specific pod
kubectl describe pod <pod-name>

# Port forward to database (if needed)
kubectl port-forward service/postgres-laporan 5432:5432
```

## 🎯 Demo Flow for Presentation

1. Show the architecture diagram (6 microservices with Ingress)
2. Explain Ingress benefits (single entry point, path-based routing, no port numbers)
3. Run `./deploy.sh` and explain what's happening
4. Show `kubectl get pods` - point out multiple replicas and auth services
5. **Authentication Flow**: 
   - Register user account at /user/register.html
   - Login at /user/login.html
   - Explain JWT tokens (access + refresh)
6. **User Flow**: Create 2-3 reports via authenticated session
7. **Admin Flow**:
   - Register admin account at /admin/register.html
   - Login and show separate admin authentication
   - Update report statuses
8. **Ingress Demo**: Show `kubectl get ingress` and explain path rewrites
9. **Reliability**: Delete admin pod, show user still works
10. **Scalability**: Show 3 Go replicas handling requests, explain HPA
11. **Security**: Show separate databases for auth and reports
12. Show logs to prove everything is working
13. Run `./cleanup.sh`

## 🐛 Troubleshooting

### Ingress not working?
```bash
# Check Ingress Controller is running
kubectl get pods -n ingress-nginx

# Check Ingress resource
kubectl describe ingress laporan-ingress

# Check for errors in Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Pods not starting?
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Authentication not working?
```bash
# Check auth service pods
kubectl get pods -l app=service-auth-warga
kubectl get pods -l app=service-auth-admin

# Check auth database
kubectl get pods -l app=postgres-warga
kubectl get pods -l app=postgres-admin

# View auth service logs
kubectl logs -l app=service-auth-warga
kubectl logs -l app=service-auth-admin
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
