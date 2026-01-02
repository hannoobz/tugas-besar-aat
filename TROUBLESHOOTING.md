# Troubleshooting Guide

## Common Issues and Solutions

### 1. Cannot build Docker images

**Error**: `docker: command not found` or `Cannot connect to Docker daemon`

**Solution**:
- Make sure Docker Desktop is installed and running
- On Linux, make sure your user is in the docker group: `sudo usermod -aG docker $USER`
- Restart Docker Desktop if it's running but not responding

### 2. kubectl command not found

**Error**: `kubectl: command not found`

**Solution**:
- **macOS**: `brew install kubectl`
- **Linux**: Follow [official kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- **Windows**: Download from [official site](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
- Or use Docker Desktop's built-in kubectl

### 3. Kubernetes not enabled in Docker Desktop

**Error**: `The connection to the server localhost:8080 was refused`

**Solution**:
1. Open Docker Desktop
2. Go to Settings/Preferences
3. Click on "Kubernetes" tab
4. Check "Enable Kubernetes"
5. Click "Apply & Restart"
6. Wait for Kubernetes to start (green indicator)

### 4. Pods stuck in "Pending" state

**Error**: Pods show "Pending" status for a long time

**Solution**:
```bash
# Check pod details
kubectl describe pod <pod-name>

# Common causes:
# - Not enough resources (increase Docker memory to 4GB+)
# - Image pull errors (check if images are built)

# Fix: Increase Docker memory
# Docker Desktop > Settings > Resources > Memory (set to 4GB+)
```

### 5. Pods stuck in "ImagePullBackOff"

**Error**: Pods show "ImagePullBackOff" or "ErrImagePull"

**Solution**:
This happens when images aren't available locally. Make sure you:
1. Built all images: `./deploy.sh` does this automatically
2. Using `imagePullPolicy: Never` in k8s-all-in-one.yaml (already set)

### 6. Database connection refused

**Error**: Backend services can't connect to PostgreSQL

**Solution**:
```bash
# Check if postgres pod is running
kubectl get pods -l app=postgres

# If not running, check logs
kubectl logs -l app=postgres

# Check if postgres service exists
kubectl get service postgres

# If missing, re-apply manifests
kubectl apply -f k8s-all-in-one.yaml
```

### 7. Frontend can't reach backend

**Error**: Frontend shows "Failed to fetch" or CORS errors

**Solution**:
1. Check if backend services are running:
   ```bash
   kubectl get pods
   ```

2. Check backend service endpoints:
   ```bash
   kubectl get endpoints
   ```

3. For local development, the frontend uses service names:
   - `http://service-pembuat-laporan:8080`
   - `http://service-penerima-laporan:3000`

4. If testing in browser directly (not through NodePort), you may need to port-forward:
   ```bash
   kubectl port-forward service/service-pembuat-laporan 8080:8080
   kubectl port-forward service/service-penerima-laporan 3000:3000
   ```

### 8. NodePort not accessible

**Error**: Cannot access http://localhost:30080 or http://localhost:30081

**Solution**:
1. Check if services are created:
   ```bash
   kubectl get services
   ```

2. Verify NodePort assignments:
   ```bash
   kubectl get service client-user -o yaml
   kubectl get service client-admin -o yaml
   ```

3. Check if pods are running:
   ```bash
   kubectl get pods -l app=client-user
   kubectl get pods -l app=client-admin
   ```

4. Try accessing through port-forward:
   ```bash
   kubectl port-forward service/client-user 8081:80
   # Then access http://localhost:8081
   ```

### 9. Deployment fails with "field is immutable"

**Error**: Can't update deployment, field is immutable

**Solution**:
```bash
# Delete existing deployment first
kubectl delete -f k8s-all-in-one.yaml

# Then re-apply
kubectl apply -f k8s-all-in-one.yaml
```

### 10. Out of disk space

**Error**: `no space left on device`

**Solution**:
```bash
# Clean up unused Docker images
docker system prune -a

# Clean up unused volumes
docker volume prune
```

## Debugging Commands

### View Pod Details
```bash
# List all pods
kubectl get pods

# Describe specific pod (shows events and errors)
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# View logs for all pods with a label
kubectl logs -l app=service-pembuat-laporan

# Follow logs in real-time
kubectl logs -f <pod-name>
```

### View Service Details
```bash
# List all services
kubectl get services

# Describe specific service
kubectl describe service <service-name>

# View service endpoints
kubectl get endpoints
```

### Check Resource Usage
```bash
# View node resources
kubectl top nodes

# View pod resources (requires metrics-server)
kubectl top pods
```

### Port Forwarding for Testing
```bash
# Forward database port
kubectl port-forward service/postgres 5432:5432

# Forward Go service
kubectl port-forward service/service-pembuat-laporan 8080:8080

# Forward Node service
kubectl port-forward service/service-penerima-laporan 3000:3000

# Forward frontend (alternative to NodePort)
kubectl port-forward service/client-user 8081:80
```

### Execute Commands in Pods
```bash
# Get shell in postgres pod
kubectl exec -it <postgres-pod-name> -- /bin/sh

# Run psql in postgres pod
kubectl exec -it <postgres-pod-name> -- psql -U postgres -d laporandb

# Get shell in Go service pod
kubectl exec -it <go-pod-name> -- /bin/sh
```

## Complete Reset

If nothing works, try a complete reset:

```bash
# 1. Delete all Kubernetes resources
kubectl delete -f k8s-all-in-one.yaml

# 2. Wait for everything to be deleted
kubectl get all

# 3. Delete all Docker images
docker rmi service-pembuat-laporan:latest
docker rmi service-penerima-laporan:latest
docker rmi client-user:latest
docker rmi client-admin:latest

# 4. Clean Docker system
docker system prune -a

# 5. Restart Docker Desktop

# 6. Re-deploy
./deploy.sh
```

## Getting Help

If you're still stuck:

1. **Check pod logs**: They usually contain the exact error
   ```bash
   kubectl logs <pod-name>
   ```

2. **Check pod events**: Shows what Kubernetes is trying to do
   ```bash
   kubectl describe pod <pod-name>
   ```

3. **Check all events**: Shows cluster-wide events
   ```bash
   kubectl get events --sort-by='.lastTimestamp'
   ```

4. **Verify Kubernetes is running**:
   ```bash
   kubectl cluster-info
   ```

## Prevention Tips

1. **Always wait for pods to be ready** before accessing services
2. **Build images before deploying** (deploy.sh does this automatically)
3. **Allocate enough resources** to Docker Desktop (4GB+ RAM)
4. **Use the provided scripts** (deploy.sh, cleanup.sh) to avoid mistakes
5. **Check logs immediately** if something doesn't work

---

**Most issues are solved by**:
1. Checking if Docker is running
2. Checking if Kubernetes is enabled
3. Checking pod logs
4. Allocating more resources to Docker Desktop
