#!/usr/bin/env bash
printf "%s\n" ""
printf "%s\n" "Install Circleci Snap..."
sudo zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Tumbleweed snappy
sudo zypper --gpg-auto-import-keys refresh
sudo zypper dup --from snappy
sudo zypper install snapd
sudo systemctl enable --now snapd
sudo systemctl enable --now snapd.apparmor
sudo snap install circleci
sudo snap install docker
sudo snap connect circleci:docker docker
printf "%s\n" "done..."

printf "%s\n" "You can invoke CLI with /snap/bin/circleci"
printf "%s\n"  "[aliases]" \
"  # CircleCI" \
"  \"circleci/runner-agent\" = \"docker.io/circleci/runner-agent\"" \
"  \"envoyproxy/gateway-dev\" = \"docker.io/envoyproxy/gateway-dev\"" \
| sudo tee /etc/containers/registries.conf.d/001-shortnames.conf
cp -Rf /etc/containers/registries.conf.d /home/$USER/.config/containers/registries.conf.d
