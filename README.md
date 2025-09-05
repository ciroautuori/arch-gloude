<div align="center">
  <h3>Automated Arch Linux provisioning with Docker on Google Cloud</h3>
  <p>One-command deployment • Optimized for performance • Beautiful CLI output</p>
</div>
<div align="center">
  <img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch Linux">
  <img src="https://img.shields.io/badge/Docker-2CA5E0?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white" alt="Google Cloud">
  <img src="https://img.shields.io/badge/Bash_Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
</div>

## ✨ Features

- **One-Command Setup** - Fully automated provisioning with `./main.sh --auto`
- **Optimized Performance** - Pre-configured with best practices for Arch Linux
- **Beautiful CLI** - Elegant, color-coded output with progress tracking
- **Modular Design** - Easy to customize and extend
- **Secure by Default** - Proper user permissions and security settings

## 🚀 Quick Start

### Prerequisites

- Google Cloud SDK installed and configured
- Billing enabled on your Google Cloud account
- Sufficient permissions to create VM instances

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/arch-linux-provisioner.git
cd arch-linux-provisioner

# Make the scripts executable
chmod +x main.sh scripts/*.sh

# Copy and edit the configuration
cp config/settings.conf.example config/settings.conf
nano config/settings.conf
```

### Usage

```bash
# Start the provisioning (interactive mode)
./main.sh

# Or run in fully automated mode
./main.sh --auto
```

## 🛠️ Configuration

Edit `config/settings.conf` to customize:

```ini
# VM Configuration
VM_NAME="paclab-dev"
ZONE="europe-west1-b"
MACHINE_TYPE="e2-medium"
DISK_SIZE="30"
DISK_TYPE="pd-ssd"

# Network Settings
TAGS="docker-host,http-server,https-server"

# System Configuration
TIMEZONE="Europe/Rome"
LOCALE="en_US.UTF-8"
KEYMAP="it"

# User Configuration
USERNAME="$(whoami)"
USER_EMAIL="user@example.com"
```

## 📦 Included Packages

- **Essentials**: Docker, Docker Compose, Git, Curl, Wget
- **Development**: Python, pip, Poetry, pipx
- **System Tools**: htop, rsync, jq, unzip, zip
- **Security**: fail2ban, UFW (Uncomplicated Firewall)

## 🔄 Workflow

1. **VM Creation** - Creates an Arch Linux VM on Google Cloud
2. **System Setup** - Configures pacman, updates the system, and installs packages
3. **Docker Setup** - Installs and configures Docker with proper permissions
4. **User Environment** - Sets up the user environment with Starship prompt
5. **Verification** - Runs tests to ensure everything is working correctly

## 🎯 Example Output

```
╔══════════════════════════════════════════════════════════════╗
║                 ARCH LINUX PROVISIONING                      ║
╚══════════════════════════════════════════════════════════════╝

✓ Creating VM: paclab-dev in zone europe-west1-b
✓ Updating system packages...
✓ Installing Docker and dependencies...
✓ Configuring user environment...
✓ Verification completed successfully!

Your Arch Linux environment is ready!
SSH Access: gcloud compute ssh paclab-dev --zone=europe-west1-b
```

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Arch Linux](https://archlinux.org/)
- [Google Cloud Platform](https://cloud.google.com/)
- [Docker](https://www.docker.com/)
- [Starship](https://starship.rs/)

---

<div align="center">
  Made with ❤️ by Ciro Autuori 
</div>
