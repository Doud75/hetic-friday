// Stress test progressif pour 90k connexions simultanées
// Lancer : k6 run load_test.js
import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  stages: [
    { duration: "3m", target: 5000 }, // Stress: 10000 → 20000 VUs (pic)
    { duration: "3m", target: 5000 }, // Sustain: maintien à 10000 VUs
    { duration: "1m", target: 0 }, // Shutdown: 2000 → 0 VUs
  ],
  thresholds: {
    http_req_duration: ["p(95)<2000"], // 95% des requêtes < 2s
    http_req_failed: ["rate<0.05"], // Moins de 5% d'erreurs
  },
};

export default function () {
  const url =
    "http://a486a408bf1ad4a58a941652f5c7d993-1321088097.eu-central-1.elb.amazonaws.com/";

  const res = http.get(url);

  check(res, {
    "status is 200": (r) => r.status === 200,
    "response time < 2s": (r) => r.timings.duration < 2000,
  });

  sleep(1); // Pause 1s entre chaque requête par VU
}
