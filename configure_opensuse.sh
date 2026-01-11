#!/usr/bin/env bash

PODMAN=0x10
DOCKER=0x01
KUBEV="v1.32.11"
LANG="EN"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSLATIONS_FILE="${SCRIPT_DIR}/translations.json"

# Load translations from JSON file
load_translations() {
    if [[ ! -f "$TRANSLATIONS_FILE" ]]; then
        echo "ERROR: Translation file not found: $TRANSLATIONS_FILE"
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
    echo "  $(t 'menu.title')"
    echo "========================================"
    echo ""
}

# Prompt for installation
ask_installation() {
    while true; do
        echo "$(t 'install.question')"
        read -p "$(t 'install.prompt') " reponse
        case $reponse in
            [OoYy]* )
                INSTALL=0x1
                echo "$(t 'install.enabled')"
                break
                ;;
            [Nn]* )
                INSTALL=0x0
                echo "$(t 'install.disabled')"
                break
                ;;
            * )
                echo "$(t 'install.invalid')"
                ;;
        esac
    done
    echo ""
}

# Prompt for driver
ask_driver() {
    while true; do
        echo "$(t 'driver.question')"
        echo "  1) $(t 'driver.docker')"
        echo "  2) $(t 'driver.podman')"
        read -p "$(t 'driver.prompt') " choix
        case $choix in
            1 )
                DRIVER=$DOCKER
                echo "$(t 'driver.docker_selected')"
                break
                ;;
            2 )
                DRIVER=$PODMAN
                echo "$(t 'driver.podman_selected')"
                break
                ;;
            * )
                echo "$(t 'driver.invalid')"
                ;;
        esac
    done
    echo ""
}

# Confirmation of choices
confirm_choices() {
    echo "========================================"
    echo "  $(t 'confirm.title')"
    echo "========================================"
    if (( INSTALL == 0x1 )); then
        echo "$(t 'confirm.installation') $(t 'confirm.yes')"
    else
        echo "$(t 'confirm.installation') $(t 'confirm.no')"
    fi
    
    if (( DRIVER == PODMAN )); then
        echo "$(t 'confirm.driver') PODMAN"
    else
        echo "$(t 'confirm.driver') DOCKER"
    fi
    echo "========================================"
    echo ""
    
    while true; do
        read -p "$(t 'confirm.question') " reponse
        case $reponse in
            [OoYy]* )
                return 0
                ;;
            [Nn]* )
                echo "$(t 'confirm.cancelled')"
                exit 0
                ;;
            * )
                echo "$(t 'confirm.invalid')"
                ;;
        esac
    done
}

# Main script execution
main() {
    load_translations
    select_language
    display_menu
    ask_installation
    ask_driver
    confirm_choices
    
    echo "$(t 'main.starting')"
    echo ""
    
    # === ORIGINAL SCRIPT ===
    minikube -p sysbox stop || true
    minikube -p sysbox delete || true

    if (( INSTALL & 0x1 )); then
        printf "%s\n" ""
        printf "%s\n" "Install Circleci Snap..."
        sudo zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed snappy
        sudo zypper --gpg-auto-import-keys refresh
        sudo zypper dup --from snappy
        sudo zypper install snapd
        sudo systemctl enable --now snapd
        sudo systemctl enable --now snapd.apparmor
        sudo snap install minikube circleci
        alias kubectl="minikube.ctl --"
        if (( DRIVER & DOCKER )); then
            snap install docker
            sudo snap connect circleci:docker docker
        fi
        if (( DRIVER & PODMAN )); then
            snap install --edge --devmode podman
            sudo snap connect circleci:docker podman
        fi
        printf "%s\n" "done..."

        printf "%s\n" "You can invoke CLI with /snap/bin/circleci"

        printf "%s\n"  "[[registry]]" \
        "  # DockerHub" \
        "  \"location\" = \"docker.io\"" \
        | sudo tee /etc/containers/registries.conf.d/k8s-registries.conf
        printf "%s\n"  "[aliases]" \
        "  # CircleCI" \
        "  \"circleci/runner-agent\" = \"docker.io/circleci/runner-agent\"" \
        "  \"envoyproxy/gateway-dev\" = \"docker.io/envoyproxy/gateway-dev\"" \
        | sudo tee /etc/containers/registries.conf.d/k8s-shortnames.conf
        printf "%s\n" "Copied to the user containers path..."
        cp -Rvf /etc/containers/registries.conf.d /home/$USER/.config/containers/
    fi
    
    if (( DRIVER & PODMAN )); then
        minikube start --driver=podman --container-runtime=cri-o -p sysbox --kubernetes-version="$KUBEV"
    fi
    
    if (( DRIVER & DOCKER )); then
        if (( INSTALL & DOCKER )); then
            dockerd-rootless-setuptool.sh install -f
	    unset DOCKER_HOST
            docker context use rootless
        fi
        minikube start --driver=docker --container-runtime=containerd -p sysbox --kubernetes-version="$KUBEV"
    fi
    
    minikube -p sysbox addons enable metrics-server
    minikube profile list
    
    echo ""
    echo "$(t 'main.success')"
}

# Start the script
main
