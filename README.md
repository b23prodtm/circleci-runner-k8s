# Minikube & CircleCI Setup Scripts

Installation and configuration scripts for Minikube with CircleCI Container Agent and Envoy Gateway.

## 📋 Prerequisites

- `jq` - For JSON translation parsing
- `kubectl` - For Kubernetes management

```bash
# Installation on Ubuntu (Recommended)
sudo zypper install jq kubectl
```

```bash
# Installation on openSUSE
sudo zypper install jq kubectl
```

## 🔧 Configuration

### 1. Create the secrets file

The `values.yaml` file contains your CircleCI token and **must never be committed**.

```bash
# Copy the example file
cp values.yaml.example values.yaml

# Edit with your token
nano values.yaml
```

**Where to find your CircleCI token:**
1. Go to https://app.circleci.com/settings/organization/YOUR_ORG/runners
2. Create a new runner and go to last step.
3. Otherwise to copy the token from an existing runner, follow below steps.
4. Use CLI my-org/resource-class: ```circleci runner resource-class token create <namespace>/<resource-class>```
5. ```circleci runner token list <namespace>/<resource-class>```
6. ```circleci runner token delete <token-id>```
7. ```circleci runner token create  <namespace>/<resource-class> <token-name>```
8. In `values.yaml`, replace:
   - `MY_ORG/RESOURCE_CLASS_HERE` with your resource class (e.g., `my-org/resource-class`)
   - `YOUR_CIRCLECI_TOKEN_HERE` with your token

### 2. Check .gitignore

The `.gitignore` file is already configured to ignore `values.yaml`. **Always verify** before committing:

```bash
git status
# values.yaml should NOT appear
```

## 🚀 Usage

### Script 1: Minikube Configuration

Configures and starts Minikube with Podman or Docker.

```bash
chmod +x configure.sh
./configure.sh
```

**Interactive options:**
- Language: English or Français
- Install dependencies: Yes/No
- Driver: Podman (recommended) or Docker

### Script 2: CircleCI Installation

Installs CircleCI Container Agent and Envoy Gateway.

```bash
chmod +x install.sh
./install.sh
```

**Interactive options:**
- Language: English or Français
- Envoy Gateway installation method:
  - Helm (recommended)
  - Kubernetes
  - Upgrade (update existing)

## 📁 Project Structure

```
.
├── configure.sh                  # Minikube configuration script
├── install.sh                    # CircleCI installation script
├── translations.json             # EN/FR translations
├── values.yaml                   # ⚠️ SECRET - CircleCI token (ignored by git)
├── values.yaml.example           # Configuration template
├── .gitignore                    # Ignore secrets
└── README.md                     # This file
```

## ⚠️ Security

### Sensitive files

- `values.yaml` - **NEVER commit this file**
- Contains your CircleCI token and resource class
- Automatically ignored by git

### Security checks

```bash
# Verify that values.yaml is properly ignored
git check-ignore values.yaml
# Should return: values.yaml

# List files that will be committed
git status
# values.yaml should NOT appear

# Scan history for secrets (optional)
git log --all --full-history -- values.yaml
# Should return nothing
```

## 🌍 Adding a Language

To add a new language (e.g., Spanish):

1. Edit `translations.json`
2. Add an `ES` section with all translations
3. Modify scripts to support the new language

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

## 🐛 Troubleshooting

### Error: "Translation file not found"
```bash
# Verify that translations.json exists
ls -la translations.json
```

### Error: "Configuration file not found"
```bash
# Create the configuration file
cp values.yaml.example values.yaml
# Edit with your token
nano values.yaml
```

### Error: "Please replace YOUR_CIRCLECI_TOKEN_HERE"
```bash
# You must replace the placeholder in values.yaml
nano values.yaml
# Search for YOUR_CIRCLECI_TOKEN_HERE and replace with your actual token
```

### Error: "No token found"
```bash
# Check the file content
grep "token:" values.yaml
# Should contain: token: <your_actual_token>
```

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. **WARNING**: Never commit `values.yaml`
4. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
5. Push to the branch (`git push origin feature/AmazingFeature`)
6. Open a Pull Request
