# Decisions — Dossier d'Architecture LaTeX

## ADR-001 : Structure multi-fichiers
- **Contexte** : Dossier d'architecture volumineux, besoin de clarté
- **Décision** : Un `main.tex` + fichiers par chapitre dans `chapters/`
- **Conséquence** : Modularité, compilation partielle possible avec \includeonly

## ADR-002 : Classe document
- **Contexte** : Besoin de chapitres numérotés
- **Décision** : `report` plutôt que `article`
- **Conséquence** : \chapter disponible, structure plus professionnelle

## ADR-003 : Pas de Proxmox/K3s/AD
- **Contexte** : Le TOC initial venait d'un autre projet
- **Décision** : Adapter le contenu au projet LockBits réel (EDR + Site + Chatbot + CI/CD)
- **Conséquence** : Pas de sections Proxmox, K3s, OPNsense, Active Directory
