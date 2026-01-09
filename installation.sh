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
HELM_VERSION="1.6.1"
printf "%s\n" ""
printf "%s\n" "Enable rerun job with SSH..."
printf "%s\n" "Helm version $HELM_VERSION"
kubectl uninstall eg -n envoy-gateway-system|| true
kubectl delete namespace envoy-gateway-system || true
helm install eg oci://docker.io/envoyproxy/gateway-helm --version "$HELM_VERSION" -n envoy-gateway-system --create-namespace
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
helm upgrade --wait --timeout=5m eg container-agent/container-agent -n envoy-gateway-system -f values.yaml
kubectl wait gateway --timeout=5m --all --for=condition=Programmed -n envoy-gateway-system
printf "%s\n" "done..."


