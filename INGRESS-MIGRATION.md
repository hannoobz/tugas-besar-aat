# Migration to Ingress - Architecture Update

## Summary of Changes

The system has been migrated from NodePort-based access to **NGINX Ingress Controller** with path-based routing.

### Old Architecture (NodePort)
- User Portal: `http://localhost:30080`
- Admin Portal: `http://localhost:30081`
- User Report API: `http://localhost:30082`
- Admin API: `http://localhost:30083`
- User Auth API: `http://localhost:30084`
- Admin Auth API: `http://localhost:30085`

### New Architecture (Ingress)
- User Portal: `http://localhost/user`
- Admin Portal: `http://localhost/admin`
- User Auth API: `http://localhost/api/warga/auth/*`
- User Report API: `http://localhost/api/warga/laporan`
- Admin Auth API: `http://localhost/api/admin/auth/*`
- Admin Report API: `http://localhost/api/admin/laporan`

## Benefits of Ingress

1. **Clean URLs**: No port numbers, path-based routing
2. **Single Entry Point**: All traffic through one gateway
3. **Production Ready**: Industry standard pattern
4. **SSL/TLS Ready**: Easy to add HTTPS with cert-manager
5. **Advanced Routing**: Path rewrites, host-based routing, etc.

## Ingress Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laporan-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: $1
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      # User frontend
      - path: /user(.*)
        pathType: Prefix
        backend:
          service:
            name: client-user
            port:
              number: 80
      
      # Admin frontend
      - path: /admin(.*)
        pathType: Prefix
        backend:
          service:
            name: client-admin
            port:
              number: 80
      
      # User Auth API
      - path: /api/warga(/auth.*)
        pathType: Prefix
        backend:
          service:
            name: service-auth-warga
            port:
              number: 8080
      
      # User Report API
      - path: /api/warga(/laporan.*)
        pathType: Prefix
        backend:
          service:
            name: service-pembuat-laporan
            port:
              number: 8080
      
      # Admin Auth API
      - path: /api/admin(/auth.*)
        pathType: Prefix
        backend:
          service:
            name: service-auth-admin
            port:
              number: 3000
      
      # Admin Report API
      - path: /api/admin(/laporan.*)
        pathType: Prefix
        backend:
          service:
            name: service-penerima-laporan
            port:
              number: 3000
```

## Installation

NGINX Ingress Controller must be installed before deploying:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

## NodePort Services

NodePort services (30080-30085) still exist but are **deprecated**. They are kept for backward compatibility but should not be used. All access should go through Ingress.

## Documentation Updated

- ✅ README.md - Updated with Ingress URLs and installation steps
- ✅ deploy.sh - Updated access URLs in completion message
- ✅ get-urls.sh - Updated to show Ingress URLs
- ✅ check-status.sh - Updated access URLs
- ✅ QUICKSTART.md - Updated with Ingress setup and testing
- ✅ AUTH_IMPLEMENTATION.md - Updated all endpoints and testing examples
- ⚠️ ARCHITECTURE.md - Contains ASCII diagrams showing NodePort (for reference only)
- ⚠️ LOAD-TESTING.md - May still reference old port-based URLs

## Testing

All functionality has been tested and verified working:
- ✅ User registration and login (NIK-based)
- ✅ Admin registration and login
- ✅ Report creation via authenticated session
- ✅ Report management in admin dashboard
- ✅ JWT token refresh mechanism
- ✅ All pods running healthy
- ✅ Ingress routing correctly

Test credentials:
- User: NIK=1234567890123456, password=Test@123
- Admin: username=admin, password=Admin@123
