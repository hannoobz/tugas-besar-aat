# Authentication Implementation Summary

## Overview
Sistem autentikasi telah diimplementasikan dengan fitur:
- ✅ Login dan registrasi untuk Admin dan User
- ✅ JWT access token (15 menit expiry)
- ✅ Refresh token mechanism (7 hari expiry)
- ✅ Password requirements enforcement
- ✅ Database autentikasi terpisah dari database laporan
- ✅ Role-based access control (Admin vs User)

## Architecture

### Databases
1. **postgres** (port 5432) - Laporan Database
   - Database: `laporandb`
   - Tables: `laporan`
   
2. **postgres-auth** (port 5432) - Authentication Database
   - Database: `authdb`
   - Tables: `users`, `refresh_tokens`

### Services

#### Service Auth Warga (Go) - `/api/warga/auth/*`
**Role: User Authentication**
- Endpoints:
  - `POST /api/warga/auth/register` - Register new user (NIK-based)
  - `POST /api/warga/auth/login` - User login
  - `POST /api/warga/auth/refresh` - Refresh access token
  - `POST /api/warga/auth/logout` - Logout (revoke refresh token)
  - `GET /api/warga/auth/health` - Health check

#### Service Pembuat Laporan (Go) - `/api/warga/laporan`
**Role: Report Creation**
- Endpoints:
  - `POST /api/warga/laporan` - Create report (protected, user only)

#### Service Auth Admin (Node.js) - `/api/admin/auth/*`
**Role: Admin Authentication**
- Endpoints:
  - `POST /api/admin/auth/register` - Register new admin
  - `POST /api/admin/auth/login` - Admin login
  - `POST /api/admin/auth/refresh` - Refresh access token
  - `POST /api/admin/auth/logout` - Logout (revoke refresh token)
  - `GET /api/admin/auth/health` - Health check

#### Service Penerima Laporan (Node.js) - `/api/admin/laporan`
**Role: Report Management**
- Endpoints:
  - `GET /api/admin/laporan` - Get all reports (protected, admin only)
  - `PUT /api/admin/laporan/:id/status` - Update report status (protected, admin only)

### Frontend

#### Client User (`http://localhost/user`)
- `login.html` - User login page
- `register.html` - User registration page (NIK-based)
- `index.html` - Report creation form (protected)

#### Client Admin (`http://localhost/admin`)
- `login.html` - Admin login page
- `register.html` - Admin registration page
- `index.html` - Admin dashboard (protected)

## Password Requirements
Passwords must meet the following criteria:
- ✅ Minimum 8 characters
- ✅ At least one uppercase letter (A-Z)
- ✅ At least one lowercase letter (a-z)
- ✅ At least one number (0-9)
- ✅ At least one special character (@$!%*?&)

## JWT Configuration
Environment variables (configured in k8s ConfigMap):
```
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_REFRESH_SECRET=your-super-secret-refresh-key-change-this-in-production
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d
```

## Database Schema

### users table
```sql
id SERIAL PRIMARY KEY
username VARCHAR(100) UNIQUE NOT NULL
email VARCHAR(255) UNIQUE NOT NULL
password_hash VARCHAR(255) NOT NULL
role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'admin'))
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
```

### refresh_tokens table
```sql
id SERIAL PRIMARY KEY
user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
token VARCHAR(500) UNIQUE NOT NULL
expires_at TIMESTAMP NOT NULL
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
revoked BOOLEAN DEFAULT FALSE
```

## Deployment Steps

### 1. Install NGINX Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 2. Build Docker Images
```bash
# Build service-auth-warga (Go)
cd service-auth-warga
docker build -t service-auth-warga:latest .

# Build service-auth-admin (Node.js)
cd ../service-auth-admin
docker build -t service-auth-admin:latest .

# Build service-pembuat-laporan (Go)
cd ../service-pembuat-laporan
docker build -t service-pembuat-laporan:latest .

# Build service-penerima-laporan (Node.js)
cd ../service-penerima-laporan
docker build -t service-penerima-laporan:latest .

# Build client-user
cd ../client-user
docker build -t client-user:latest .

# Build client-admin
cd ../client-admin
docker build -t client-admin:latest .
```

### 3. Deploy to Kubernetes
```bash
kubectl apply -f k8s-all-in-one.yaml
```

### 4. Verify Deployment
```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get services

# Check Ingress
kubectl get ingress
kubectl describe ingress laporan-ingress
```

### 5. Access URLs
All services accessible via Ingress at `http://localhost`:

**Frontend:**
- User Portal: `http://localhost/user`
- Admin Dashboard: `http://localhost/admin`

**API Endpoints:**
- User Auth: `http://localhost/api/warga/auth/*`
- User Reports: `http://localhost/api/warga/laporan`
- Admin Auth: `http://localhost/api/admin/auth/*`
- Admin Reports: `http://localhost/api/admin/laporan`

## Testing Flow

### Test User Flow
1. Navigate to `http://localhost/user/register.html`
2. Register with:
   - NIK: `1234567890123456` (16 digits, required for users)
   - Nama Lengkap: `Test User`
   - Email: `testuser@example.com`
   - Password: `User@123` (meets all requirements)
3. Login at `http://localhost/user/login.html`
4. Create a report at `http://localhost/user/index.html`

### Test Admin Flow
1. Navigate to `http://localhost/admin/register.html`
2. Register with:
   - Username: `testadmin`
   - Email: `admin@example.com`
   - Password: `Admin@123` (meets all requirements)
3. Login at `http://localhost/admin/login.html`
4. View and manage reports at `http://localhost/admin/index.html`

### Test Authentication
1. Try accessing protected routes without token (should redirect to login)
2. Login and verify access token is stored in localStorage
3. Wait 15 minutes for access token to expire
4. Make a request - should auto-refresh using refresh token
5. Logout and verify tokens are cleared

## API Testing with curl

### Register User (NIK-based)
```bash
curl -X POST http://localhost/api/warga/auth/register \
  -H "Content-Type: application/json" \
  -d '{"nik":"1234567890123456","nama_lengkap":"Test User","email":"test@example.com","password":"User@123"}'
```

### Login User
```bash
curl -X POST http://localhost/api/warga/auth/login \
  -H "Content-Type: application/json" \
  -d '{"nik":"1234567890123456","password":"User@123"}'
```

### Create Report (with token)
```bash
curl -X POST http://localhost/api/warga/laporan \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -d '{"title":"Test Report","description":"This is a test"}'
```

### Register Admin
```bash
curl -X POST http://localhost/api/admin/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","email":"admin@example.com","password":"Admin@123"}'
```

### Login Admin
```bash
curl -X POST http://localhost/api/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'
```

### Get All Reports (with admin token)
```bash
curl http://localhost/api/admin/laporan \
  -H "Authorization: Bearer <ADMIN_ACCESS_TOKEN>"
```

### Update Report Status (with admin token)
```bash
curl -X PUT http://localhost/api/admin/laporan/1/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ADMIN_ACCESS_TOKEN>" \
  -d '{"status":"completed"}'
```

## Security Features

### Implemented
- ✅ Password hashing with bcrypt (10 salt rounds)
- ✅ JWT token-based authentication
- ✅ Refresh token mechanism
- ✅ Token expiration (15m access, 7d refresh)
- ✅ Token revocation on logout
- ✅ Role-based access control
- ✅ Password complexity requirements
- ✅ Email format validation
- ✅ Duplicate username/email check

### Production Recommendations
- ⚠️ Change JWT secrets in production (use Kubernetes Secrets)
- ⚠️ Enable HTTPS/TLS
- ⚠️ Rate limiting on auth endpoints
- ⚠️ Account lockout after failed login attempts
- ⚠️ Email verification for registration
- ⚠️ Password reset functionality
- ⚠️ Audit logging for security events

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <POD_NAME>
kubectl logs <POD_NAME>
```

### Database connection issues
```bash
# Check postgres pods
kubectl get pods | grep postgres

# Check database logs
kubectl logs postgres-<POD_ID>
kubectl logs postgres-auth-<POD_ID>
```

### Auth not working
1. Check JWT secrets are properly configured
2. Verify database schema is created (check auth database)
3. Check service logs for errors
4. Verify environment variables are set correctly

### CORS issues
- Both services have CORS enabled with wildcard `*`
- If still encountering issues, check browser console
- Verify Authorization header is being sent

## Files Modified/Created

### New Files
- `db/init-auth.sql` - Auth database initialization
- `client-admin/login.html` - Admin login page
- `client-admin/register.html` - Admin registration page
- `client-user/login.html` - User login page
- `client-user/register.html` - User registration page
- `AUTH_IMPLEMENTATION.md` - This documentation

### Modified Files
- `k8s-all-in-one.yaml` - Added auth database, ConfigMaps for JWT
- `service-penerima-laporan/index.js` - Added auth endpoints & middleware
- `service-penerima-laporan/package.json` - Added bcrypt, jsonwebtoken
- `service-pembuat-laporan/main.go` - Added auth endpoints & middleware
- `service-pembuat-laporan/go.mod` - Added JWT and crypto packages
- `client-admin/index.html` - Added auth check, logout, token handling
- `client-user/index.html` - Added auth check, logout, token handling

## Next Steps
1. Deploy using `./deploy.sh`
2. Test registration and login for both user and admin
3. Test report creation with user authentication
4. Test report management with admin authentication
5. Test token refresh mechanism
6. Consider implementing additional security features for production
