# Laporan System - Kubernetes POC

Proof of Concept untuk sistem pelaporan yang mendemonstrasikan **Reliability** dan **Scalability** menggunakan Kubernetes.

## 🏗️ Arsitektur Sistem

Sistem ini terdiri dari 6 komponen yang di-orchestrate oleh Kubernetes:

1. **PostgreSQL Database (Laporan)** - Menyimpan data laporan
2. **PostgreSQL Database (Auth)** - Menyimpan data user dan admin (database terpisah)
3. **Service Pembuat Laporan (Go)** - Backend untuk user membuat laporan (scaled to 3 replicas)
4. **Service Penerima Laporan (Node.js)** - Backend untuk admin mengelola laporan
5. **Client User (Frontend)** - Interface untuk user dengan login/register
6. **Client Admin (Frontend)** - Interface untuk admin dengan login/register

## 📋 Prerequisites

- Docker Desktop dengan Kubernetes enabled
- kubectl CLI tool
- Minimal 4GB RAM tersedia untuk Docker

## 🔐 Authentication Flow

### User Flow:
1. Register via **User Register** (`http://localhost/user/register.html`)
   - Input: **NIK (16 digit)**, Nama Lengkap, Email, Password
2. Login via **User Login** (`http://localhost/user/login.html`)
   - Input: **NIK (16 digit)**, Password
3. Create reports (authenticated with JWT)

### Admin Flow:
1. Register via **Admin Register** (`http://localhost/admin/register.html`)
   - Input: Username, Email, Password
2. Login via **Admin Login** (`http://localhost/admin/login.html`)
   - Input: Username, Password
3. Manage reports (authenticated with JWT)

### Database Schema:
- **User accounts**: Identified by **NIK (16 digit)** as unique identifier
- **Admin accounts**: Identified by **username**
- Separate authentication database for security

### Security Features:
- Separate databases for reports and authentication
- JWT access tokens (15 minutes expiry)
- JWT refresh tokens (7 days expiry)
- Password hashing with bcrypt
- Password requirements: min 8 chars, uppercase, lowercase, number, special char
- Token refresh mechanism for seamless experience
- Role-based access control (user vs admin)

## 🚀 Deployment Instructions

### Step 1: Install NGINX Ingress Controller

```bash
# Install Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for Ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Step 2: Build Docker Images

Buka terminal di root project dan jalankan:

```bash
# Build Service Pembuat Laporan (Go)
cd service-pembuat-laporan
docker build -t service-pembuat-laporan:latest .
cd ..

# Build Service Penerima Laporan (Node.js)
cd service-penerima-laporan
docker build -t service-penerima-laporan:latest .
cd ..

# Build Client User
cd client-user
docker build -t client-user:latest .
cd ..

# Build Client Admin
cd client-admin
docker build -t client-admin:latest .
cd ..
```

### Step 3: Deploy ke Kubernetes

```bash
# Apply semua manifests (termasuk Ingress)
kubectl apply -f k8s-all-in-one.yaml

# Verify deployments
kubectl get deployments

# Verify pods
kubectl get pods

# Verify services
kubectl get services

# Verify Ingress
kubectl get ingress
```

### Step 4: Tunggu Semua Pods Running

```bash
# Watch pods status
kubectl get pods -w

# Pods harus dalam status Running:
# - postgres-xxx (3 database pods)
# - service-auth-warga-xxx (2 replicas)
# - service-auth-admin-xxx (2 replicas)
# - service-pembuat-laporan-xxx (3 replicas)
# - service-penerima-laporan-xxx
# - client-user-xxx
# - client-admin-xxx
```

### Step 5: Access Applications

Setelah semua pods running dan Ingress ready:

- **User Interface**: http://localhost/user
- **Admin Interface**: http://localhost/admin
- **Root URL**: http://localhost/ (redirects to user interface)

**API Endpoints (for testing):**
- User Auth: http://localhost/api/warga/auth/*
- User Reports: http://localhost/api/warga/laporan
- Admin Auth: http://localhost/api/admin/auth/*
- Admin Reports: http://localhost/api/admin/laporan

**Note**: Ingress menggunakan path-based routing, tidak ada port number yang perlu diingat!

## 🧪 Testing the System

### Test 1: Membuat Laporan (User Side)

1. Buka http://localhost/user
2. Register atau login dengan credentials yang sudah dibuat
3. Isi form dengan:
   - Judul: "Test Laporan 1"
   - Deskripsi: "Ini adalah test laporan"
4. Klik "Kirim Laporan"
5. Seharusnya muncul pesan sukses dengan ID laporan

### Test 2: Melihat dan Update Laporan (Admin Side)

1. Buka http://localhost/admin
2. Register atau login dengan credentials admin
3. Anda akan melihat semua laporan termasuk yang baru dibuat
4. Klik salah satu status button (In Progress, Completed, dll)
5. Status akan terupdate dan dashboard akan refresh

### Test 3: Reliability - Delete Admin Pod

```bash
# Get admin pod name
kubectl get pods | grep client-admin

# Delete admin pod
kubectl delete pod client-admin-xxx

# User service tetap bisa membuat laporan
# Buka http://localhost/user dan coba buat laporan baru
# Seharusnya tetap berfungsi!

# Admin pod akan otomatis recreated oleh Kubernetes
kubectl get pods | grep client-admin
```

### Test 4: Scalability - Lihat Go Service Replicas

```bash
# Lihat 3 replicas Go service
kubectl get pods | grep service-pembuat-laporan

# Seharusnya ada 3 pods:
# service-pembuat-laporan-xxx-1
# service-pembuat-laporan-xxx-2
# service-pembuat-laporan-xxx-3

# Delete satu pod
kubectl delete pod service-pembuat-laporan-xxx-1

# Kubernetes akan otomatis create pod baru
# Service tetap available karena ada 2 pod lain
```

## 🔍 Monitoring & Debugging

### Check Logs

```bash
# Logs database
kubectl logs -l app=postgres

# Logs Go service (pilih salah satu pod)
kubectl logs -l app=service-pembuat-laporan

# Logs Node service
kubectl logs -l app=service-penerima-laporan

# Logs frontend
kubectl logs -l app=client-user
kubectl logs -l app=client-admin
```

### Check Pod Details

```bash
# Describe specific pod
kubectl describe pod <pod-name>

# Check pod events
kubectl get events --sort-by='.lastTimestamp'
```

### Access Database Directly

```bash
# Port forward postgres
kubectl port-forward service/postgres 5432:5432

# Connect using psql (in another terminal)
psql -h localhost -U postgres -d laporandb
# Password: postgres

# Query laporan
SELECT * FROM laporan;
```

## 📊 Architecture Highlights

### Modern Architecture with Ingress
- **Path-Based Routing**: Clean URLs tanpa port numbers (http://localhost/user)
- **Single Entry Point**: NGINX Ingress Controller sebagai gateway
- **Automatic SSL Ready**: Mudah tambahkan HTTPS dengan cert-manager
- **Production Pattern**: Industry standard untuk Kubernetes deployments

### Reliability
- **Service Isolation**: Admin service dan User service terpisah - jika satu crash, yang lain tetap jalan
- **Auto-Healing**: Kubernetes otomatis restart pods yang crash
- **Health Checks**: Liveness dan readiness probes untuk semua services

### Scalability
- **Horizontal Scaling**: Service Pembuat Laporan (Go) di-scale ke 3 replicas
- **Load Balancing**: Kubernetes Service otomatis distribute traffic ke 3 pods
- **Stateless Backend**: Semua backend services stateless, mudah di-scale

### Service Discovery
- **ClusterIP Services**: Backend services (Go, Node, Postgres) hanya accessible dalam cluster
- **NodePort Services**: Frontend services accessible dari luar cluster
- **Environment Variables**: ConfigMap untuk database credentials

## ⚠️ Security Disclaimer

**THIS IS A PROOF OF CONCEPT FOR EDUCATIONAL PURPOSES ONLY**

This codebase contains intentional security vulnerabilities to demonstrate concepts:

### Known Critical Issues:
- ❌ **XSS Vulnerabilities** - No input sanitization or output encoding
- ❌ **JWT in localStorage** - Tokens vulnerable to XSS attacks
- ❌ **No HTTPS** - All traffic unencrypted
- ❌ **Weak secrets** - Default JWT secrets in code
- ❌ **No rate limiting** - Vulnerable to brute force
- ❌ **No CSRF protection** - Cross-site request forgery possible

### Implemented Security Features:
- ✅ **Content Security Policy** - CSP headers on all services
- ✅ **Additional Headers** - X-Frame-Options, X-Content-Type-Options, etc.

### For Production Use, You Must:
1. ✅ Add Content Security Policy headers (DONE)
2. ❌ Implement input sanitization (XSS library)
3. ❌ Use HTTP-only cookies for tokens
4. ❌ Enable HTTPS/TLS
5. ❌ Use Kubernetes Secrets (not ConfigMaps) for credentials
6. ❌ Add rate limiting and CSRF tokens
7. ❌ Remove `'unsafe-inline'` from CSP and externalize scripts
8. ❌ Implement proper logging and monitoring

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f k8s-all-in-one.yaml

# Verify deletion
kubectl get all
```

## 📁 Project Structure

```
.
├── k8s-all-in-one.yaml              # Kubernetes manifests + Ingress
├── db/
│   ├── init.sql                      # Laporan database schema
│   └── init-auth.sql                 # Auth database schema
├── service-auth-warga/               # Go auth service for users
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── service-auth-admin/               # Node.js auth service for admins
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── service-pembuat-laporan/          # Go service for creating reports
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── service-penerima-laporan/         # Node.js service for managing reports
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── client-user/                      # User frontend with auth
│   ├── index.html
│   ├── login.html
│   ├── register.html
│   ├── nginx.conf
│   └── Dockerfile
└── client-admin/                     # Admin frontend with auth
    ├── index.html
    ├── login.html
    ├── register.html
    ├── nginx.conf
    └── Dockerfile
```

## 💡 Key Features

1. **JWT Authentication** - Secure login/register untuk user dan admin
2. **Ingress Gateway** - Path-based routing tanpa port numbers
3. **Microservices Architecture** - 6 distinct services dengan responsibilities yang jelas
4. **Separate Auth Services** - Dedicated authentication services (Go + Node.js)
5. **Multiple Databases** - Separate databases untuk auth, user data, dan reports
6. **Production-Ready K8s Config** - Ingress, ConfigMaps, health checks, proper service types
7. **Auto-Scaling** - HPA untuk service-pembuat-laporan
8. **Easy to Demo** - Automated deployment script, clear testing steps

## 🎓 Academic Context

Project ini dibuat sebagai Proof of Concept untuk tugas besar matakuliah AAT (Arsitektur Aplikasi Terdistribusi). Fokus utama adalah mendemonstrasikan:

- **Reliability melalui isolation**: User tetap bisa submit laporan walau admin service down
- **Scalability melalui replication**: 3 replicas Go service untuk handle high traffic
- **Orchestration**: Kubernetes manages lifecycle semua components

---

**Note**: Code generated with the assistance of Claude Sonnet for implementation logic.
