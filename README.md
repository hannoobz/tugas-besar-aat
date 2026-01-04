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
1. Register via **User Register** (`http://localhost:30080/register.html`)
   - Input: **NIK (16 digit)**, Nama Lengkap, Email, Password
2. Login via **User Login** (`http://localhost:30080/login.html`)
   - Input: **NIK (16 digit)**, Password
3. Create reports (authenticated with JWT)

### Admin Flow:
1. Register via **Admin Register** (`http://localhost:30081/register.html`)
   - Input: Username, Email, Password
2. Login via **Admin Login** (`http://localhost:30081/login.html`)
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

### Step 1: Build Docker Images

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

### Step 2: Deploy ke Kubernetes

```bash
# Apply semua manifests
kubectl apply -f k8s-all-in-one.yaml

# Verify deployments
kubectl get deployments

# Verify pods
kubectl get pods

# Verify services
kubectl get services
```

### Step 3: Tunggu Semua Pods Running

```bash
# Watch pods status
kubectl get pods -w

# Pods harus dalam status Running:
# - postgres-xxx
# - service-pembuat-laporan-xxx (3 replicas)
# - service-penerima-laporan-xxx
# - client-user-xxx
# - client-admin-xxx
```

### Step 4: Access Applications

Setelah semua pods running:

- **User Interface**: http://localhost:30080
- **Admin Interface**: http://localhost:30081

## 🧪 Testing the System

### Test 1: Membuat Laporan (User Side)

1. Buka http://localhost:30080
2. Isi form dengan:
   - Judul: "Test Laporan 1"
   - Deskripsi: "Ini adalah test laporan"
3. Klik "Kirim Laporan"
4. Seharusnya muncul pesan sukses dengan ID laporan

### Test 2: Melihat dan Update Laporan (Admin Side)

1. Buka http://localhost:30081
2. Anda akan melihat semua laporan termasuk yang baru dibuat
3. Klik salah satu status button (In Progress, Completed, dll)
4. Status akan terupdate dan dashboard akan refresh

### Test 3: Reliability - Delete Admin Pod

```bash
# Get admin pod name
kubectl get pods | grep client-admin

# Delete admin pod
kubectl delete pod client-admin-xxx

# User service tetap bisa membuat laporan
# Buka http://localhost:30080 dan coba buat laporan baru
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
├── k8s-all-in-one.yaml              # Kubernetes manifests
├── db/
│   └── init.sql                      # Database schema
├── service-pembuat-laporan/          # Go service
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── service-penerima-laporan/         # Node.js service
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── client-user/                      # User frontend
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile
└── client-admin/                     # Admin frontend
    ├── index.html
    ├── nginx.conf
    └── Dockerfile
```

## 💡 Key Features

1. **No Authentication** - Fokus pada K8s orchestration, bukan auth
2. **Simple Architecture** - Tidak ada Kafka/CDC, langsung ke Postgres
3. **Clean Separation** - 5 distinct components dengan responsibilities yang jelas
4. **Production-Ready K8s Config** - ConfigMaps, health checks, proper service types
5. **Easy to Demo** - Single command deployment, clear testing steps

## 🎓 Academic Context

Project ini dibuat sebagai Proof of Concept untuk tugas besar matakuliah AAT (Arsitektur Aplikasi Terdistribusi). Fokus utama adalah mendemonstrasikan:

- **Reliability melalui isolation**: User tetap bisa submit laporan walau admin service down
- **Scalability melalui replication**: 3 replicas Go service untuk handle high traffic
- **Orchestration**: Kubernetes manages lifecycle semua components

---

**Note**: Code generated with the assistance of Claude Sonnet for implementation logic.
