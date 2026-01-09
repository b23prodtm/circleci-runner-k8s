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
