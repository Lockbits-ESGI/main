# Roadmap

## ✅ Done — v1.0.0

- [x] EDR Server : scan de fichiers, rapports STIX, intégration VirusTotal
- [x] Agent EDR : binaire portable + conteneur Docker
- [x] Site client : portail avec authentification GLPI SSO
- [x] CI/CD : lint → test → build multi-arch → push → Trivy
- [x] Déploiement one-liner avec install.sh
- [x] Monitoring stack (Prometheus, Grafana, Loki)
- [x] Auto-update des submodules toutes les heures

## 🔜 Short-term

- [ ] **Fix : création de ticket GLPI** — bug dans l'appel API GLPI côté site
- [ ] Améliorer la couverture de tests unitaires EDR (objectif 80 %)
- [ ] Ajouter des tests d'intégration pour le site client
- [ ] Configuration Dokploy automatisée

## 📅 Medium-term

- [ ] Dashboard Grafana prêt à l'emploi (import automatique)
- [ ] Alerting Prometheus (webhook Discord/email)
- [ ] Backups automatiques de la base MySQL
- [ ] Support IPv6 dans la stack Docker
- [ ] Rate limiting sur l'API EDR

## 🔭 Long-term

- [ ] Authentification OAuth2 complète (Google, Microsoft)
- [ ] Interface d'administration web pour l'EDR
- [ ] Support de déploiement Kubernetes (minikube / k3s)
- [ ] Intégration SIEM (Wazuh / ELK)
- [ ] Tests de pénétration automatisés
