Act as a Senior Developer helping me with a university assignment POC.

I have attached a design document ("Laporan Tubes AAT") for context regarding the domain (e.g., what a "Laporan" is), but **please IGNORE the complex architecture (Kafka, CDC, Auth) described in the PDF.**

**Strictly follow MY simplified requirements below.** I only need a working Proof of Concept that demonstrates **Reliability** and **Scalability** using Kubernetes.

### The Requirement:
Implement 5 distinct components orchestrated by Kubernetes. The system must allow creating reports (User side) and updating them (Admin side) without any authentication.

### 1. The Components

1.  **Postgres DB:**
    * Create a K8s Deployment and Service.
    * Include a `ConfigMap` for DB credentials.
    * **Schema:** A simple `laporan` table (id, title, description, status).

2.  **Service Pembuat Laporan (Backend - Golang):**
    * **Role:** Handles high-traffic report creation (`POST /laporan`).
    * **Logic:** Connects directly to Postgres.
    * **Mandatory Comment:** Add "Code generated with the assistance of Claude Sonnet for implementation logic" at the top.

3.  **Service Penerima Laporan (Backend - NodeJS):**
    * **Role:** Handles admin updates (`GET /laporan` and `PUT /laporan/:id/status`).
    * **Logic:** Connects directly to Postgres.
    * **Reliability:** Ensure this is a separate Deployment so if it crashes, the Go service stays alive.
    * **Mandatory Comment:** Add "Code generated with the assistance of Claude Sonnet for implementation logic" at the top.

4.  **Client User (Frontend):**
    * A simple HTML/JS or React app.
    * Contains a form to submit a report to the **Go Service**.

5.  **Client Admin (Frontend):**
    * A simple HTML/JS or React app.
    * Displays a list of reports and buttons to change status via the **Node Service**.

### 2. Orchestration (Kubernetes)

Generate the `Dockerfile` for each app and a single `k8s-all-in-one.yaml` that includes:
* **Deployments:** One for each of the 5 components.
* **Scalability:** Set `replicas: 3` specifically for the **Service Pembuat Laporan (Go)** to demonstrate scaling.
* **Services:** Define strict Service discovery (ClusterIP for backends, NodePort/LoadBalancer for frontends).
* **Env Variables:** Ensure the apps know how to find the DB inside the cluster (e.g., using the K8s Service name `postgres`).

**Focus:** Keep the code simple (no Auth, no Kafka). Focus on the K8s configuration to ensure I can run `kubectl apply -f ...` and immediately demo that the User side works even if the Admin side is deleted.