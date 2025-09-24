## 🚀 Deployment Scripts

This repository contains two main deployment scripts for the CLS Laravel project, designed for Ubuntu 22.04 and 24.04.

1.  `deploy_cls.sh`: For traditional "bare-metal" deployments using Apache and MySQL directly on the host.
2.  `deploy_docker.sh`: For containerized deployments using Docker and Docker Compose.

### Key Improvements

- **Interactive Menus**: Both scripts provide user-friendly menus for step-by-step execution.
- **Dynamic SSH Key Detection**: Automatically detects existing SSH keys.
- **User-Friendly Execution**: Works with both `root` and regular users (uses `sudo` when needed).
- **Ubuntu 22.04/24.04 Compatible**: Tested and optimized for both Ubuntu versions.
- **Comprehensive Error Handling**: Better error messages and validation.
- **Colored Output**: Easy-to-read status messages with color coding.

## 📋 Prerequisites

- Ubuntu 22.04 or 24.04
- Internet connection
- Git repository access
- Domain name configured (for SSL setup)

## ⚙️ Configuration

Both scripts use a shared `.env` file for configuration.

1.  **Create your environment configuration**:
    ```bash
    cp .env.example .env
    nano .env # Edit with your configuration
    ```
2.  **Make the scripts executable**:
    ```bash
    chmod +x deploy_cls.sh
    chmod +x deploy_docker.sh
    ```

The `.env` file contains settings for domain, database, Git repository, and more.

```bash
# Domain configuration
domain=your-domain.com
contact=admin@your-domain.com

# Database configuration
db=cls_database
user=cls_user
pass=your_secure_password
db_host=localhost

# Git repository configuration
repo=https://github.com/your-org/your-repo.git
branch=main

# Traccar configuration (optional)
traccar_installer=https://github.com/traccar/traccar/releases/download/v5.8/traccar-linux-5.8.zip
```

## 🎯 Deployment Methods

### 1. Normal Deployment (`deploy_cls.sh`)

This script sets up the entire environment on the host machine.

**Usage:**

```bash
./deploy_cls.sh
```

**Features:**

- Installs Apache, MySQL, PHP, and other dependencies.
- Configures the database and Apache virtual host.
- Clones the project from your Git repository.
- Sets up Laravel, including migrations and key generation.
- Configures SSL using Let's Encrypt.
- Sets up cron jobs for backups and maintenance.
- Optionally installs Traccar server.

### 2. Docker Deployment (`deploy_docker.sh`)

This script automates the setup and management of a containerized CLS environment.

**Usage:**

```bash
./deploy_docker.sh
```

**Features:**

- **Automated Setup**: Installs Docker and Docker Compose, sets up SSH keys, and clones the project.
- **Environment Configuration**: Configures all necessary `.env` files for the Docker setup.
- **Multi-Profile Deployment**: Supports different deployment profiles:
  - `development`: Includes Mailhog for email testing.
  - `production`: Sets up an Nginx reverse proxy with SSL.
  - `traccar`: Includes the Traccar GPS service.
  - `basic`: A minimal setup with the application, database, and Redis.
- **Service Management**: Provides commands to `start`, `stop`, `restart`, `update`, and view `logs` for your Docker containers.

## 🔧 Usage Options

### Interactive Mode
```bash
./deploy_cls.sh
# or
./deploy_docker.sh
```
- Shows a menu to select individual steps.
- Allows running all steps at once or skipping to a specific step.
- Provides confirmation prompts before executing critical actions.

### Run All Steps
```bash
./deploy_cls.sh
# Select option 'a' for all steps
```

### Update Mode
```bash
./deploy_cls.sh update
```
- Runs only system updates (useful for cron jobs)

## 🔑 SSH Key Management

The script automatically handles SSH key detection and generation:

- **Detects existing keys**: Looks for `id_rsa.pub`, `id_ed25519.pub`, `id_ecdsa.pub`, or any `.pub` file
- **Generates new keys**: Creates `id_ed25519` key if none found
- **Shows public key**: Displays the public key for adding to GitHub/GitLab
- **Validates setup**: Confirms key is added to repository

## 👤 User Permissions

The script works with both root and regular users:

- **Root user**: Runs commands directly
- **Regular user**: Uses `sudo` for system operations
- **File permissions**: Properly sets ownership and permissions
- **ACL support**: Uses Access Control Lists for proper file access

## 🛡️ Security Features

- **Non-interactive mode**: Uses `DEBIAN_FRONTEND=noninteractive` for automated updates
- **Secure file permissions**: Sets appropriate permissions for sensitive files
- **Firewall configuration**: Configures UFW firewall rules
- **SSL/TLS support**: Automatic Let's Encrypt certificate setup

## 📁 Directory Structure

```
cls-deployment2/
├── deploy_cls.sh              # Main interactive deployment script
├── .env.example              # Environment configuration template
├── .env                      # Your environment configuration (create this)
├── data/
│   ├── 000-default.conf      # Apache virtual host template
│   ├── db.sql               # Database setup script
│   ├── db_backup.sh         # Database backup script
│   └── maintanance.sh       # Maintenance script
└── README.md                # This file
```

## 🔄 Legacy Scripts

The original numbered scripts are still available for reference:
- `1.setup_server.sh` - Original server setup
- `2.configure_project.sh` - Original project configuration
- `3.configure_ssl.sh` - Original SSL setup
- `4.setup_cron_job_backup_maintanance.sh` - Original backup cron
- `5.setup_cron_job_server_update.sh` - Original update cron
- `6.setup_traccar_server.sh` - Original Traccar setup

## 🐛 Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the script is executable (`chmod +x deploy_cls.sh`)
2. **SSH Key Issues**: The script will guide you through SSH key setup
3. **Database Connection**: Verify database credentials in `.env` file
4. **Domain Resolution**: Ensure DNS is configured before SSL setup

### Logs and Debugging

- Check Apache logs: `/var/log/apache2/`
- Check MySQL logs: `/var/log/mysql/`
- Check system logs: `journalctl -u apache2` or `journalctl -u mysql`

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify your `.env` configuration
3. Ensure all prerequisites are met
4. Check system logs for specific error messages

## 🔄 Updates

The script includes automatic update functionality:
- System updates run via cron job (yearly)
- Database backups run every 6 hours
- Maintenance runs weekly

## 📝 License

This deployment script is part of the CLS project. Please refer to the main project license for usage terms.

---

**Note**: Always backup your data before running deployment scripts in production environments.