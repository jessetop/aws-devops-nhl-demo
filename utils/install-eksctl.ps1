# Install eksctl if not present

function Install-Eksctl {
    Write-Host "Checking eksctl installation..." -ForegroundColor Yellow
    try {
        $eksctlVersion = eksctl version --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty GitTag
        Write-Host "✅ eksctl already installed: $eksctlVersion" -ForegroundColor Green
    } catch {
        Write-Host "Installing eksctl..." -ForegroundColor Yellow
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            choco install eksctl -y
        } else {
            Write-Host "Downloading eksctl manually..." -ForegroundColor Yellow
            $eksctlUrl = "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Windows_amd64.zip"
            $tempPath = "$env:TEMP\eksctl.zip"
            Invoke-WebRequest -Uri $eksctlUrl -OutFile $tempPath
            Expand-Archive -Path $tempPath -DestinationPath "$env:TEMP\eksctl" -Force
            $programFiles = ${env:ProgramFiles}
            if (-not (Test-Path "$programFiles\eksctl")) {
                New-Item -ItemType Directory -Path "$programFiles\eksctl" -Force
            }
            Copy-Item "$env:TEMP\eksctl\eksctl.exe" "$programFiles\eksctl\eksctl.exe" -Force
            $env:PATH += ";$programFiles\eksctl"
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
        }
        Write-Host "✅ eksctl installed successfully" -ForegroundColor Green
    }
}

Install-Eksctl