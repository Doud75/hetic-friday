// Stress test progressif - 5000 VUs max
// Lancer : k6 run load_test.js
import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  stages: [
    { duration: "15s", target: 50 },
    { duration: "1m", target: 5000 },
    { duration: "2m", target: 5000 },
    { duration: "1s", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<2000"], // 95% des requêtes < 2s
    http_req_failed: ["rate<0.05"], // Moins de 5% d'erreurs
  },
};

const BASE_URL = __ENV.BASE_URL || "http://a00d025d61513404d9e74bdb63ce78dc-b9804b293783b47b.elb.eu-central-2.amazonaws.com";

const params = {
  headers: { "Connection": "keep-alive" },
};

export default function () {
  const res = http.get(`${BASE_URL}/`, params);

  check(res, {
    "status is 200": (r) => r.status === 200,
    "response time < 2s": (r) => r.timings.duration < 2000,
  });

  sleep(1); // Pause 1s entre chaque requête par VU
}
