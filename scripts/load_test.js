// installer dépendences macOS : brew install k6
// lancer le script : k6 run --vus 500 --duration 5m load_test.js
import http from "k6/http";

export default function () {
  // Ne pas oublier de mettre à jour l'URL de l'application
  http.get(
    "http://a8cda0b9fd451481eb413153c15b91b2-1118995752.eu-central-1.elb.amazonaws.com/",
  );
}
