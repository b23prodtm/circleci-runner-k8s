#!/bin/bash
# File: ./scripts/minikube_service.sh
# Installation script for Minikube Sysbox systemd user service

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if minikube is installed
check_minikube() {
    if ! command -v minikube &> /dev/null; then
        print_error "Minikube is not installed. Please install minikube first."
        exit 1
    fi
    print_info "Minikube found: $(minikube version --short)"
}

# Create systemd user directory
create_systemd_dir() {
    local systemd_dir="$HOME/.config/systemd/user"
    if [ ! -d "$systemd_dir" ]; then
        print_info "Creating systemd user directory: $systemd_dir"
        mkdir -p "$systemd_dir"
    else
        print_info "Systemd user directory already exists"
    fi
}

# Create the service file
create_service_file() {
    local service_file="$HOME/.config/systemd/user/minikube-sysbox.service"
    
    print_info "Creating service file: $service_file"
    
    cat > "$service_file" << 'EOF'
[Unit]
Description=Minikube Sysbox Profile Startup with Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="HOME=%h"

# Start minikube with sysbox profile
ExecStart=/bin/bash -c 'minikube start -p sysbox && sleep 5 && minikube dashboard -p sysbox'

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
EOF

    print_info "Service file created successfully"
}

# Reload systemd daemon
reload_systemd() {
    print_info "Reloading systemd user daemon..."
    systemctl --user daemon-reload
}

# Enable the service
enable_service() {
    print_info "Enabling minikube-sysbox.service..."
    systemctl --user enable minikube-sysbox.service
}

# Enable lingering (optional but recommended)
enable_lingering() {
    print_info "Enabling user lingering (allows service to start before login)..."
    if loginctl enable-linger "$USER" 2>/dev/null; then
        print_info "Lingering enabled for user: $USER"
    else
        print_warn "Could not enable lingering. You may need sudo privileges."
        print_warn "Run: sudo loginctl enable-linger $USER"
    fi
}

# Offer to start the service now
start_service() {
    read -p "Do you want to start the service now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Starting minikube-sysbox.service..."
        systemctl --user start minikube-sysbox.service
        sleep 2
        print_info "Service status:"
        systemctl --user status minikube-sysbox.service --no-pager
    else
        print_info "Service not started. You can start it later with:"
        echo "  systemctl --user start minikube-sysbox.service"
    fi
}

# Display helpful commands
show_usage() {
    echo ""
    print_info "Installation complete! Useful commands:"
    echo ""
    echo "  Check service status:"
    echo "    systemctl --user status minikube-sysbox.service"
    echo ""
    echo "  Start service:"
    echo "    systemctl --user start minikube-sysbox.service"
    echo ""
    echo "  Stop service:"
    echo "    systemctl --user stop minikube-sysbox.service"
    echo ""
    echo "  Restart service:"
    echo "    systemctl --user restart minikube-sysbox.service"
    echo ""
    echo "  Disable service:"
    echo "    systemctl --user disable minikube-sysbox.service"
    echo ""
    echo "  View logs:"
    echo "    journalctl --user -u minikube-sysbox.service -f"
    echo ""
}

# Main installation flow
main() {
    echo "========================================="
    echo "Minikube Sysbox Service Installer"
    echo "========================================="
    echo ""
    
    check_minikube
    create_systemd_dir
    create_service_file
    reload_systemd
    enable_service
    enable_lingering
    start_service
    show_usage
    
    print_info "Installation finished!"
}

# Run main function
main
