# Install kubectl if not present

function Install-Kubectl {
    Write-Host "Checking kubectl installation..." -ForegroundColor Yellow
    try {
        $kubectlVersion = kubectl version --client --short 2>$null
        Write-Host "✅ kubectl already installed: $kubectlVersion" -ForegroundColor Green
    } catch {
        Write-Host "Installing kubectl..." -ForegroundColor Yellow
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            choco install kubernetes-cli -y
        } else {
            Write-Host "Downloading kubectl manually..." -ForegroundColor Yellow
            $kubectlUrl = "https://dl.k8s.io/release/v1.30.0/bin/windows/amd64/kubectl.exe"
            $programFiles = ${env:ProgramFiles}
            if (-not (Test-Path "$programFiles\kubectl")) {
                New-Item -ItemType Directory -Path "$programFiles\kubectl" -Force
            }
            Invoke-WebRequest -Uri $kubectlUrl -OutFile "$programFiles\kubectl\kubectl.exe"
            $env:PATH += ";$programFiles\kubectl"
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
        }
        Write-Host "✅ kubectl installed successfully" -ForegroundColor Green
    }
}

Install-Kubectl