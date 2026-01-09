printf "%s\n" ""
printf "%s\n" "Container runner installation..."
kubectl uninstall container-agent -n circleci || true
kubectl delete namespace circleci || true
helm repo add container-agent https://packagecloud.io/circleci/container-agent/helm
helm repo update
kubectl create namespace circleci
helm install container-agent container-agent/container-agent -n circleci -f values.yaml
printf "%s\n" "done..."

sleep 2
HELM_VERSION="v1.6.1"
HELM_INSTALL=0x1
KUBERNETES_INSTALL=0x10
KUBERNETES_UPGRADE=0x100
(( INSTALL=KUBERNETES_INSTALL ))
printf "%s\n" ""
printf "%s\n" "Enable rerun job with SSH..."
printf "%s\n" "Envoyproxy/gateway-helm version $HELM_VERSION"
kubectl uninstall eg -n envoy-gateway-system|| true
kubectl delete namespace envoy-gateway-system || true

if (( INSTALL & HELM_INSTALL )); then
  printf "%s\n" "Installation with Helm..."
  helm install eg oci://docker.io/envoyproxy/gateway-helm --version "$HELM_VERSION" -n envoy-gateway-system --create-namespace
  kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
  kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/latest/quickstart.yaml -n default
fi
if (( INSTALL & KUBERNETES_INSTALL )); then
  printf "%s\n" "Installation with Kubernetes..."
  kubectl apply --force-conflicts --server-side -f https://github.com/envoyproxy/gateway/releases/download/latest/install.yaml
fi
if (( INSTALL & KUBERNETES_UPGRADE )); then  
  helm pull oci://docker.io/envoyproxy/gateway-helm --version "$HELM_VERSION" --untar
  kubectl apply --force-conflicts --server-side -f ./gateway-helm/crds/gatewayapi-crds.yaml
  kubectl apply --force-conflicts --server-side -f ./gateway-helm/crds/generated
  helm upgrade eg oci://docker.io/envoyproxy/gateway-helm --version "$HELM_VERSION" -n envoy-gateway-system
  rm -Rfv ./gateway-helm
fi
printf "%s\n" "done..."

sleep 1
printf "%s\n" "Redeploy Manifest for SSH gateway to be programmed..."
helm upgrade --wait --timeout=5m eg container-agent/container-agent -n envoy-gateway-system -f values.yaml
kubectl wait eg --timeout=5m --all --for=condition=Programmed -n envoy-gateway-system
printf "%s\n" "done..."


