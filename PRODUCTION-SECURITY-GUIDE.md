# Panduan Keamanan Produksi: CORS & TLS/SSL

Dokumen ini berisi panduan lengkap untuk mengimplementasikan CORS (Cross-Origin Resource Sharing) dan TLS/SSL pada lingkungan produksi untuk Sistem Laporan Masyarakat.

---

## Daftar Isi

1. [Pendahuluan](#1-pendahuluan)
2. [CORS (Cross-Origin Resource Sharing)](#2-cors-cross-origin-resource-sharing)
3. [TLS/SSL Configuration](#3-tlsssl-configuration)
4. [Kubernetes Production Setup](#4-kubernetes-production-setup)
5. [Monitoring & Maintenance](#5-monitoring--maintenance)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Pendahuluan

### 1.1 Mengapa Keamanan Penting?

| Aspek | Risiko Tanpa Keamanan | Solusi |
|-------|----------------------|--------|
| **Data in Transit** | Man-in-the-middle attack, data sniffing | TLS/SSL encryption |
| **Cross-Origin Attacks** | CSRF, XSS, data theft | CORS restriction |
| **Authentication** | Token hijacking | Secure cookies, HTTPS-only |

### 1.2 Arsitektur Keamanan

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUD LOAD BALANCER                          │
│                    (SSL Termination)                            │
│                    *.yourdomain.com                             │
└─────────────────────────────────────────────────────────────────┘
                              │ HTTPS (443)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX INGRESS CONTROLLER                     │
│                    - TLS Certificate                            │
│                    - CORS Headers                               │
│                    - Security Headers                           │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
     ┌───────────┐     ┌───────────┐     ┌───────────┐
     │  Service  │     │  Service  │     │  Service  │
     │  Pod 1    │     │  Pod 2    │     │  Pod 3    │
     └───────────┘     └───────────┘     └───────────┘
```

---

## 2. CORS (Cross-Origin Resource Sharing)

### 2.1 Apa itu CORS?

CORS adalah mekanisme keamanan browser yang mengontrol request dari satu origin (domain) ke origin lain. Tanpa CORS yang tepat:
- ❌ Website jahat bisa mengakses API Anda
- ❌ Data pengguna bisa dicuri via JavaScript
- ❌ CSRF attacks lebih mudah dilakukan

### 2.2 Konfigurasi CORS untuk Development vs Production

#### Development (Current Setup)
```go
// Allowed origins untuk development
var allowedOrigins = map[string]bool{
    "https://localhost":     true,
    "http://localhost":      true,
    "https://127.0.0.1":     true,
    "http://127.0.0.1":      true,
}
```

#### Production Setup
```go
// Allowed origins untuk production
var allowedOrigins = map[string]bool{
    "https://laporan.yourdomain.com":       true,
    "https://admin.laporan.yourdomain.com": true,
    "https://api.laporan.yourdomain.com":   true,
}
```

### 2.3 Implementasi CORS di Go Services

Berikut implementasi CORS yang aman untuk production:

```go
package main

import (
    "net/http"
    "os"
    "strings"
)

// Load allowed origins dari environment variable
func getAllowedOrigins() map[string]bool {
    origins := make(map[string]bool)
    
    // Default production origins
    productionOrigins := []string{
        "https://laporan.yourdomain.com",
        "https://admin.laporan.yourdomain.com",
    }
    
    // Override dengan environment variable jika ada
    envOrigins := os.Getenv("CORS_ALLOWED_ORIGINS")
    if envOrigins != "" {
        productionOrigins = strings.Split(envOrigins, ",")
    }
    
    for _, origin := range productionOrigins {
        origins[strings.TrimSpace(origin)] = true
    }
    
    return origins
}

var allowedOrigins = getAllowedOrigins()

func isOriginAllowed(origin string) bool {
    return allowedOrigins[origin]
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        origin := r.Header.Get("Origin")
        
        // CORS Headers - only allow specific origins
        if isOriginAllowed(origin) {
            w.Header().Set("Access-Control-Allow-Origin", origin)
            w.Header().Set("Access-Control-Allow-Credentials", "true")
        }
        
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        w.Header().Set("Access-Control-Max-Age", "86400") // Cache preflight 24 jam
        w.Header().Set("Vary", "Origin")
        
        // Security Headers
        w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self'; object-src 'none'")
        w.Header().Set("X-Content-Type-Options", "nosniff")
        w.Header().Set("X-Frame-Options", "DENY")
        w.Header().Set("X-XSS-Protection", "1; mode=block")
        w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
        w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
        
        // Handle preflight
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        
        next(w, r)
    }
}
```

### 2.4 Implementasi CORS di Node.js Services

```javascript
const cors = require('cors');

// Load allowed origins dari environment
const getAllowedOrigins = () => {
    const envOrigins = process.env.CORS_ALLOWED_ORIGINS;
    
    if (envOrigins) {
        return envOrigins.split(',').map(origin => origin.trim());
    }
    
    // Default production origins
    return [
        'https://laporan.yourdomain.com',
        'https://admin.laporan.yourdomain.com'
    ];
};

const allowedOrigins = getAllowedOrigins();

// CORS Configuration
app.use(cors({
    origin: function(origin, callback) {
        // Allow requests with no origin (mobile apps, curl, etc.)
        if (!origin) return callback(null, true);
        
        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            console.warn(`CORS blocked request from: ${origin}`);
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    exposedHeaders: ['X-Served-By'],
    maxAge: 86400 // Cache preflight 24 jam
}));

// Security Headers Middleware
app.use((req, res, next) => {
    res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; object-src 'none'");
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    next();
});
```

### 2.5 Konfigurasi CORS via Kubernetes Deployment

Tambahkan environment variable di deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-pembuat-laporan
spec:
  template:
    spec:
      containers:
      - name: service-pembuat-laporan
        image: service-pembuat-laporan:latest
        env:
        - name: CORS_ALLOWED_ORIGINS
          valueFrom:
            configMapKeyRef:
              name: cors-config
              key: allowed-origins
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cors-config
data:
  allowed-origins: "https://laporan.yourdomain.com,https://admin.laporan.yourdomain.com"
```

---

## 3. TLS/SSL Configuration

### 3.1 Opsi TLS Certificate

| Opsi | Kelebihan | Kekurangan | Use Case |
|------|-----------|------------|----------|
| **Let's Encrypt (cert-manager)** | Gratis, auto-renewal | Rate limits | Production (recommended) |
| **Cloud Provider SSL** | Managed, reliable | Berbayar | Enterprise |
| **Self-signed** | Gratis, cepat | Browser warning | Development only |
| **Purchased SSL** | Trusted, warranty | Mahal | High-security apps |

### 3.2 Production Setup dengan cert-manager (Recommended)

#### Step 1: Install cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

#### Step 2: Buat ClusterIssuer untuk Let's Encrypt

```yaml
# letsencrypt-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Email untuk notifikasi certificate expiry
    email: admin@yourdomain.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
---
# Untuk testing, gunakan staging environment
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: admin@yourdomain.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
kubectl apply -f letsencrypt-issuer.yaml
```

#### Step 3: Update Ingress untuk Auto-TLS

```yaml
# ingress-production.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laporan-api-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    # Gunakan staging dulu untuk testing
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Force HTTPS redirect
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # HSTS
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
spec:
  tls:
  - hosts:
    - api.laporan.yourdomain.com
    secretName: laporan-api-tls  # cert-manager akan buat ini otomatis
  rules:
  - host: api.laporan.yourdomain.com
    http:
      paths:
      - path: /api/warga
        pathType: Prefix
        backend:
          service:
            name: service-pembuat-laporan
            port:
              number: 8080
      - path: /api/admin
        pathType: Prefix
        backend:
          service:
            name: service-penerima-laporan
            port:
              number: 8082
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laporan-client-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - laporan.yourdomain.com
    - admin.laporan.yourdomain.com
    secretName: laporan-client-tls
  rules:
  - host: laporan.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: client-user
            port:
              number: 80
  - host: admin.laporan.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: client-admin
            port:
              number: 80
```

#### Step 4: Verify Certificate

```bash
# Cek status certificate
kubectl get certificates

# Detail certificate
kubectl describe certificate laporan-api-tls

# Cek secret TLS
kubectl get secrets | grep tls
```

### 3.3 Self-Signed Certificate (Development Only)

Untuk development/testing, gunakan self-signed certificate:

```bash
# Generate private key dan certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=localhost/O=Development"

# Buat Kubernetes secret
kubectl create secret tls tls-secret \
  --cert=tls.crt \
  --key=tls.key

# Verify
kubectl get secret tls-secret -o yaml
```

### 3.4 Cloud Provider TLS (AWS/GCP/Azure)

#### AWS - ACM (Amazon Certificate Manager)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laporan-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/xxxxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  rules:
  - host: laporan.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: client-user
            port:
              number: 80
```

#### Google Cloud - Managed Certificate

```yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: laporan-certificate
spec:
  domains:
    - laporan.yourdomain.com
    - admin.laporan.yourdomain.com
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laporan-ingress
  annotations:
    kubernetes.io/ingress.class: gce
    networking.gke.io/managed-certificates: laporan-certificate
spec:
  rules:
  - host: laporan.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: client-user
            port:
              number: 80
```

---

## 4. Kubernetes Production Setup

### 4.1 Complete Production Manifest

```yaml
# production-security.yaml
---
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: laporan-production
---
# Network Policy - Restrict pod communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: laporan-production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-services
  namespace: laporan-production
spec:
  podSelector:
    matchLabels:
      tier: backend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
---
# CORS ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: cors-config
  namespace: laporan-production
data:
  allowed-origins: "https://laporan.yourdomain.com,https://admin.laporan.yourdomain.com"
---
# JWT Secrets
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secrets
  namespace: laporan-production
type: Opaque
data:
  # Generate dengan: echo -n "your-secret" | base64
  jwt-secret: eW91ci1zZWNyZXQta2V5LWhlcmU=
  jwt-refresh-secret: eW91ci1yZWZyZXNoLXNlY3JldC1oZXJl
---
# Database Secrets
apiVersion: v1
kind: Secret
metadata:
  name: db-secrets
  namespace: laporan-production
type: Opaque
data:
  # JANGAN commit nilai asli ke git!
  postgres-password: c3VwZXItc2VjcmV0LXBhc3N3b3Jk
---
# Service Deployment dengan Security Context
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-pembuat-laporan
  namespace: laporan-production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: service-pembuat-laporan
      tier: backend
  template:
    metadata:
      labels:
        app: service-pembuat-laporan
        tier: backend
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: service-pembuat-laporan
        image: your-registry/service-pembuat-laporan:v1.0.0
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: CORS_ALLOWED_ORIGINS
          valueFrom:
            configMapKeyRef:
              name: cors-config
              key: allowed-origins
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-secrets
              key: jwt-secret
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: postgres-password
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 4.2 Production Ingress dengan Full Security

```yaml
# ingress-production-full.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laporan-production-ingress
  namespace: laporan-production
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    
    # Force HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    
    # Security Headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "DENY" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self'; object-src 'none'; frame-ancestors 'none';" always;
    
    # Rate Limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
    
    # Request Size Limit
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    
    # Timeouts
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
spec:
  tls:
  - hosts:
    - laporan.yourdomain.com
    - admin.laporan.yourdomain.com
    - api.laporan.yourdomain.com
    secretName: laporan-production-tls
  rules:
  - host: api.laporan.yourdomain.com
    http:
      paths:
      - path: /api/warga
        pathType: Prefix
        backend:
          service:
            name: service-pembuat-laporan
            port:
              number: 8080
      - path: /api/admin
        pathType: Prefix
        backend:
          service:
            name: service-penerima-laporan
            port:
              number: 8082
      - path: /auth/warga
        pathType: Prefix
        backend:
          service:
            name: service-auth-warga
            port:
              number: 8081
      - path: /auth/admin
        pathType: Prefix
        backend:
          service:
            name: service-auth-admin
            port:
              number: 8083
  - host: laporan.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: client-user
            port:
              number: 80
  - host: admin.laporan.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: client-admin
            port:
              number: 80
```

---

## 5. Monitoring & Maintenance

### 5.1 Certificate Expiry Monitoring

```bash
#!/bin/bash
# check-cert-expiry.sh

NAMESPACES="laporan-production"
WARNING_DAYS=30

for ns in $NAMESPACES; do
    for secret in $(kubectl get secrets -n $ns -o jsonpath='{.items[?(@.type=="kubernetes.io/tls")].metadata.name}'); do
        EXPIRY=$(kubectl get secret $secret -n $ns -o jsonpath='{.data.tls\.crt}' | \
                 base64 -d | \
                 openssl x509 -noout -enddate | \
                 cut -d= -f2)
        
        EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
        
        if [ $DAYS_LEFT -lt $WARNING_DAYS ]; then
            echo "⚠️ WARNING: $secret expires in $DAYS_LEFT days!"
        else
            echo "✅ $secret: $DAYS_LEFT days remaining"
        fi
    done
done
```

### 5.2 Security Headers Verification

```bash
#!/bin/bash
# verify-security-headers.sh

URL="${1:-https://laporan.yourdomain.com}"

echo "Checking security headers for: $URL"
echo "=================================="

HEADERS=$(curl -s -I "$URL" 2>/dev/null)

check_header() {
    HEADER=$1
    EXPECTED=$2
    
    VALUE=$(echo "$HEADERS" | grep -i "^$HEADER:" | cut -d: -f2- | xargs)
    
    if [ -n "$VALUE" ]; then
        if [[ "$VALUE" == *"$EXPECTED"* ]]; then
            echo "✅ $HEADER: $VALUE"
        else
            echo "⚠️ $HEADER: $VALUE (expected: $EXPECTED)"
        fi
    else
        echo "❌ $HEADER: MISSING"
    fi
}

check_header "Strict-Transport-Security" "max-age"
check_header "X-Content-Type-Options" "nosniff"
check_header "X-Frame-Options" "DENY"
check_header "X-XSS-Protection" "1"
check_header "Content-Security-Policy" "default-src"
check_header "Referrer-Policy" "strict-origin"
```

### 5.3 CORS Testing Script

```bash
#!/bin/bash
# test-cors.sh

API_URL="${1:-https://api.laporan.yourdomain.com}"
ALLOWED_ORIGIN="${2:-https://laporan.yourdomain.com}"
BLOCKED_ORIGIN="${3:-https://evil.com}"

echo "Testing CORS Configuration"
echo "=========================="

# Test allowed origin
echo -e "\n[TEST 1] Allowed Origin: $ALLOWED_ORIGIN"
RESPONSE=$(curl -s -I -H "Origin: $ALLOWED_ORIGIN" "$API_URL/api/warga/laporan" 2>/dev/null)
CORS_HEADER=$(echo "$RESPONSE" | grep -i "Access-Control-Allow-Origin" | cut -d: -f2- | xargs)

if [ "$CORS_HEADER" = "$ALLOWED_ORIGIN" ]; then
    echo "✅ PASS: CORS header correctly set to $CORS_HEADER"
else
    echo "❌ FAIL: Expected $ALLOWED_ORIGIN, got: $CORS_HEADER"
fi

# Test blocked origin
echo -e "\n[TEST 2] Blocked Origin: $BLOCKED_ORIGIN"
RESPONSE=$(curl -s -I -H "Origin: $BLOCKED_ORIGIN" "$API_URL/api/warga/laporan" 2>/dev/null)
CORS_HEADER=$(echo "$RESPONSE" | grep -i "Access-Control-Allow-Origin" | cut -d: -f2- | xargs)

if [ -z "$CORS_HEADER" ]; then
    echo "✅ PASS: No CORS header for blocked origin"
elif [ "$CORS_HEADER" = "*" ]; then
    echo "❌ FAIL: CORS allows all origins (*)"
else
    echo "❌ FAIL: CORS header present: $CORS_HEADER"
fi
```

---

## 6. Troubleshooting

### 6.1 Common Issues

#### Issue: Certificate not issued

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate status
kubectl describe certificate <cert-name>

# Check challenge status
kubectl get challenges
kubectl describe challenge <challenge-name>
```

**Solusi:**
- Pastikan DNS A record mengarah ke IP cluster
- Pastikan port 80 tidak di-block (untuk HTTP-01 challenge)
- Cek rate limit Let's Encrypt

#### Issue: CORS errors di browser

```
Access to fetch at 'https://api.example.com' from origin 'https://example.com' 
has been blocked by CORS policy
```

**Solusi:**
1. Verifikasi origin di whitelist
2. Cek credentials setting
3. Pastikan preflight (OPTIONS) handler ada

```bash
# Test preflight
curl -X OPTIONS -H "Origin: https://laporan.yourdomain.com" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type,Authorization" \
     -v https://api.laporan.yourdomain.com/api/warga/laporan
```

#### Issue: Mixed Content Warning

```
Mixed Content: The page was loaded over HTTPS, but requested 
an insecure resource
```

**Solusi:**
- Pastikan semua API calls menggunakan HTTPS
- Update BASE_URL di frontend
- Set `upgrade-insecure-requests` di CSP

### 6.2 Security Checklist

```
Pre-Production Security Checklist
=================================

[ ] TLS/SSL
    [ ] Certificate installed dan valid
    [ ] HTTPS redirect aktif
    [ ] HSTS header configured
    [ ] Certificate auto-renewal tested

[ ] CORS
    [ ] Origins restricted ke domain production
    [ ] Credentials handling configured
    [ ] Preflight caching enabled
    [ ] No wildcard (*) in production

[ ] Headers
    [ ] X-Content-Type-Options: nosniff
    [ ] X-Frame-Options: DENY
    [ ] X-XSS-Protection: 1; mode=block
    [ ] Content-Security-Policy configured
    [ ] Referrer-Policy set

[ ] Authentication
    [ ] JWT secrets unique dan strong
    [ ] Token expiry configured
    [ ] Refresh token rotation

[ ] Network
    [ ] Network policies configured
    [ ] Internal services tidak exposed
    [ ] Rate limiting enabled

[ ] Monitoring
    [ ] Certificate expiry alerts
    [ ] Error logging enabled
    [ ] Security events logged
```

---

## Quick Reference Commands

```bash
# Check TLS certificate
kubectl get certificates -A
openssl s_client -connect laporan.yourdomain.com:443 -servername laporan.yourdomain.com

# Test CORS
curl -I -H "Origin: https://laporan.yourdomain.com" https://api.laporan.yourdomain.com/api/warga/laporan

# Check security headers
curl -I https://laporan.yourdomain.com | grep -E "Strict-Transport|X-Content|X-Frame|X-XSS|Content-Security|Referrer"

# Restart services after config change
kubectl rollout restart deployment -n laporan-production

# View cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f
```

---

## Referensi

- [Mozilla Web Security Guidelines](https://infosec.mozilla.org/guidelines/web_security)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)

---

*Dokumen ini dibuat untuk Sistem Laporan Masyarakat - Tugas Besar AAT*
*Last Updated: January 2026*
