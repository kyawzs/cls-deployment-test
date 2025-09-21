# CLS Laravel Project Deployment Scripts

This repository contains improved deployment scripts for the CLS Laravel project, designed to work seamlessly with Ubuntu 22.04 and 24.04.

## 🚀 New Interactive Deployment Script

The main deployment script `deploy_cls.sh` is a comprehensive, interactive deployment tool that addresses all the issues from the original scripts:

### Key Improvements

1. **Single Interactive Script**: All deployment steps are now consolidated into one script with a user-friendly menu system
2. **Dynamic SSH Key Detection**: Automatically detects existing SSH keys instead of hardcoded `id_rsa.pub`
3. **User-Friendly Execution**: Works with both root and regular users (uses sudo when needed)
4. **Step-by-Step Execution**: Choose which steps to run or skip individual steps
5. **Ubuntu 22.04/24.04 Compatible**: Tested and optimized for both Ubuntu versions
6. **Comprehensive Error Handling**: Better error messages and validation
7. **Colored Output**: Easy-to-read status messages with color coding

## 📋 Prerequisites

- Ubuntu 22.04 or 24.04
- Internet connection
- Git repository access
- Domain name configured (for SSL setup)

## 🛠️ Quick Start

1. **Clone or download the deployment scripts**
2. **Create your environment configuration**:
   ```bash
   cp .env.example .env
   nano .env  # Edit with your configuration
   ```
3. **Make the script executable**:
   ```bash
   chmod +x deploy_cls.sh
   ```
4. **Run the deployment script**:
   ```bash
   ./deploy_cls.sh
   ```

## ⚙️ Configuration

Edit the `.env` file with your specific configuration:

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

## 🎯 Available Steps

The interactive script provides the following steps:

1. **Update System Packages** - Updates Ubuntu packages
2. **Install Services** - Installs Apache, MySQL, PHP, and dependencies
3. **Setup SSH Keys** - Configures SSH keys for Git access
4. **Configure Database** - Creates database and user
5. **Configure Laravel Project** - Clones and configures the Laravel application
6. **Setup SSL Certificate** - Configures Let's Encrypt SSL
7. **Setup Backup Cron Jobs** - Configures automated backups
8. **Setup Update Cron Job** - Configures automated system updates
9. **Install Traccar Server** - Installs Traccar GPS tracking server

## 🔧 Usage Options

### Interactive Mode
```bash
./deploy_cls.sh
```
- Shows a menu to select individual steps
- Allows skipping steps
- Provides confirmation prompts

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