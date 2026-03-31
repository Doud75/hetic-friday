import http from "k6/http";
import { sleep, check, group } from "k6";

export const options = {
  stages: [
    // 1. Échauffement (Warm-up) : On vérifie que tout va bien
    { duration: '2m', target: 2000 },  
    { duration: '3m', target: 2000 },  // On stabilise : l'ASG devrait commencer à voir le CPU monter

    // 2. Premier palier sérieux : On force le scaling
    { duration: '5m', target: 15000 }, 
    { duration: '5m', target: 15000 }, // On attend 5min : les nouvelles EC2 arrivent ici

    // 3. Accélération
    { duration: '5m', target: 40000 }, 
    { duration: '5m', target: 40000 }, // Stabilisation

    // 4. Vers l'objectif final
    { duration: '5m', target: 70000 },
    { duration: '5m', target: 70000 },

    // 5. Le "Peak" à 90k
    { duration: '5m', target: 90000 },
    { duration: '10m', target: 90000 }, // On maintient le stress maximum

    // 6. Redescente
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = "http://hetic-friday-prod-alb-1663745015.eu-central-1.elb.amazonaws.com";
const params = {
  headers: { "Connection": "keep-alive" },
};
export default function () {
  // 1. Page d'accueil
  group("01_Home_Page", function () {
    const res = http.get(`${BASE_URL}/`, params);
    check(res, {
      "home status is 200": (r) => r.status === 200,
    });
  });

  sleep(Math.random() * 2 + 1); // Temps de réflexion aléatoire (1-3s)

  // 2. Page Produit
  group("02_Product_Page", function () {
    const res = http.get(`${BASE_URL}/product/OLJCESPC7Z`, params);
    check(res, {
      "product status is 200": (r) => r.status === 200,
      "product loaded quickly": (r) => r.timings.duration < 2000,
    });
  });

  sleep(Math.random() * 2 + 1);

  // 3. Page Panier
  group("03_Cart_Page", function () {
    const res = http.get(`${BASE_URL}/cart`, params);
    check(res, {
      "cart status is 200": (r) => r.status === 200,
    });
  });

  sleep(Math.random() * 3 + 2); // Pause plus longue avant la prochaine itération
}