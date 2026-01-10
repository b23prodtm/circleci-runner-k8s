#!/usr/bin/env bash

HELM_VERSION="v1.6.1"
HELM_INSTALL=0x1
KUBERNETES_INSTALL=0x10
HELM_UPGRADE=0x100
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
    
    # Verify the file contains a token
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
        echo "  2) $(t 'installation.gateway.helm')"
        echo "  3) $(t 'installation.gateway.upgrade')"
        read -p "$(t 'installation.gateway.prompt') " choix
        case $choix in
            1 )
                GATEWAY_INSTALL=$KUBERNETES_INSTALL
                echo "$(t 'installation.gateway.kubernetes_selected')"
                break
                ;;
            2 )
                GATEWAY_INSTALL=$HELM_INSTALL
                echo "$(t 'installation.gateway.helm_selected')"
                break
                ;;
            3 )
                GATEWAY_INSTALL=$HELM_UPGRADE
                echo "$(t 'installation.gateway.upgrade_selected')"
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
    
    if (( GATEWAY_INSTALL == HELM_INSTALL )); then
        echo "$(t 'installation.confirm.method') $(t 'installation.gateway.helm')"
    elif (( GATEWAY_INSTALL == KUBERNETES_INSTALL )); then
        echo "$(t 'installation.confirm.method') $(t 'installation.gateway.kubernetes')"
    else
        echo "$(t 'installation.confirm.method') $(t 'installation.gateway.upgrade')"
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

# Main installation script
main() {
    load_translations
    check_values_file
    select_language
    display_menu
    ask_gateway_method
    confirm_choices
    
    echo "$(t 'installation.main.starting')"
    echo ""
    
    # Container runner installation
    printf "%s\n" ""
    printf "%s\n" "$(t 'installation.steps.container_runner')"
    helm uninstall container-agent -n circleci || true
    kubectl delete namespace circleci || true
    helm repo add container-agent https://packagecloud.io/circleci/container-agent/helm
    helm repo update
    kubectl create namespace circleci
    helm install container-agent container-agent/container-agent -n circleci -f "$VALUES_FILE"
    printf "%s\n" "$(t 'installation.steps.done')"

    sleep 1
    printf "%s\n" "$(t 'installation.steps.sysbox')"
    kubectl label nodes minikube sysbox-install=yes
    kubectl apply -f https://raw.githubusercontent.com/nestybox/sysbox/master/sysbox-k8s-manifests/sysbox-install.yaml
    printf "%s\n" "$(t 'installation.steps.done')"

    sleep 1
    printf "%s\n" ""
    printf "%s\n" "$(t 'installation.steps.ssh_enable')"
    printf "%s\n" "$(t 'installation.steps.envoy_version') $HELM_VERSION"
    helm uninstall eg -n envoy-gateway-system|| true
    kubectl delete namespace envoy-gateway-system || true

    if (( GATEWAY_INSTALL & HELM_INSTALL )); then
        printf "%s\n" "$(t 'installation.steps.helm_install')"
        helm install eg oci://docker.io/envoyproxy/gateway-helm --version "$HELM_VERSION" -n envoy-gateway-system --create-namespace
        kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
        kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/latest/quickstart.yaml -n default
    fi
    
    if (( GATEWAY_INSTALL & KUBERNETES_INSTALL )); then
        printf "%s\n" "$(t 'installation.steps.kubernetes_install')"
        kubectl apply --force-conflicts --server-side -f https://github.com/envoyproxy/gateway/releases/download/latest/install.yaml
    fi
    
    if (( GATEWAY_INSTALL & HELM_UPGRADE )); then  
        printf "%s\n" "$(t 'installation.steps.helm_upgrade')"
        helm pull oci://docker.io/envoyproxy/gateway-helm --version "$HELM_VERSION" --untar
        kubectl apply --force-conflicts --server-side -f ./gateway-helm/crds/gatewayapi-crds.yaml
        kubectl apply --force-conflicts --server-side -f ./gateway-helm/crds/generated
        helm upgrade eg oci://docker.io/envoyproxy/gateway-helm --version "$HELM_VERSION" -n envoy-gateway-system
        rm -Rfv ./gateway-helm
    fi
    printf "%s\n" "$(t 'installation.steps.done')"

    sleep 1
    printf "%s\n" "$(t 'installation.steps.redeploy')"
    helm upgrade --wait --timeout=5m eg container-agent/container-agent -n envoy-gateway-system -f "$VALUES_FILE"
    kubectl wait eg --timeout=5m --all --for=condition=Programmed -n envoy-gateway-system
    printf "%s\n" "$(t 'installation.steps.done')"
    
    echo ""
    echo "$(t 'installation.main.success')"
}

# Start the script
main
