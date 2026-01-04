import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';
import { SharedArray } from 'k6/data';

// Custom metrics
const errorRate = new Rate('errors');
const loginErrorRate = new Rate('login_errors');

// Get environment variables
const MINIKUBE_IP = __ENV.MINIKUBE_IP || '192.168.49.2';
const AUTH_API_URL = `http://${MINIKUBE_IP}:30084`;
const REPORT_API_URL = `http://${MINIKUBE_IP}:30082`;

// Base credentials - each VU will get unique NIK
const BASE_NIK = '1234567890000000'; // Will increment last digits for each VU
const TEST_PASSWORD = 'LoadTest@123';

export const options = {
  stages: [
    // Instant brutal spike to maximum load
    { duration: '5s', target: 100 },
    
    // Sustain MAXIMUM load for 45 seconds (force instant scaling)
    { duration: '45s', target: 100 },
    
    // Instant drop to observe scale-down
    { duration: '5s', target: 10 },
    
    // Brief cooldown
    { duration: '5s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // Allow higher latency due to extreme load + auth
    errors: ['rate<0.4'], // Allow higher error rate due to extreme stress
    login_errors: ['rate<0.1'], // Login should be more reliable
  },
};

// Cache for access tokens and NIK (per VU)
let accessToken = null;
let userNIK = null;

// Generate unique NIK for this VU
function getVuNIK() {
  if (!userNIK) {
    // Use __VU to get unique VU number (1-100)
    const vuNumber = __VU;
    // Pad to 3 digits: 001, 002, etc.
    const paddedVU = String(vuNumber).padStart(3, '0');
    // Create unique 16-digit NIK: 1234567890000001, 1234567890000002, etc.
    userNIK = `1234567890${paddedVU}000`.substring(0, 16);
  }
  return userNIK;
}

// Register user (auto-register if not exists)
function registerUser(nik) {
  const registerPayload = JSON.stringify({
    nik: nik,
    nama: `Load Test User ${__VU}`,
    email: `loadtest${__VU}@example.com`,
    password: TEST_PASSWORD,
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  // Try to register (will fail if user exists, that's OK)
  http.post(`${AUTH_API_URL}/auth/register`, registerPayload, params);
}

// Login function to get access token
function login() {
  const nik = getVuNIK();
  
  // First, try to register (in case user doesn't exist)
  registerUser(nik);
  
  // Then login
  const loginPayload = JSON.stringify({
    nik: nik,
    password: TEST_PASSWORD,
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const response = http.post(`${AUTH_API_URL}/auth/login`, loginPayload, params);
  
  const success = check(response, {
    'login status is 200': (r) => r.status === 200,
    'login response has token': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.accessToken !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  loginErrorRate.add(!success);
  
  if (success) {
    try {
      const body = JSON.parse(response.body);
      return body.accessToken;
    } catch (e) {
      return null;
    }
  }
  
  return null;
}

// Generate random report data
function generateReport() {
  const titles = [
    'Jalan rusak di area perumahan',
    'Lampu jalan mati',
    'Sampah menumpuk',
    'Drainase tersumbat',
    'Fasilitas umum rusak',
    'Pohon tumbang',
    'Lubang besar di jalan',
    'Kebocoran pipa air',
  ];
  
  const descriptions = [
    'Mohon segera diperbaiki karena membahayakan pengguna jalan',
    'Sudah berhari-hari tidak berfungsi dengan baik',
    'Mengganggu aktivitas warga sekitar',
    'Perlu perhatian khusus dari pihak terkait',
    'Kondisi semakin parah dan perlu penanganan cepat',
  ];

  const tipes = ['publik'];
  const divisis = ['kebersihan', 'kesehatan', 'fasilitas umum', 'kriminalitas'];
  
  return {
    title: titles[Math.floor(Math.random() * titles.length)],
    description: descriptions[Math.floor(Math.random() * descriptions.length)],
    tipe: tipes[Math.floor(Math.random() * tipes.length)],
    divisi: divisis[Math.floor(Math.random() * divisis.length)],
  };
}

export default function () {
  // Get or refresh access token if not available
  if (!accessToken) {
    accessToken = login();
    if (!accessToken) {
      // If login fails, skip this iteration
      return;
    }
  }
  
  // Create report with authentication
  const payload = JSON.stringify(generateReport());
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    },
  };
  
  const response = http.post(`${REPORT_API_URL}/laporan`, payload, params);
  
  // Check if request was successful
  const success = check(response, {
    'report status is 201': (r) => r.status === 201,
    'response has id': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.id !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  // If we get 401, token might have expired, clear it
  if (response.status === 401) {
    accessToken = null;
  }
  
  errorRate.add(!success);
}

export function handleSummary(data) {
  return {
    'load-test-results.json': JSON.stringify(data, null, 2),
  };
}
