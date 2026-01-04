# Aplikasi Pelaporan Warga

> **Note:** This code implementation was generated with the assistance of Large Language Models (LLMs).

A microservices-based reporting system demonstrating **Reliability** and **Scalability** using Kubernetes orchestration.

## System Components

- **Client User** (Frontend) - Public report viewing and creation
- **Client Admin** (Frontend) - Admin dashboard for report management
- **Service Auth Warga** (Go) - User authentication service
- **Service Auth Admin** (Node.js) - Admin authentication service
- **Service Pembuat Laporan** (Go) - High-traffic report creation service (scaled to 3 replicas)
- **Service Penerima Laporan** (Node.js) - Report management and updates
- **PostgreSQL** - Three separate databases (warga, admin, laporan)

## Prerequisites

- Docker
- Kubernetes cluster (Minikube/k0s/k3s)
- kubectl configured
- NGINX Ingress Controller

## Quick Start

### 1. Install NGINX Ingress Controller

If not already installed:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 2. Deploy the System

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy all components
./deploy.sh
```

The deployment script will:
- Clean up any existing deployments
- Build all Docker images
- Deploy to Kubernetes
- Wait for all pods to be ready

### 3. Access the Applications

**Get Ingress IP/Hostname:**

For Minikube:
```bash
minikube ip
# Use this IP in URLs below
```

For k0s/k3s:
```bash
kubectl get ingress
# Use the EXTERNAL-IP or your server IP
```

**Access URLs:**

Replace `<INGRESS_IP>` with your cluster IP:

- **User Portal:** `http://<INGRESS_IP>/user`
- **Admin Portal:** `http://<INGRESS_IP>/admin`

**API Endpoints:**
- User Auth: `http://<INGRESS_IP>/api/warga/auth/*`
- User Reports: `http://<INGRESS_IP>/api/warga/laporan`
- Admin Auth: `http://<INGRESS_IP>/api/admin/auth/*`
- Admin Reports: `http://<INGRESS_IP>/api/admin/laporan`

### 4. Test the System

**Register a User:**
1. Go to `http://<INGRESS_IP>/user`
2. Click "Daftar" (Register)
3. Fill in:
   - NIK: Any 16-digit number (e.g., `1234567890123456`)
   - Nama: Your name
   - Email: Your email
   - Password: At least 8 characters

**Create a Report:**
1. Login with your credentials
2. Click "Buat Laporan" (Create Report)
3. Fill in the form and submit
4. View your report on the main page

**Admin Access:**
1. Go to `http://<INGRESS_IP>/admin`
2. Register an admin account (username + password)
3. Login and manage reports

## Monitoring

**Check deployment status:**
```bash
./check-status.sh
```

**View logs:**
```bash
# All pods
kubectl get pods

# Specific service logs
kubectl logs -f deployment/service-pembuat-laporan
kubectl logs -f deployment/service-penerima-laporan
```

**Check HPA (Horizontal Pod Autoscaler):**
```bash
kubectl get hpa
```

## Load Testing

Test system scalability with k6:

```bash
# Install k6 first (if not installed)
# See: https://k6.io/docs/get-started/installation/

# Run load test
k6 run load-test.js
```

The load test will:
- Spike to 100 concurrent users
- Auto-register 100 unique users
- Create reports with authentication
- Test system under extreme load

## Cleanup

To remove all deployments:

```bash
./cleanup.sh
```

This will safely remove only the Laporan system components, leaving other Kubernetes resources intact.

