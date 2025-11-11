#!/bin/bash
# Install eksctl if not present

check_and_install_eksctl() {
    echo "Checking eksctl installation..."
    if ! command -v eksctl &> /dev/null || ! eksctl version &> /dev/null; then
        echo "Installing eksctl..."
        curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
        sudo mv /tmp/eksctl /usr/local/bin
        echo "✅ eksctl installed successfully"
    else
        echo "✅ eksctl already installed: $(eksctl version --output json | grep -o '"GitTag":"[^"]*' | cut -d'"' -f4)"
    fi
}

check_and_install_eksctl