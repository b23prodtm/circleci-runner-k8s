PODMAN=0x10
DOCKER=0x01
(( INSTALL=0x0 ))
(( DRIVER=DOCKER ))

minikube stop || true
minikube delete || true

#!/usr/bin/env bash
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
