#!/bin/bash

# CLS Laravel Project Deployment Script
# Compatible with Ubuntu 22.04 and 24.04
# Supports both root and regular user execution with sudo

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "${SCRIPT_DIR}"

# Check if running as root
IS_ROOT=false
if [ "$EUID" -eq 0 ]; then
    IS_ROOT=true
    echo -e "${YELLOW}Warning: Running as root. Consider using a regular user with sudo privileges.${NC}"
fi

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect SSH key files dynamically
detect_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local key_file=""
    
    if [ ! -d "$ssh_dir" ]; then
        return 1
    fi
    
    # Look for common SSH key patterns
    for pattern in "id_rsa.pub" "id_ed25519.pub" "id_ecdsa.pub" "id_dsa.pub"; do
        if [ -f "$ssh_dir/$pattern" ]; then
            key_file="$ssh_dir/$pattern"
            break
        fi
    done
    
    # If no standard key found, look for any .pub file
    if [ -z "$key_file" ]; then
        key_file=$(find "$ssh_dir" -name "*.pub" -type f | head -n 1)
    fi
    
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
        echo "$key_file"
        return 0
    else
        return 1
    fi
}

# Function to generate SSH key if none exists
generate_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    
    if [ ! -d "$ssh_dir" ]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi
    
    print_status "Generating new SSH key..."
    
    # Check if expect is available for interactive key generation
    if command_exists expect; then
        # Use expect for interactive key generation
        expect >/dev/null 2>&1 << EOF
spawn ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -C "$(whoami)@$(hostname)"
expect "Enter passphrase (empty for no passphrase):"
send "\r"
expect "Enter same passphrase again:"
send "\r"
expect eof
EOF
    else
        # Fallback: try to generate with empty passphrase
        print_status "Installing expect for SSH key generation..."
        run_with_sudo apt install -y expect >/dev/null 2>&1
        
        expect >/dev/null 2>&1 << EOF
spawn ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -C "$(whoami)@$(hostname)"
expect "Enter passphrase (empty for no passphrase):"
send "\r"
expect "Enter same passphrase again:"
send "\r"
expect eof
EOF
    fi
    
    # Verify the key was created
    if [ -f "$ssh_dir/id_ed25519.pub" ]; then
        print_status "SSH key generated successfully"
    else
        print_error "Failed to generate SSH key"
        return 1
    fi
    
    # Return the generated key file
    echo "$ssh_dir/id_ed25519.pub"
}

# Function to check environment file
check_env_file() {
    if [ ! -f ".env" ]; then
        print_error ".env file not found!"
        print_status "Creating .env template file..."
        create_env_template
        print_warning "Please edit .env file with your configuration before running the script again."
        exit 1
    fi
    
    # Source the environment file
    source .env
    
    # Validate required variables
    local required_vars=("domain" "db" "user" "pass" "contact" "repo" "branch")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        print_warning "Please check your .env file and ensure all required variables are set."
        exit 1
    fi
}

# Function to create .env template
create_env_template() {
    cat > .env << 'EOF'
# CLS Deployment Configuration
# Please update these values according to your setup

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
EOF
    chmod 600 .env
}

# Function to run command with appropriate permissions
run_with_sudo() {
    if [ "$IS_ROOT" = true ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Function to show initial deployment choice
show_initial_choice() {
    echo ""
    echo "=========================================="
    echo "  CLS Laravel Project Deployment Script  "
    echo "=========================================="
    echo ""
    echo "Current Configuration:"
    echo "  Domain: ${domain:-'Not set'}"
    echo "  Database: ${db:-'Not set'}"
    echo "  Database User: ${user:-'Not set'}"
    echo "  Admin Email: ${contact:-'Not set'}"
    echo "  Repository: ${repo:-'Not set'}"
    echo "  Branch: ${branch:-'Not set'}"
    echo ""
    echo "Choose deployment method:"
    echo "  1) Normal Deployment (Apache + MySQL on host)"
    echo "  2) Docker Deployment (Containerized)"
    echo "  q) Quit"
    echo ""
}

# Function to show normal deployment menu
show_normal_menu() {
    echo ""
    echo "=========================================="
    echo "  CLS Normal Deployment Steps"
    echo "=========================================="
    echo ""
    echo "Available Steps:"
    echo "  1) Update system packages"
    echo "  2) Install Apache, MySQL, PHP and dependencies"
    echo "  3) Setup SSH keys"
    echo "  4) Configure database"
    echo "  5) Clone Laravel project"
    echo "  6) Configure Laravel project"
    echo "  7) Setup SSL certificate"
    echo "  8) Setup backup and maintenance cron jobs"
    echo "  9) Setup server update cron job"
    echo "  10) Install Traccar server"
    echo "  a) Run all steps"
    echo "  s) Skip to specific step"
    echo "  b) Back to main menu"
    echo "  q) Quit"
    echo ""
}

# Function to show Docker deployment menu
show_docker_menu() {
    echo ""
    echo "=========================================="
    echo "  CLS Docker Deployment Steps"
    echo "=========================================="
    echo ""
    echo "Available Steps:"
    echo "  1) Update system packages"
    echo "  2) Install Docker and Docker Compose"
    echo "  3) Setup SSH keys"
    echo "  4) Clone Laravel project"
    echo "  5) Configure Docker environment"
    echo "  6) Deploy with Docker"
    echo "  7) Setup Traccar service (optional)"
    echo "  a) Run all steps"
    echo "  s) Skip to specific step"
    echo "  b) Back to main menu"
    echo "  q) Quit"
    echo ""
}

# Function to confirm action
confirm_action() {
    local message="$1"
    read -p "$message (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Step 1: Update system packages
step_update_system() {
    print_step "Updating system packages..."
    
    if ! confirm_action "Update system packages?"; then
        print_status "Skipping system update..."
        return 0
    fi
    
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    
    print_status "Updating package lists..."
    run_with_sudo apt-get -qy update
    
    print_status "Upgrading packages..."
    run_with_sudo apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
    
    print_status "Cleaning up..."
    run_with_sudo apt-get -qy autoclean
    
    print_status "System update completed!"
}

# Step 2: Install Apache, MySQL, PHP and dependencies
step_install_services() {
    print_step "Installing Apache, MySQL, PHP and dependencies..."
    
    if ! confirm_action "Install web server and database?"; then
        print_status "Skipping service installation..."
        return 0
    fi
    
    print_status "Installing Apache web server..."
    run_with_sudo apt install -y apache2
    
    print_status "Configuring firewall..."
    run_with_sudo ufw allow 'Apache Full'
    run_with_sudo ufw reload
    
    print_status "Installing MySQL database server..."
    run_with_sudo apt install -y mysql-server
    
    print_status "Installing PHP and extensions..."
    run_with_sudo apt install -y php libapache2-mod-php php-mysql php-common php-xml php-xmlrpc php-curl php-gd php-imagick php-cli php-dev php-imap php-mbstring php-opcache php-soap php-zip php-intl
    
    print_status "Installing Composer..."
    run_with_sudo apt install -y curl
    curl -s https://getcomposer.org/installer | php
    run_with_sudo mv composer.phar /usr/bin/composer
    
    print_status "Installing Certbot for SSL..."
    run_with_sudo apt install -y python3-certbot-apache
    
    print_status "Enabling Apache modules..."
    run_with_sudo a2enmod ssl proxy_http proxy_wstunnel rewrite
    run_with_sudo a2dissite 000-default
    
    print_status "Service installation completed!"
}

# Step 3: Setup SSH keys
step_setup_ssh() {
    print_step "Setting up SSH keys..."
    
    if ! confirm_action "Setup SSH keys?"; then
        print_status "Skipping SSH setup..."
        return 0
    fi
    
    # Add GitHub to known hosts
    print_status "Adding GitHub to known hosts..."
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    
    # Detect existing SSH key
    local ssh_key
    if ssh_key=$(detect_ssh_key); then
        print_status "Found existing SSH key: $ssh_key"
        echo ""
        print_status "Your public SSH key:"
        cat "$ssh_key"
        echo ""
        print_warning "Please add this key to your GitHub repository deployment keys if not already done."
    else
        print_status "No SSH key found. Generating new key..."
        ssh_key=$(generate_ssh_key)
        print_status "Generated new SSH key: $ssh_key"
        echo ""
        print_status "Your public SSH key:"
        cat "$ssh_key"
        echo ""
        print_warning "Please add this key to your GitHub repository deployment keys."
    fi
    
    if ! confirm_action "Have you added the SSH key to your repository?"; then
        print_warning "Please add the SSH key to your repository and run this step again."
        return 1
    fi
    
    print_status "SSH setup completed!"
}

# Step 4: Configure database
step_configure_database() {
    print_step "Configuring database..."
    
    if ! confirm_action "Configure database?"; then
        print_status "Skipping database configuration..."
        return 0
    fi
    
    print_status "Setting up environment variables in database script..."
    sed -i "s/__DOMAIN__/${domain}/g" ./data/db.sql
    sed -i "s/__DB__/${db}/g" ./data/db.sql
    sed -i "s/__USER__/${user}/g" ./data/db.sql
    sed -i "s/__PASS__/${pass}/g" ./data/db.sql
    
    print_status "Creating database and user..."
    run_with_sudo mysql < ./data/db.sql
    
    print_status "Database configuration completed!"
}

# Step 5: Clone Laravel project
step_clone_project() {
    print_step "Cloning Laravel project..."
    
    if ! confirm_action "Clone Laravel project from repository?"; then
        print_status "Skipping project cloning..."
        return 0
    fi
    
    print_status "Setting up directory permissions..."
    run_with_sudo chown -R www-data: /var/www/
    run_with_sudo apt-get install -y acl
    run_with_sudo setfacl -R -m u:$(whoami):rwx /var/www
    
    print_status "Adding GitHub to known hosts..."
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    
    # Clone or update repository
    local project_dir="/var/www/${domain}"
    if [ -d "$project_dir" ]; then
        print_status "Project directory exists. Updating..."
        cd "$project_dir"
        git stash
        git pull origin ${branch}
    else
        print_status "Cloning repository..."
        git clone -b ${branch} ${repo} "$project_dir"
        run_with_sudo git config --global --add safe.directory "$project_dir"
    fi
    
    print_status "Project cloning completed!"
}

# Step 6: Configure Laravel project
step_configure_project() {
    print_step "Configuring Laravel project..."
    
    if ! confirm_action "Configure Laravel project?"; then
        print_status "Skipping project configuration..."
        return 0
    fi
    
    local project_dir="/var/www/${domain}"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    print_status "Configuring Apache virtual host..."
    run_with_sudo cp ${SCRIPT_DIR}/data/000-default.conf /etc/apache2/sites-available/${domain}.conf
    run_with_sudo sed -i "s/__DOMAIN__/${domain}/g" /etc/apache2/sites-available/${domain}.conf
    run_with_sudo sed -i "s/__CONTACT__/${contact}/g" /etc/apache2/sites-available/${domain}.conf
    
    print_status "Enabling site..."
    run_with_sudo a2ensite ${domain}
    
    print_status "Configuring Laravel environment..."
    cp ./.env.example ./.env
    
    # Update Laravel .env file with proper database configuration
    print_status "Updating database configuration in .env file..."
    
    # Update APP_URL
    sed -i.bak "s|APP_URL=.*|APP_URL=https://${domain}|g" ./.env && rm ./.env.bak
    
    # Update database configuration
    sed -i.bak "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/g" ./.env && rm ./.env.bak
    sed -i.bak "s/DB_HOST=.*/DB_HOST=${db_host:-localhost}/g" ./.env && rm ./.env.bak
    sed -i.bak "s/DB_PORT=.*/DB_PORT=3306/g" ./.env && rm ./.env.bak
    sed -i.bak "s/DB_DATABASE=.*/DB_DATABASE=${db}/g" ./.env && rm ./.env.bak
    sed -i.bak "s/DB_USERNAME=.*/DB_USERNAME=${user}/g" ./.env && rm ./.env.bak
    sed -i.bak "s/DB_PASSWORD=.*/DB_PASSWORD=${pass}/g" ./.env && rm ./.env.bak
    
    # Update mail configuration
    sed -i.bak "s/MAIL_FROM_ADDRESS=.*/MAIL_FROM_ADDRESS=${contact}/g" ./.env && rm ./.env.bak
    sed -i.bak "s/MAIL_FROM_NAME=.*/MAIL_FROM_NAME=\"CLS System\"/g" ./.env && rm ./.env.bak
    
    # Verify the configuration was applied correctly
    print_status "Verifying .env configuration..."
    if grep -q "DB_DATABASE=${db}" ./.env && grep -q "DB_USERNAME=${user}" ./.env && grep -q "DB_PASSWORD=${pass}" ./.env; then
        print_status "Database configuration updated successfully"
    else
        print_warning "Database configuration may not have been updated correctly"
        print_status "Current database settings:"
        grep -E "^DB_(HOST|PORT|DATABASE|USERNAME|PASSWORD)=" ./.env || true
    fi
    
    print_status "Creating upload directories..."
    local upload_dirs=("public/upload" "public/upload/import" "public/upload/export" "public/upload/temp" "public/upload/library" "public/upload/location" "public/upload/srf")
    for dir in "${upload_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            run_with_sudo mkdir -p "$dir"
        fi
    done
    
    print_status "Setting up directory permissions..."
    run_with_sudo chown -R www-data:www-data "$project_dir"
    run_with_sudo chmod -R 755 "$project_dir"
    run_with_sudo chown -R www-data:www-data "$project_dir/public/upload"
    run_with_sudo chmod -R 777 "$project_dir/public/upload"
    run_with_sudo setfacl -R -m u:$(whoami):rwx /var/www
    
    print_status "Installing Composer dependencies..."
    composer install --no-dev --optimize-autoloader
    
    print_status "Running database migrations..."
    php artisan migrate --force
    
    print_status "Generating application key..."
    php artisan key:generate --force
    
    print_status "Generating Passport keys..."
    php artisan passport:install --force
    
    print_status "Running seed data..."
    run_with_sudo mysql ${db} < "$project_dir/database/sqls/seed.sql" 2>/dev/null || print_warning "Seed file not found, skipping..."
    
    print_status "Reloading Apache..."
    run_with_sudo systemctl reload apache2
    
    print_status "Project configuration completed!"
}

# Step 6: Setup SSL certificate
step_setup_ssl() {
    print_step "Setting up SSL certificate..."
    
    if ! confirm_action "Setup SSL certificate?"; then
        print_status "Skipping SSL setup..."
        return 0
    fi
    
    print_status "Checking domain resolution..."
    if ! host ${domain} > /dev/null 2>&1; then
        print_warning "Domain ${domain} does not resolve. Please ensure DNS is configured before setting up SSL."
        if ! confirm_action "Continue with SSL setup anyway?"; then
            return 0
        fi
    fi
    
    print_status "Setting up SSL certificate with Let's Encrypt..."
    run_with_sudo certbot --apache --agree-tos --redirect -m ${contact} -d ${domain}
    
    print_status "Restarting Apache..."
    run_with_sudo systemctl restart apache2
    
    print_status "SSL setup completed!"
}

# Step 7: Setup backup and maintenance cron jobs
step_setup_backup_cron() {
    print_step "Setting up backup and maintenance cron jobs..."
    
    if ! confirm_action "Setup backup and maintenance cron jobs?"; then
        print_status "Skipping cron job setup..."
        return 0
    fi
    
    print_status "Setting up database backup script..."
    chmod +x ${SCRIPT_DIR}/data/db_backup.sh
    
    print_status "Setting up maintenance script..."
    chmod +x ${SCRIPT_DIR}/data/maintanance.sh
    
    print_status "Adding cron jobs..."
    (crontab -l 2>/dev/null; echo "0 */6 * * * ${SCRIPT_DIR}/data/db_backup.sh >/dev/null 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "0 0 * * 0 ${SCRIPT_DIR}/data/maintanance.sh >/dev/null 2>&1") | crontab -
    
    print_status "Cron jobs setup completed!"
}

# Step 8: Setup server update cron job
step_setup_update_cron() {
    print_step "Setting up server update cron job..."
    
    if ! confirm_action "Setup server update cron job?"; then
        print_status "Skipping update cron job setup..."
        return 0
    fi
    
    print_status "Adding server update cron job..."
    (crontab -l 2>/dev/null; echo "0 0 1 1 * ${SCRIPT_DIR}/deploy_cls.sh update >/dev/null 2>&1") | crontab -
    
    print_status "Update cron job setup completed!"
}

# Step 9: Install Traccar server
step_install_traccar() {
    print_step "Installing Traccar server..."
    
    if ! confirm_action "Install Traccar server?"; then
        print_status "Skipping Traccar installation..."
        return 0
    fi
    
    local traccar_dir="${SCRIPT_DIR}/data/traccar"
    
    if [ -d "$traccar_dir" ]; then
        print_warning "Traccar server already installed. Please uninstall manually and try again."
        return 1
    fi
    
    print_status "Preparing Traccar directory..."
    run_with_sudo ufw allow 8082
    run_with_sudo ufw allow 5093
    run_with_sudo ufw reload
    
    mkdir -p "$traccar_dir"
    cd "$traccar_dir"
    
    print_status "Downloading Traccar installer..."
    wget "${traccar_installer:-https://github.com/traccar/traccar/releases/download/v5.8/traccar-linux-5.8.zip}"
    
    print_status "Extracting installer..."
    unzip *.zip
    
    print_status "Installing Traccar server..."
    run_with_sudo ./traccar.run
    run_with_sudo systemctl start traccar
    
    print_status "Traccar server installation completed!"
    print_warning "Please contact hosting administrator to enable network ports:"
    print_warning "  PORT 8082 TCP INBOUND"
    print_warning "  PORT 8082 UDP INBOUND"
    print_warning "  PORT 8082 UDP OUTBOUND"
}

# Docker Step 2: Install Docker and Docker Compose
step_install_docker() {
    print_step "Installing Docker and Docker Compose..."
    
    if ! confirm_action "Install Docker and Docker Compose?"; then
        print_status "Skipping Docker installation..."
        return 0
    fi
    
    # Check if Docker is already installed
    if command_exists docker; then
        print_status "Docker is already installed."
    else
        print_status "Installing Docker..."
        run_with_sudo apt-get update
        run_with_sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | run_with_sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | run_with_sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        run_with_sudo apt-get update
        run_with_sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Add user to docker group
        run_with_sudo usermod -aG docker $(whoami)
        
        print_status "Docker installed successfully!"
    fi
    
    # Check if Docker Compose is installed
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        print_status "Docker Compose is already installed."
    else
        print_status "Installing Docker Compose..."
        run_with_sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        run_with_sudo chmod +x /usr/local/bin/docker-compose
        
        print_status "Docker Compose installed successfully!"
    fi
    
    # Start and enable Docker
    run_with_sudo systemctl start docker
    run_with_sudo systemctl enable docker
    
    print_status "Docker installation completed!"
    print_warning "You may need to log out and log back in for Docker group changes to take effect."
}

# Docker Step 4: Clone Laravel project for Docker
step_clone_project_docker() {
    print_step "Cloning Laravel project for Docker deployment..."
    
    if ! confirm_action "Clone Laravel project from repository?"; then
        print_status "Skipping project cloning..."
        return 0
    fi
    
    print_status "Adding GitHub to known hosts..."
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    
    # Clone repository to a temporary directory first
    local temp_dir="/tmp/cls-temp"
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
    
    print_status "Cloning repository to temporary directory..."
    git clone -b ${branch} ${repo} "$temp_dir"
    
    # Move to final location
    if [ -d "$project_dir" ]; then
        print_status "Backing up existing project directory..."
        mv "$project_dir" "${project_dir}.backup.$(date +%s)"
    fi
    
    print_status "Moving project to final location..."
    mv "$temp_dir" "$project_dir"
    
    # Set proper permissions
    chown -R $(whoami):$(whoami) "$project_dir"
    chmod -R 755 "$project_dir"
    
    print_status "Project cloning completed!"
}

# Docker Step 5: Configure Docker environment
step_configure_docker_env() {
    print_step "Configuring Docker environment..."
    
    if ! confirm_action "Configure Docker environment files?"; then
        print_status "Skipping Docker environment configuration..."
        return 0
    fi
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    # Create .env file from template
    if [ ! -f ".env" ]; then
        if [ -f ".env.docker" ]; then
            print_status "Creating .env file from Docker template..."
            cp .env.docker .env
        else
            print_error "Docker environment template not found!"
            return 1
        fi
    fi
    
    # Update .env with deployment configuration
    print_status "Updating environment configuration..."
    sed -i.bak "s/your-domain.com/${domain}/g" .env && rm .env.bak
    sed -i.bak "s/admin@your-domain.com/${contact}/g" .env && rm .env.bak
    sed -i.bak "s/cls_database/${db}/g" .env && rm .env.bak
    sed -i.bak "s/cls_user/${user}/g" .env && rm .env.bak
    sed -i.bak "s/your_secure_password/${pass}/g" .env && rm .env.bak
    sed -i.bak "s/your_root_password/${pass}/g" .env && rm .env.bak
    
    print_status "Docker environment configuration completed!"
    print_warning "Please review and edit .env file if needed:"
    print_status "File location: ${project_dir}/.env"
}

# Docker Step 6: Deploy with Docker
step_deploy_docker() {
    print_step "Deploying with Docker..."
    
    if ! confirm_action "Deploy CLS application using Docker?"; then
        print_status "Skipping Docker deployment..."
        return 0
    fi
    
    # Check if Docker is installed and running
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        return 1
    fi
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    # Ask for deployment mode
    echo ""
    echo "Select Docker deployment mode:"
    echo "  1) Development (with Mailhog for email testing)"
    echo "  2) Production (with SSL and Nginx)"
    echo "  3) With Traccar GPS service"
    echo "  4) Basic (just application, database, and Redis)"
    
    read -p "Enter choice (1-4): " docker_choice
    
    case $docker_choice in
        1)
            print_status "Starting in development mode..."
            if command_exists docker-compose; then
                COMPOSE_PROFILES=development docker-compose up -d --build
            else
                COMPOSE_PROFILES=development docker compose up -d --build
            fi
            ;;
        2)
            print_status "Starting in production mode..."
            if command_exists docker-compose; then
                COMPOSE_PROFILES=production docker-compose up -d --build
            else
                COMPOSE_PROFILES=production docker compose up -d --build
            fi
            ;;
        3)
            print_status "Starting with Traccar service..."
            if command_exists docker-compose; then
                COMPOSE_PROFILES=traccar docker-compose up -d --build
            else
                COMPOSE_PROFILES=traccar docker compose up -d --build
            fi
            ;;
        4)
            print_status "Starting basic services..."
            if command_exists docker-compose; then
                docker-compose up -d --build
            else
                docker compose up -d --build
            fi
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    print_status "Docker deployment completed!"
    print_status "Application should be available at: http://localhost:8080"
    print_status "Database is available at: localhost:3306"
    print_status "Redis is available at: localhost:6379"
    
    if [ "$docker_choice" = "1" ]; then
        print_status "Mailhog UI: http://localhost:8025"
    fi
    
    if [ "$docker_choice" = "3" ]; then
        print_status "Traccar GPS: http://localhost:8082"
    fi
    
    print_status "Use './deploy_docker.sh' for Docker management commands"
}

# Function to run normal deployment
run_normal_deployment() {
    while true; do
        show_normal_menu
        read -p "Select an option: " choice
        
        case $choice in
            1) step_update_system ;;
            2) step_install_services ;;
            3) step_setup_ssh ;;
            4) step_configure_database ;;
            5) step_clone_project ;;
            6) step_configure_project ;;
            7) step_setup_ssl ;;
            8) step_setup_backup_cron ;;
            9) step_setup_update_cron ;;
            10) step_install_traccar ;;
            a|A) 
                print_status "Running all normal deployment steps..."
                step_update_system
                step_install_services
                step_setup_ssh
                step_configure_database
                step_clone_project
                step_configure_project
                step_setup_ssl
                step_setup_backup_cron
                step_setup_update_cron
                print_status "All normal deployment steps completed!"
                break
                ;;
            s|S)
                read -p "Enter step number to skip to (1-10): " skip_to
                case $skip_to in
                    1) step_update_system ;;
                    2) step_install_services ;;
                    3) step_setup_ssh ;;
                    4) step_configure_database ;;
                    5) step_clone_project ;;
                    6) step_configure_project ;;
                    7) step_setup_ssl ;;
                    8) step_setup_backup_cron ;;
                    9) step_setup_update_cron ;;
                    10) step_install_traccar ;;
                    *) print_error "Invalid step number" ;;
                esac
                ;;
            b|B) return 0 ;;
            q|Q) exit 0 ;;
            *) print_error "Invalid option. Please try again." ;;
        esac
        
        if [ "$choice" != "a" ] && [ "$choice" != "A" ] && [ "$choice" != "b" ] && [ "$choice" != "B" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# Function to run Docker deployment
run_docker_deployment() {
    while true; do
        show_docker_menu
        read -p "Select an option: " choice
        
        case $choice in
            1) step_update_system ;;
            2) step_install_docker ;;
            3) step_setup_ssh ;;
            4) step_clone_project_docker ;;
            5) step_configure_docker_env ;;
            6) step_deploy_docker ;;
            7) step_install_traccar ;;
            a|A) 
                print_status "Running all Docker deployment steps..."
                step_update_system
                step_install_docker
                step_setup_ssh
                step_clone_project_docker
                step_configure_docker_env
                step_deploy_docker
                print_status "All Docker deployment steps completed!"
                break
                ;;
            s|S)
                read -p "Enter step number to skip to (1-7): " skip_to
                case $skip_to in
                    1) step_update_system ;;
                    2) step_install_docker ;;
                    3) step_setup_ssh ;;
                    4) step_clone_project_docker ;;
                    5) step_configure_docker_env ;;
                    6) step_deploy_docker ;;
                    7) step_install_traccar ;;
                    *) print_error "Invalid step number" ;;
                esac
                ;;
            b|B) return 0 ;;
            q|Q) exit 0 ;;
            *) print_error "Invalid option. Please try again." ;;
        esac
        
        if [ "$choice" != "a" ] && [ "$choice" != "A" ] && [ "$choice" != "b" ] && [ "$choice" != "B" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# Main execution function
main() {
    # Check if .env file exists and is valid
    check_env_file
    
    # Handle update mode
    if [ "$1" = "update" ]; then
        print_status "Running in update mode..."
        step_update_system
        exit 0
    fi
    
    print_status "Starting normal deployment..."
    run_normal_deployment
}

# Run main function
main "$@"
