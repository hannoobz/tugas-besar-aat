import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Get Minikube IP from environment variable
const MINIKUBE_IP = __ENV.MINIKUBE_IP || '192.168.49.2';
const API_URL = `http://${MINIKUBE_IP}:30082`;

export const options = {
  stages: [
    // Ramp up to 50 users over 1 minute
    { duration: '1m', target: 50 },
    
    // Stay at 50 users for 2 minutes (high load to trigger scale-up)
    { duration: '2m', target: 50 },
    
    // Spike to 100 users for 30 seconds
    { duration: '30s', target: 100 },
    
    // Stay at 100 users for 1 minute
    { duration: '1m', target: 100 },
    
    // Ramp down to 20 users over 1 minute
    { duration: '1m', target: 20 },
    
    // Stay at 20 users for 2 minutes (low load to trigger scale-down)
    { duration: '2m', target: 20 },
    
    // Ramp down to 0
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    errors: ['rate<0.1'], // Error rate should be below 10%
  },
};

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
  
  return {
    title: titles[Math.floor(Math.random() * titles.length)],
    description: descriptions[Math.floor(Math.random() * descriptions.length)],
  };
}

export default function () {
  const payload = JSON.stringify(generateReport());
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const response = http.post(`${API_URL}/laporan`, payload, params);
  
  // Check if request was successful
  const success = check(response, {
    'status is 201': (r) => r.status === 201,
    'response has id': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.id !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  errorRate.add(!success);
  
  // Random sleep between requests (0.5 to 1.5 seconds)
  sleep(Math.random() * 1 + 0.5);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'load-test-results.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(data, options) {
  const indent = options?.indent || '';
  const enableColors = options?.enableColors || false;
  
  let output = '\n';
  output += indent + '=====================================\n';
  output += indent + '  K6 Load Test Results\n';
  output += indent + '=====================================\n\n';
  
  output += indent + `Total Requests: ${data.metrics.http_reqs.values.count}\n`;
  output += indent + `Failed Requests: ${data.metrics.http_req_failed.values.passes || 0}\n`;
  output += indent + `Request Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)} req/s\n`;
  output += indent + `Duration: ${(data.state.testRunDurationMs / 1000).toFixed(2)}s\n\n`;
  
  output += indent + 'Response Times:\n';
  output += indent + `  Avg: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  output += indent + `  Min: ${data.metrics.http_req_duration.values.min.toFixed(2)}ms\n`;
  output += indent + `  Max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms\n`;
  output += indent + `  P95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  output += indent + `  P99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n\n`;
  
  output += indent + '=====================================\n';
  
  return output;
}
