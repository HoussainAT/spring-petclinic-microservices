# Explication de la correction — OWASP A05:2021

## Résumé

La correction applique le principe de moindre privilège sur les endpoints Spring Boot
Actuator et ajoute les headers de sécurité HTTP manquants, conformément aux
recommandations OWASP A05:2021 Security Misconfiguration.

---

## Before / After

### Exposition des endpoints Actuator

**Avant (vulnérable)**
```yaml
# application.yml par défaut
management:
  endpoints:
    web:
      exposure:
        include: "*"   # TOUS les endpoints exposés sans restriction
```
→ `/actuator/env`, `/actuator/beans`, `/actuator/heapdump`, etc. accessibles
  publiquement sans authentification.

**Après (corrigé)**
```yaml
# application-security.yml
management:
  endpoints:
    web:
      exposure:
        include: "health,info"   # Seulement les endpoints inoffensifs
  server:
    port: 8081                   # Port interne, non exposé via Security Group
```
→ Seuls `/actuator/health` et `/actuator/info` restent accessibles publiquement.

---

### Authentification et autorisation

**Avant (vulnérable)**
```java
// Aucune configuration Spring Security — tout est permit
http.authorizeExchange(e -> e.anyExchange().permitAll())
```

**Après (corrigé — SecurityConfig.java)**
```java
.authorizeExchange(exchanges -> exchanges
    .pathMatchers("/actuator/health", "/actuator/info").permitAll()
    .pathMatchers("/actuator/**").hasRole("ADMIN")   // ADMIN uniquement
    .anyExchange().authenticated()
)
```

---

### Headers de sécurité HTTP

**Avant (vulnérable)**  
Aucun header de sécurité configuré → XSS, clickjacking possibles.

**Après (corrigé)**
```java
.headers(headers -> headers
    .frameOptions(frame -> frame.mode(Mode.DENY))           // Anti-clickjacking
    .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))  // Anti-XSS
)
```

Réponse HTTP après correction :
```
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
```

---

## Référence OWASP A05:2021

> **A05:2021 – Security Misconfiguration** se produit quand :
> - Des fonctionnalités inutiles sont activées ou installées (ports, services, pages, comptes, privilèges)
> - Les comptes par défaut et leurs mots de passe sont toujours activés
> - La gestion des erreurs révèle des traces de stack ou des messages trop informatifs
> - Les paramètres de sécurité dans les frameworks ne sont pas correctement configurés

Source : [owasp.org/Top10/A05_2021-Security_Misconfiguration](https://owasp.org/Top10/A05_2021-Security_Misconfiguration/)

---

## Relancer le scan ZAP pour vérifier la correction

### 1. Mettre à jour le secret GitHub `ZAP_TARGET`
```bash
gh secret set ZAP_TARGET --body "<NOUVELLE_IP_EC2>"
```

### 2. Déclencher le workflow manuellement
```bash
gh workflow run zap-scan.yml
```

### 3. Vérifier les résultats
```bash
gh run list --workflow=zap-scan.yml --limit 5
gh run view <RUN_ID> --log
```

### 4. Télécharger le rapport HTML
Dans l'onglet **Actions → Artifacts** du dépôt GitHub, télécharger `zap-report-<N>`.

### Résultats attendus après correction

| Finding (avant) | Statut attendu (après) |
|-----------------|------------------------|
| Actuator env/beans exposés | RÉSOLU — 401 Unauthorized |
| X-Frame-Options manquant | RÉSOLU — Header présent |
| Content-Security-Policy absent | RÉSOLU — Header présent |
| Accès non authentifié aux API | RÉSOLU — 401/403 |
