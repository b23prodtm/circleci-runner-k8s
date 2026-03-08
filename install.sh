#!/usr/bin/env bash

HELM_VERSION="v1.6.1"
KUBERNETES_INSTALL=0x10
NO_GATEWAY_INSTALL=0x100
LANG="EN"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSLATIONS_FILE="${SCRIPT_DIR}/translations.json"
VALUES_FILE="${SCRIPT_DIR}/values.yaml"

# Load translations from JSON file
load_translations() {
    if [[ ! -f "$TRANSLATIONS_FILE" ]]; then
        echo "ERROR: Translation file not found: $TRANSLATIONS_FILE"
        exit 1
    fi
}

# Check if values.yaml exists
check_values_file() {
    if [[ ! -f "$VALUES_FILE" ]]; then
        echo ""
        echo "$(t 'installation.error.values_missing')"
        echo ""
        echo "$(t 'installation.error.values_instructions')"
        echo ""
        echo "  cp values.yaml.example values.yaml"
        echo "  nano values.yaml"
        echo ""
        echo "$(t 'installation.error.values_template')"
        echo ""
        exit 1
    fi

    if grep -q "YOUR_CIRCLECI_TOKEN_HERE" "$VALUES_FILE"; then
        echo ""
        echo "$(t 'installation.error.token_placeholder')"
        echo ""
        exit 1
    fi

    if ! grep -q "token:" "$VALUES_FILE"; then
        echo ""
        echo "$(t 'installation.error.token_missing')"
        echo ""
        exit 1
    fi
}

# Get translated text
# Usage: t "key"
t() {
    local key="$1"
    local translation
    translation=$(jq -r ".${LANG}.${key} // \"MISSING: ${key}\"" "$TRANSLATIONS_FILE" 2>/dev/null)
    echo "$translation"
}

# Language selection
select_language() {
    echo "========================================"
    echo "  Language / Langue"
    echo "========================================"
    echo "  1) English"
    echo "  2) Français"
    echo ""
    while true; do
        read -p "Select / Choisir (1 ou 2) : " choix
        case $choix in
            1 )
                LANG="EN"
                break
                ;;
            2 )
                LANG="FR"
                break
                ;;
            * )
                echo "Please choose 1 or 2 / Veuillez choisir 1 ou 2"
                ;;
        esac
    done
    echo ""
}

# Display menu
display_menu() {
    echo "========================================"
    echo "  $(t 'installation.menu.title')"
    echo "========================================"
    echo ""
}

# Prompt for gateway installation method
ask_gateway_method() {
    while true; do
        echo "$(t 'installation.gateway.question')"
        echo "  1) $(t 'installation.gateway.kubernetes')"
        echo "  2) $(t 'installation.gateway.none')"
        read -p "$(t 'installation.gateway.prompt') " choix
        case $choix in
            1 )
                GATEWAY_INSTALL=$KUBERNETES_INSTALL
                echo "$(t 'installation.gateway.kubernetes_selected')"
                break
                ;;
            2 )
                GATEWAY_INSTALL=$NO_GATEWAY_INSTALL
                echo "$(t 'installation.gateway.none_selected')"
                break
                ;;
            * )
                echo "$(t 'installation.gateway.invalid')"
                ;;
        esac
    done
    echo ""
}

# Confirmation of choices
confirm_choices() {
    echo "========================================"
    echo "  $(t 'installation.confirm.title')"
    echo "========================================"
    echo "$(t 'installation.confirm.helm_version') $HELM_VERSION"

    if (( GATEWAY_INSTALL == KUBERNETES_INSTALL )); then
        echo "$(t 'installation.confirm.method') $(t 'installation.gateway.kubernetes')"
    else
        echo "$(t 'installation.confirm.method') $(t 'installation.gateway.none')"
    fi
    echo "========================================"
    echo ""

    while true; do
        read -p "$(t 'installation.confirm.question') " reponse
        case $reponse in
            [OoYy]* )
                return 0
                ;;
            [Nn]* )
                echo "$(t 'installation.confirm.cancelled')"
                exit 0
                ;;
            * )
                echo "$(t 'installation.confirm.invalid')"
                ;;
        esac
    done
}


# Install helm if not present
install_helm() {
    if command -v helm &> /dev/null; then
        printf "%s\n" "helm already installed: $(helm version --short)"
        return 0
    fi
    printf "%s\n" "Installing helm..."
    # Try snap first (available after configure.sh)
    if command -v snap &> /dev/null; then
        sudo snap install helm --classic && return 0
    fi
    # Download binary directly from GitHub releases (HTTP/1.1 to avoid stream errors)
    local HELM_INSTALL_VERSION="v3.14.4"
    local ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *)        ARCH="amd64" ;;
    esac
    local HELM_URL="https://get.helm.sh/helm-${HELM_INSTALL_VERSION}-linux-${ARCH}.tar.gz"
    local TMPDIR
    TMPDIR=$(mktemp -d)
    curl --http1.1 -fsSL "$HELM_URL" -o "$TMPDIR/helm.tar.gz"
    tar -xzf "$TMPDIR/helm.tar.gz" -C "$TMPDIR"
    sudo mv "$TMPDIR/linux-${ARCH}/helm" /usr/local/bin/helm
    sudo chmod +x /usr/local/bin/helm
    rm -rf "$TMPDIR"
    helm version --short
}

# Main installation script
main() {
    load_translations
    check_values_file
    install_helm
    select_language
    display_menu
    ask_gateway_method
    confirm_choices

    echo "$(t 'installation.main.starting')"
    echo ""

    sleep 1

    # Container runner installation
    printf "%s\n" ""
    printf "%s\n" "$(t 'installation.steps.container_runner')"
    helm uninstall container-agent -n circleci || true
    kubectl delete namespace circleci || true
    printf "%s\n" "$(t 'installation.steps.helm_upgrade')"
    helm repo add container-agent https://packagecloud.io/circleci/container-agent/helm
    helm repo update
    kubectl create namespace circleci
    helm install container-agent container-agent/container-agent -n circleci -f "$VALUES_FILE"
    printf "%s\n" "$(t 'installation.steps.done')"

    sleep 1
    printf "%s\n" ""

    if (( GATEWAY_INSTALL & KUBERNETES_INSTALL )); then
        printf "%s\n" "$(t 'installation.steps.kubernetes_install')"
        kubectl apply --validate=false --force-conflicts --server-side \
            -f https://github.com/envoyproxy/gateway/releases/download/latest/install.yaml
        HELM_TMPDIR=$(mktemp -d)
        helm pull oci://docker.io/envoyproxy/gateway-helm \
            --version "$HELM_VERSION" --untar --untardir "$HELM_TMPDIR"
        kubectl apply --validate=false --force-conflicts --server-side \
            -f "$HELM_TMPDIR/gateway-helm/crds/gatewayapi-crds.yaml"
        kubectl apply --validate=false --force-conflicts --server-side \
            -f "$HELM_TMPDIR/gateway-helm/crds/generated"
        rm -Rfv "$HELM_TMPDIR"
        printf "%s\n" "$(t 'installation.steps.done')"

        sleep 1
        printf "%s\n" "$(t 'installation.steps.ssh_enable')"
        printf "%s\n" "$(t 'installation.steps.envoy_version') $HELM_VERSION"
        printf "%s\n" "$(t 'installation.steps.redeploy')"
        helm upgrade --wait --timeout=5m eg \
            container-agent/container-agent \
            -n envoy-gateway-system \
            -f "$VALUES_FILE"
        kubectl wait eg --timeout=5m --all \
            --for=condition=Programmed \
            -n envoy-gateway-system
        printf "%s\n" "$(t 'installation.steps.done')"
    fi

    if (( GATEWAY_INSTALL & NO_GATEWAY_INSTALL )); then
        helm uninstall eg -n envoy-gateway-system || true
        kubectl delete namespace envoy-gateway-system || true
        printf "%s\n" "$(t 'installation.steps.done')"
    fi

    echo ""
    minikube -p runner addons enable headlamp
    kubectl create token headlamp --duration 24h -n headlamp
    echo "$(t 'installation.main.success')"
    echo "$(t 'installation.main.dashboard')"
    minikube -p runner service headlamp -n headlamp --url=true
}

# Start the script
main
