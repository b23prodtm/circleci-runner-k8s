#!/usr/bin/env bash

PODMAN=0x10
DOCKER=0x01
KUBERNETES_VERSION="v1.32"
CRIO_VERSION="v1.32"
LANG="EN"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSLATIONS_FILE="${SCRIPT_DIR}/translations.json"
REGISTRY_DIR="/home/$USER/.config/containers"
REGISTRIES_FILE="registries.conf"
REGISTRIES_ALIASES_FILE="registries.conf.d/shortnames.conf"

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

# Configure CRI-O for rootless userns
configure_crio_userns() {
    echo "$(t 'install.crio_userns')"

    # Setup subuid/subgid for rootless containers (required by newuidmap)
    minikube ssh -p runner -- sudo bash -c '
        for U in root $(id -un 1000 2>/dev/null || echo ubuntu); do
            if ! grep -q "^${U}:" /etc/subuid 2>/dev/null; then
                echo "${U}:100000:65536" >> /etc/subuid
            fi
            if ! grep -q "^${U}:" /etc/subgid 2>/dev/null; then
                echo "${U}:100000:65536" >> /etc/subgid
            fi
        done
    '

    # Ensure newuidmap/newgidmap have correct setuid bit
    minikube ssh -p runner -- sudo bash -c '
        chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap 2>/dev/null || true
    '

    # CRI-O capabilities config
    minikube ssh -p runner -- sudo tee /etc/crio/crio.conf.d/99-userns.conf << 'CRIEOF'
[crio.runtime]
default_capabilities = [
  "CHOWN",
  "DAC_OVERRIDE",
  "FSETID",
  "FOWNER",
  "SETGID",
  "SETUID",
  "SETPCAP",
  "NET_BIND_SERVICE",
  "KILL"
]
CRIEOF

    # Enable unprivileged user namespaces
    minikube ssh -p runner -- \
        sudo sysctl -w kernel.unprivileged_userns_clone=1
    minikube ssh -p runner -- \
        sudo bash -c 'echo "kernel.unprivileged_userns_clone=1" > /etc/sysctl.d/99-userns.conf'

    # Restart CRI-O to apply config
    minikube ssh -p runner -- \
        sudo systemctl restart crio

    echo "$(t 'install.done')"
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

    # === UBUNTU-SPECIFIC INSTALLATION ===

    if (( INSTALL & 0x1 )); then
        printf "%s\n" ""
        printf "%s\n" "$(t 'install.dependencies')"

        # Install minikube
        if ! command -v minikube &> /dev/null; then
            sudo apt-get install -y curl
            dir="$(pwd)"; cd "/home/$USER"
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
            chmod 0644 minikube_latest_amd64.deb
            sudo dpkg -i minikube_latest_amd64.deb
            rm minikube_latest_amd64.deb
            cd "$dir"
        fi

        # Install CRI-O
        if ! command -v crio &> /dev/null; then
            dir="$(pwd)"; cd "/home/$USER"
            curl -fsSL "https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key" |
            sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
            echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
            sudo tee /etc/apt/sources.list.d/cri-o.list
            cd "$dir"
            sudo apt-get update
            sudo apt-get install -y cri-o
            sudo systemctl start crio.service
        fi

        # Install kubectl
        if ! command -v kubectl &> /dev/null; then
            dir="$(pwd)"; cd "/home/$USER"
            curl -fsSL "https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key" |
            sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
            sudo tee /etc/apt/sources.list.d/kubernetes.list
            cd "$dir"
            sudo apt-get update
            sudo apt-get install -y kubectl
        fi

        # Install crictl
        if ! command -v crictl &> /dev/null; then
            sudo apt-get install -y kubeadm kubelet
        fi

        # Install snapd
        if ! command -v snap &> /dev/null; then
            sudo apt-get install -y snapd
            sudo systemctl enable --now snapd.socket
            sudo systemctl enable --now snapd
            sleep 5
        fi

        # Install CircleCI CLI, helm
        sudo snap install circleci
        sudo snap install helm --classic

        # Registries configuration
        mkdir -p "$REGISTRY_DIR"
        cp -vf "$REGISTRIES_FILE" "$REGISTRY_DIR"
        mkdir -p "$(dirname "$REGISTRY_DIR/$REGISTRIES_ALIASES_FILE")"
        cp -vf "$REGISTRIES_ALIASES_FILE" "$REGISTRY_DIR"
        printf "%s\n" "$(t 'install.done')"

        if (( DRIVER & DOCKER )); then
            sudo snap remove docker 2>/dev/null || true
            if ! command -v docker &> /dev/null; then
                sudo apt-get install -y curl
                dir="$(pwd)"; cd "/home/$USER"
                curl -fsSL https://get.docker.com/rootless -o get-docker.sh
                chmod 0755 get-docker.sh
                ./get-docker.sh
                rm get-docker.sh
                cd "$dir"
            fi
            sudo snap install docker
            sudo snap connect circleci:docker docker
            docker system info || exit 0
        fi

        if (( DRIVER & PODMAN )); then
            sudo apt-get update
            sudo apt-get install -y podman
            podman system info || exit 0
        fi
    fi

    minikube -p runner stop || true
    minikube -p runner delete || true

    minikube config -p runner set rootless true

    if (( DRIVER & PODMAN )); then
        minikube start \
            --driver=podman \
            --container-runtime=cri-o \
            -p runner \
            --kubernetes-version="$KUBERNETES_VERSION" \
            --extra-config=kubelet.cgroup-driver=systemd \
            --extra-config=kubelet.allowed-unsafe-sysctls=kernel.msg*,net.core.somaxconn
    fi

    if (( DRIVER & DOCKER )); then
        minikube start \
            --driver=docker \
            --container-runtime=cri-o \
            -p runner \
            --kubernetes-version="$KUBERNETES_VERSION" \
            --extra-config=kubelet.cgroup-driver=systemd \
            --extra-config=kubelet.allowed-unsafe-sysctls=kernel.msg*,net.core.somaxconn
    fi

    # Configure CRI-O rootless user namespaces (replaces sysbox)
    configure_crio_userns

    minikube -p runner addons enable metrics-server
    minikube -p runner cp "$REGISTRIES_FILE" "/etc/containers/$REGISTRIES_FILE"
    minikube -p runner cp "$REGISTRIES_ALIASES_FILE" "/etc/containers/$REGISTRIES_ALIASES_FILE"
    minikube -p runner start
    minikube profile list

    echo ""
    echo "$(t 'main.success')"
    printf "%s\n" "$(t 'install.invoke') circleci setup"
}

# Start the script
main
