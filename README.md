# Minikube & CircleCI Setup Scripts

Scripts d'installation et de configuration pour Minikube avec CircleCI Container Agent et Envoy Gateway.

## 📋 Prérequis

- `jq` - Pour le parsing JSON des traductions
- `kubectl` - Pour la gestion Kubernetes
- `helm` - Pour les installations Helm
- `minikube` - Pour le cluster Kubernetes local

```bash
# Installation sur openSUSE
sudo zypper install jq kubectl helm minikube
```

## 🔧 Configuration

### 1. Créer le fichier de secrets

Le fichier `values.yaml` contient votre token CircleCI et **ne doit jamais être commité**.

```bash
# Copier le fichier exemple
cp values.yaml.example values.yaml

# Éditer avec votre token
nano values.yaml
```

**Où trouver votre token CircleCI :**
1. Allez sur https://app.circleci.com/settings/organization/YOUR_ORG/runners
2. Créez un nouveau runner ou copiez le token d'un runner existant
3. Dans `values.yaml`, remplacez :
   - `MY_ORG/RESOURCE_CLASS_HERE` avec votre resource class (ex: `mycompany/docker-runner`)
   - `YOUR_CIRCLECI_TOKEN_HERE` avec votre token

### 2. Vérifier le .gitignore

Le fichier `.gitignore` est déjà configuré pour ignorer `values.yaml`. **Vérifiez toujours** avant de commiter :

```bash
git status
# values.yaml ne doit PAS apparaître
```

## 🚀 Utilisation

### Script 1 : Configuration Minikube

Configure et démarre Minikube avec Podman ou Docker.

```bash
chmod +x configure.sh
./configure.sh
```

**Options interactives :**
- Langue : English ou Français
- Installation des dépendances : Oui/Non
- Driver : Podman (recommandé) ou Docker

### Script 2 : Installation CircleCI

Installe CircleCI Container Agent et Envoy Gateway.

```bash
chmod +x install.sh
./install.sh
```

**Options interactives :**
- Langue : English ou Français
- Méthode d'installation Envoy Gateway :
  - Helm (recommandé)
  - Kubernetes
  - Upgrade (mise à jour)

## 📁 Structure du projet

```
.
├── configure.sh                  # Script de configuration Minikube
├── install.sh                    # Script d'installation CircleCI
├── translations.json             # Traductions EN/FR
├── values.yaml                   # ⚠️ SECRET - Token CircleCI (ignoré par git)
├── values.yaml.example           # Template de configuration
├── .gitignore                    # Ignore les secrets
└── README.md                     # Ce fichier
```

## ⚠️ Sécurité

### Fichiers sensibles

- `values.yaml` - **JAMAIS commiter ce fichier**
- Contient votre token CircleCI et votre resource class
- Est automatiquement ignoré par git

### Vérifications de sécurité

```bash
# Vérifier que values.yaml est bien ignoré
git check-ignore values.yaml
# Doit retourner: values.yaml

# Lister les fichiers qui seront committés
git status
# values.yaml ne doit PAS apparaître

# Scanner l'historique pour des secrets (optionnel)
git log --all --full-history -- values.yaml
# Ne doit rien retourner
```

## 🌍 Ajouter une langue

Pour ajouter une nouvelle langue (ex: Espagnol) :

1. Éditer `translations.json`
2. Ajouter une section `ES` avec toutes les traductions
3. Modifier les scripts pour supporter la nouvelle langue

```json
{
  "EN": { ... },
  "FR": { ... },
  "ES": {
    "menu": {
      "title": "Configuración de Minikube"
    },
    ...
  }
}
```

## 🐛 Dépannage

### Erreur : "Translation file not found"
```bash
# Vérifier que translations.json existe
ls -la translations.json
```

### Erreur : "Configuration file not found"
```bash
# Créer le fichier de configuration
cp values.yaml.example values.yaml
# Éditer avec votre token
nano values.yaml
```

### Erreur : "Please replace YOUR_CIRCLECI_TOKEN_HERE"
```bash
# Vous devez remplacer le placeholder dans values.yaml
nano values.yaml
# Chercher YOUR_CIRCLECI_TOKEN_HERE et remplacer par votre vrai token
```

### Erreur : "No token found"
```bash
# Vérifier le contenu du fichier
grep "token:" values.yaml
# Doit contenir: token: <votre_token_reel>
```

## 📝 Licence

Ce projet est sous licence MIT.

## 🤝 Contribution

1. Fork le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. **ATTENTION** : Ne commitez jamais `values.yaml`
4. Commitez vos changements (`git commit -m 'Add some AmazingFeature'`)
5. Push vers la branche (`git push origin feature/AmazingFeature`)
6. Ouvrez une Pull Request