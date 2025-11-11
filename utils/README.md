# Utility Scripts

## Purpose
Separate installation and check scripts to keep main deployment scripts clean and focused.

## Scripts

### Linux/macOS
- `install-eksctl.sh` - Installs eksctl if missing
- `install-kubectl.sh` - Installs kubectl if missing

### Windows
- `install-eksctl.ps1` - Installs eksctl if missing  
- `install-kubectl.ps1` - Installs kubectl if missing

## Usage
These scripts are automatically called by the main setup scripts:
- `linux/setup-infrastructure.sh` calls the .sh versions
- `windows/windows-setup-infrastructure.ps1` calls the .ps1 versions

## Make Scripts Executable (Linux/macOS)
```bash
chmod +x utils/*.sh
```