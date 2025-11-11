#!/bin/bash
# Install kubectl if not present

check_and_install_kubectl() {
    echo "Checking kubectl installation..."
    if ! command -v kubectl &> /dev/null; then
        echo "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        echo "✅ kubectl installed successfully"
    else
        echo "✅ kubectl already installed: $(kubectl version --client --short 2>/dev/null || echo 'version check failed')"
    fi
}

check_and_install_kubectl