#!/usr/bin/env bash

PODMAN=0x10
DOCKER=0x01

# Fonction pour afficher le menu
afficher_menu() {
    echo "========================================"
    echo "  Configuration Minikube"
    echo "========================================"
    echo ""
}

# Prompt pour l'installation
demander_installation() {
    while true; do
        echo "Voulez-vous installer les dépendances (Circleci, Snap, etc.) ?"
        read -p "Réponse (o/n) : " reponse
        case $reponse in
            [Oo]* )
                INSTALL=0x1
                echo "✓ Installation activée"
                break
                ;;
            [Nn]* )
                INSTALL=0x0
                echo "✓ Installation désactivée"
                break
                ;;
            * )
                echo "Veuillez répondre par 'o' (oui) ou 'n' (non)"
                ;;
        esac
    done
    echo ""
}

# Prompt pour le driver
demander_driver() {
    while true; do
        echo "Quel driver souhaitez-vous utiliser ?"
        echo "  1) Podman (recommandé)"
        echo "  2) Docker"
        read -p "Votre choix (1 ou 2) : " choix
        case $choix in
            1 )
                DRIVER=$PODMAN
                echo "✓ Driver Podman sélectionné"
                break
                ;;
            2 )
                DRIVER=$DOCKER
                echo "✓ Driver Docker sélectionné"
                break
                ;;
            * )
                echo "Veuillez choisir 1 ou 2"
                ;;
        esac
    done
    echo ""
}

# Confirmation des choix
confirmer_choix() {
    echo "========================================"
    echo "  Résumé de la configuration"
    echo "========================================"
    if (( INSTALL == 0x1 )); then
        echo "Installation : OUI"
    else
        echo "Installation : NON"
    fi
    
    if (( DRIVER == PODMAN )); then
        echo "Driver       : PODMAN"
    else
        echo "Driver       : DOCKER"
    fi
    echo "========================================"
    echo ""
    
    while true; do
        read -p "Confirmer et lancer l'installation ? (o/n) : " reponse
        case $reponse in
            [Oo]* )
                return 0
                ;;
            [Nn]* )
                echo "Installation annulée."
                exit 0
                ;;
            * )
                echo "Veuillez répondre par 'o' (oui) ou 'n' (non)"
                ;;
        esac
    done
}

# Exécution du script principal
main() {
    afficher_menu
    demander_installation
    demander_driver
    confirmer_choix
    
    echo "Démarrage de la configuration..."
    echo ""
    
    # === SCRIPT ORIGINAL ===
    minikube stop || true
    minikube delete || true

    if (( INSTALL & 0x1 )); then
        printf "%s\n" ""
        printf "%s\n" "Install Circleci Snap..."
        sudo zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed snappy
        sudo zypper --gpg-auto-import-keys refresh
        sudo zypper dup --from snappy
        sudo zypper install snapd
        sudo systemctl enable --now snapd
        sudo systemctl enable --now snapd.apparmor
            sudo snap install circleci
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
        | sudo tee /etc/containers/registries.conf.d/001-registries.conf
        printf "%s\n" \
        "  # CircleCI" \
        "  \"circleci/runner-agent\" = \"docker.io/circleci/runner-agent\"" \
        "  \"envoyproxy/gateway-dev\" = \"docker.io/envoyproxy/gateway-dev\"" \
        | sudo tee /etc/containers/registries.conf.d/001-shortnames.conf
        cp -Rf /etc/containers/registries.conf.d /home/$USER/.config/containers/registries.conf.d
    fi
    
    if (( DRIVER & PODMAN )); then
        minikube start --driver=podman --container-runtime=cri-o
    fi
    
    if (( DRIVER & DOCKER )); then
        if (( INSTALL & DOCKER )); then
            dockerd-rootless-setuptool.sh install -f
            docker context use rootless
        fi
        minikube start --driver=docker --container-runtime=containerd
    fi
    
    minikube addons enable metrics-server
    
    echo ""
    echo "✓ Configuration terminée avec succès !"
}

# Lancer le script
main
