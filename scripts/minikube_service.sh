#!/bin/bash
# File: ~/.config/systemd/user/minikube-sysbox.service
#
# Installation instructions:
# 1. Create the systemd user directory if it doesn't exist:
#    mkdir -p ~/.config/systemd/user
#
# 2. Save this file as: ~/.config/systemd/user/minikube-sysbox.service
#
# 3. Reload systemd user daemon:
#    systemctl --user daemon-reload
#
# 4. Enable the service to start at boot:
#    systemctl --user enable minikube-sysbox.service
#
# 5. Start the service immediately (optional):
#    systemctl --user start minikube-sysbox.service
#
# 6. Check status:
#    systemctl --user status minikube-sysbox.service
#
# 7. View logs:
#    journalctl --user -u minikube-sysbox.service -f

[Unit]
Description=Minikube Sysbox Profile Startup with Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="HOME=%h"

# Start minikube with sysbox profile
ExecStart=/bin/bash -c 'minikube start -p sysbox && sleep 5 && minikube dashboard -p sysbox &'

# Stop minikube gracefully
ExecStop=/usr/bin/minikube stop -p sysbox

# Restart on failure
Restart=on-failure
RestartSec=10

# Resource limits (adjust as needed)
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=default.target