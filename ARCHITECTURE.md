# System Architecture

## High-Level Architecture Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                        KUBERNETES CLUSTER                      │
│                                                                │
│  ┌────────────────────────────────────────────────────────────┐│
│  │                      ConfigMap                             ││
│  │  DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME           ││
│  └────────────────────────────────────────────────────────────┘│
│                                                                │
│  ┌──────────────────┐      ┌───────────────────────────────┐   │
│  │   PostgreSQL DB  │      │  Service Pembuat Laporan      │   │
│  │   (1 replica)    │◄─────┤  (Golang - 3 replicas)        │   │
│  │                  │      │  ┌─────┐ ┌─────┐ ┌─────┐      │   │
│  │  ClusterIP       │      │  │ Pod │ │ Pod │ │ Pod │      │   │
│  │  postgres:5432   │      │  └─────┘ └─────┘ └─────┘      │   │
│  └──────────────────┘      │  ClusterIP :8080              │   │
│           ▲                └───────────────────────────────┘   │
│           │                             ▲                      │
│           │                             │                      │
│           │                 ┌───────────┴────────────┐         │
│           │                 │                        │         │
│  ┌────────┴──────────┐      │                        │         │
│  │ Service Penerima  │──────┘                        │         │
│  │   Laporan         │                               │         │
│  │ (Node.js - 1 rep) │                               │         │
│  │ ClusterIP :3000   │                               │         │
│  └───────────────────┘                               │         │
│           ▲                                          │         │
│           │                                          │         │
│  ┌────────┴────────┐                     ┌───────────┴──────┐  │
│  │  Client Admin   │                     │   Client User    │  │
│  │  (1 replica)    │                     │   (1 replica)    │  │
│  │  NodePort:30081 │                     │   NodePort:30080 │  │
│  └─────────────────┘                     └──────────────────┘  │
│           ▲                                           ▲        │
└───────────┼───────────────────────────────────────────┼────────┘
            │                                           │
            │                                           │
     ┌──────┴─────────┐                      ┌──────────┴───────┐
     │ Admin Browser  │                      │  User Browser    │
     │ :30081         │                      │  :30080          │
     └────────────────┘                      └──────────────────┘
```

## Data Flow

### User Creates Report (Write Path)

```
User Browser (localhost:30080)
    │
    │ HTTP POST /laporan
    ├─► NodePort Service (30080)
    │
    ├─► Client User Pod (Nginx)
    │       │
    │       │ Serve HTML/JS
    │       │
    │       ▼
    │   Browser makes API call
    │
    ├─► Service Pembuat Laporan ClusterIP (:8080)
    │       │
    │       │ Load balances across 3 pods
    │       │
    │       ├─► Pod 1 (Golang) ──┐
    │       ├─► Pod 2 (Golang) ──┼─► PostgreSQL (:5432)
    │       └─► Pod 3 (Golang) ──┘    INSERT laporan
    │
    └─► Response: { id, title, description, status }
```

### Admin Views/Updates Reports (Read/Update Path)

```
Admin Browser (localhost:30081)
    │
    │ HTTP GET /laporan
    │ HTTP PUT /laporan/:id/status
    │
    ├─► NodePort Service (30081)
    │
    ├─► Client Admin Pod (Nginx)
    │       │
    │       │ Serve HTML/JS
    │       │
    │       ▼
    │   Browser makes API call
    │
    ├─► Service Penerima Laporan ClusterIP (:3000)
    │       │
    │       └─► Pod (Node.js) ──► PostgreSQL (:5432)
    │                              SELECT/UPDATE laporan
    │
    └─► Response: [{ laporan objects }]
```

## Component Responsibilities

### 1. PostgreSQL Database
- **Role**: Persistent data storage
- **Replicas**: 1
- **Service Type**: ClusterIP (internal only)
- **Initialization**: Runs init.sql on first start
- **Data**: laporan table with id, title, description, status

### 2. Service Pembuat Laporan (Golang)
- **Role**: Handle high-traffic report creation
- **Replicas**: 3 (demonstrates scalability)
- **Service Type**: ClusterIP (internal only)
- **Endpoint**: POST /laporan
- **Features**: 
  - Validates input (title, description required)
  - Inserts into PostgreSQL
  - Returns created report with ID
- **Scalability**: Load balanced across 3 pods

### 3. Service Penerima Laporan (Node.js)
- **Role**: Admin operations (view, update status)
- **Replicas**: 1
- **Service Type**: ClusterIP (internal only)
- **Endpoints**: 
  - GET /laporan (list all reports)
  - PUT /laporan/:id/status (update status)
- **Features**:
  - Status validation
  - Timestamp updates
  - Full CRUD operations

### 4. Client User (Frontend)
- **Role**: User interface for creating reports
- **Replicas**: 1
- **Service Type**: NodePort (external access)
- **Port**: 30080
- **Tech**: Static HTML/JS/CSS served by Nginx
- **Features**:
  - Form validation
  - API integration
  - Success/error messaging

### 5. Client Admin (Frontend)
- **Role**: Admin dashboard for managing reports
- **Replicas**: 1
- **Service Type**: NodePort (external access)
- **Port**: 30081
- **Tech**: Static HTML/JS/CSS served by Nginx
- **Features**:
  - Real-time report listing
  - Status update buttons
  - Statistics dashboard
  - Auto-refresh every 10s

## Service Discovery

All services communicate using Kubernetes DNS:
- Backend services use ClusterIP service names:
  - `postgres:5432`
  - `service-pembuat-laporan:8080`
  - `service-penerima-laporan:3000`
- Frontend services exposed via NodePort for external access

## Configuration Management

### ConfigMap: db-config
```yaml
DB_HOST: "postgres"        # Service name
DB_PORT: "5432"
DB_USER: "postgres"
DB_PASSWORD: "postgres"    # In production, use Secrets
DB_NAME: "laporandb"
```

All backend services read from this ConfigMap, ensuring:
- Centralized configuration
- Easy updates (change once, affects all)
- No hardcoded values in code

## Reliability Features

1. **Service Isolation**: 
   - User service (Go) separate from Admin service (Node.js)
   - If one crashes, other continues working

2. **Auto-Healing**:
   - Kubernetes automatically restarts failed pods
   - Deployment maintains desired replica count

3. **Health Checks**:
   - Liveness probes: Restart pod if unhealthy
   - Readiness probes: Remove pod from load balancer if not ready

4. **Graceful Degradation**:
   - 3 Go replicas: if 1 fails, 2 continue serving
   - Database issues don't crash application pods

## Scalability Features

1. **Horizontal Scaling**:
   - Go service scaled to 3 replicas
   - Can easily scale up/down: `kubectl scale deployment service-pembuat-laporan --replicas=5`

2. **Load Balancing**:
   - ClusterIP service distributes traffic evenly
   - Round-robin across healthy pods

3. **Stateless Design**:
   - No session state in backends
   - All state in PostgreSQL
   - Easy to add more replicas

4. **Resource Isolation**:
   - Each component in its own pod
   - Can allocate resources independently

## Network Policy

```
External → NodePort → ClusterIP → Pods
  (User)     (LB)      (Service)   (App)
```

- **NodePort**: Entry point for external traffic (30080, 30081)
- **ClusterIP**: Internal load balancer (postgres, backends)
- **Pod Network**: Direct pod-to-pod communication
