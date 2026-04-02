// Stress test progressif - 90000 VUs max (22500 VUs par pod répartis simultanément sur 4 pods)
import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  discardResponseBodies: true,
  stages: [
    // 1. Échauffement (Warm-up)
    { duration: '2m', target: 5000 },  
    { duration: '3m', target: 5000 },  // Stabilisation pour attendre les nouveaux pods

    // 2. Premier palier sérieux
    { duration: '5m', target: 15000 }, 
    { duration: '5m', target: 15000 }, 

    // 3. Accélération
    { duration: '5m', target: 40000 }, 
    { duration: '5m', target: 40000 }, 

    // 4. Vers l'objectif final
    { duration: '5m', target: 70000 },
    { duration: '5m', target: 70000 },

    // 5. Pic à 90k
    { duration: '5m', target: 90000 },
    { duration: '10m', target: 90000 },

    // 6. Redescente
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<2000"], // 95% des requêtes < 2s
    http_req_failed: ["rate<0.01"], // Moins de 1% d'erreurs
  },
};

const BASE_URL = __ENV.BASE_URL || "http://hetic-friday-prod-alb-170460687.eu-central-1.elb.amazonaws.com";

const params = {
  headers: { "Connection": "keep-alive" },
};
const productIds = [
  "OLJCESPC7Z", "66VCHSJNUP", "1YMWWN1N4O", 
  "L9ECAV7KIM", "2ZYFJ3GM2N", "0PUK6V6EV0", 
  "LS4PSXUNUM", "9SIQT8TOJO", "6E92ZMYYFZ"
];

export default function () {
  // 1. Page d'accueil
  group("01_Home_Page", function () {
    const res = http.get(`${BASE_URL}/`, params);
    check(res, {
      "home status is 200": (r) => r.status === 200,
    });
  });

  sleep(Math.random() * 2 + 1); 
  
  // 2. Page Produit (navigation sur 3 produits aléatoires)
  for (let i = 1; i <= 3; i++) {
    let randomProduct = productIds[Math.floor(Math.random() * productIds.length)];
    
    group("02_Product_Page", function () {
      let res = http.get(`${BASE_URL}/product/${randomProduct}`, params);
      check(res, { "product status is 200": (r) => r.status === 200 });
    });

    sleep(Math.random() * 2 + 1);
  }
  // 3. Page Panier
  group("03_Cart_Page", function () {
    const res = http.get(`${BASE_URL}/cart`, params);
    check(res, {
      "cart status is 200": (r) => r.status === 200,
    });
  });

  sleep(Math.random() * 3 + 2);
}
