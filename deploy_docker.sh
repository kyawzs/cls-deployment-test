#!/bin/bash

# CLS Docker Deployment Script
# This script deploys the CLS Laravel application using Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "${SCRIPT_DIR}"

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
        sudo apt install -y expect >/dev/null 2>&1
        
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

# Function to setup SSH keys
setup_ssh_keys() {
    print_step "Setting up SSH keys..."
    
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

# Function to clone Laravel project
clone_project() {
    print_step "Cloning Laravel project..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    # Remove existing project directory if it exists
    if [ -d "$project_dir" ]; then
        print_status "Removing existing project directory..."
        rm -rf "$project_dir"
    fi
    
    print_status "Adding GitHub to known hosts..."
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    
    print_status "Cloning repository..."
    git clone -b ${branch} ${repo} "$project_dir"
    
    # Set proper permissions
    chown -R $(whoami):$(whoami) "$project_dir"
    chmod -R 755 "$project_dir"
    
    print_status "Project cloned successfully!"
}

# Function to create Docker environment file
create_docker_env() {
    print_step "Creating Docker environment file..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    # Create .env file from Laravel template
    if [ -f ".env.example" ]; then
        print_status "Creating .env from Laravel template..."
        cp .env.example .env
    else
        print_error "Laravel .env.example not found!"
        return 1
    fi
    
    # Update .env with deployment configuration
    print_status "Updating environment configuration..."
    
    # Update APP_URL
    sed -i.bak "s|APP_URL=.*|APP_URL=https://${domain}|g" .env && rm .env.bak
    
    # Update database configuration
    sed -i.bak "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/g" .env && rm .env.bak
    sed -i.bak "s/DB_HOST=.*/DB_HOST=mysql-db/g" .env && rm .env.bak
    sed -i.bak "s/DB_PORT=.*/DB_PORT=3306/g" .env && rm .env.bak
    sed -i.bak "s/DB_DATABASE=.*/DB_DATABASE=${db}/g" .env && rm .env.bak
    sed -i.bak "s/DB_USERNAME=.*/DB_USERNAME=${user}/g" .env && rm .env.bak
    sed -i.bak "s/DB_PASSWORD=.*/DB_PASSWORD=${pass}/g" .env && rm .env.bak
    
    # Update mail configuration
    sed -i.bak "s/MAIL_FROM_ADDRESS=.*/MAIL_FROM_ADDRESS=${contact}/g" .env && rm .env.bak
    sed -i.bak "s/MAIL_FROM_NAME=.*/MAIL_FROM_NAME=\"CLS System\"/g" .env && rm .env.bak
    
    # Update cache configuration for Redis
    sed -i.bak "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/g" .env && rm .env.bak
    sed -i.bak "s/SESSION_DRIVER=.*/SESSION_DRIVER=redis/g" .env && rm .env.bak
    sed -i.bak "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/g" .env && rm .env.bak
    
    # Update Redis configuration
    sed -i.bak "s/REDIS_HOST=.*/REDIS_HOST=redis/g" .env && rm .env.bak
    sed -i.bak "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=/g" .env && rm .env.bak
    sed -i.bak "s/REDIS_PORT=.*/REDIS_PORT=6379/g" .env && rm .env.bak
    
    # Create Docker-specific environment file
    cat > .env.docker << EOF
# CLS Docker Environment Configuration
# Generated automatically from deployment configuration

# Application Configuration
APP_NAME=CLS
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://${domain}

# Domain Configuration
CLS_DOMAIN=${domain}
CLS_ADMIN_EMAIL=${contact}
CLS_PORT=8080
CLS_SSL_PORT=8443

# Database Configuration
DB_DATABASE=${db}
DB_USERNAME=${user}
DB_PASSWORD=${pass}
MYSQL_ROOT_PASSWORD=${pass}
MYSQL_PORT=3306

# Redis Configuration
REDIS_PASSWORD=
REDIS_PORT=6379

# Cache Configuration
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Mail Configuration
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=
MAIL_FROM_ADDRESS=${contact}
MAIL_FROM_NAME=CLS System

# PHP Configuration
PHP_MEMORY_LIMIT=512M
PHP_MAX_EXECUTION_TIME=300
PHP_UPLOAD_MAX_FILESIZE=200M
PHP_POST_MAX_SIZE=200M

# Traccar Configuration (Optional)
TRACCAR_DOMAIN=traccar.${domain}

# User Configuration
USER_ID=1000
GROUP_ID=1000
EOF
    
    print_status "Docker environment configuration completed!"
}

# Function to show menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "  CLS Docker Deployment Management"
    echo "=========================================="
    echo ""
    echo "Current Configuration:"
    echo "  Domain: ${domain:-'Not set'}"
    echo "  Database: ${db:-'Not set'}"
    echo "  Repository: ${repo:-'Not set'}"
    echo "  Branch: ${branch:-'Not set'}"
    echo ""
    echo "Available options:"
    echo "  1) Setup SSH keys"
    echo "  2) Clone Laravel project"
    echo "  3) Create Docker environment"
    echo "  4) Pull and start all services (with Nginx)"
    echo "  5) Pull and start services (without Nginx)"
    echo "  6) Start services (if already pulled)"
    echo "  7) Stop all services"
    echo "  8) Restart all services"
    echo "  9) Pull and restart"
    echo "  10) View logs"
    echo "  11) Access application shell"
    echo "  12) Access database shell"
    echo "  13) Clean up (remove containers and volumes)"
    echo "  d) Development mode (with Mailhog)"
    echo "  p) Production mode (with SSL)"
    echo "  t) Include Traccar service"
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

# Function to setup SSH keys
step_setup_ssh() {
    print_step "Setting up SSH keys..."
    
    if ! confirm_action "Setup SSH keys for Git access?"; then
        print_status "Skipping SSH setup..."
        return 0
    fi
    
    setup_ssh_keys
}

# Function to clone project
step_clone_project() {
    print_step "Cloning Laravel project..."
    
    if ! confirm_action "Clone Laravel project from repository?"; then
        print_status "Skipping project cloning..."
        return 0
    fi
    
    clone_project
}

# Function to create Docker environment
step_create_docker_env() {
    print_step "Creating Docker environment..."
    
    if ! confirm_action "Create Docker environment configuration?"; then
        print_status "Skipping Docker environment creation..."
        return 0
    fi
    
    create_docker_env
}

# Function to pull and start services
pull_and_start() {
    print_step "Pulling and starting CLS Docker services..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    # Pull and start services
    if command_exists docker-compose; then
        docker-compose pull
        docker-compose up -d
    else
        docker compose pull
        docker compose up -d
    fi
    
    print_status "Services started successfully!"
    print_status "Application should be available at: http://localhost:8080"
    print_status "Database is available at: localhost:3306"
    print_status "Redis is available at: localhost:6379"
}

# Function to pull and start services with Nginx
pull_and_start_with_nginx() {
    print_step "Pulling and starting CLS Docker services with Nginx proxy..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    # Pull and start services with Nginx
    if command_exists docker-compose; then
        docker-compose pull
        docker-compose --profile nginx up -d
    else
        docker compose pull
        docker compose --profile nginx up -d
    fi
    
    print_status "Services started successfully with Nginx!"
    print_status "Application should be available at: http://localhost:80"
    print_status "HTTPS should be available at: https://localhost:443"
    print_status "Database is available at: localhost:3306"
    print_status "Redis is available at: localhost:6379"
}

# Function to pull and start services without Nginx
pull_and_start_without_nginx() {
    print_step "Pulling and starting CLS Docker services without Nginx proxy..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    # Pull and start services without Nginx
    if command_exists docker-compose; then
        docker-compose pull
        docker-compose --profile app up -d
    else
        docker compose pull
        docker compose --profile app up -d
    fi
    
    print_status "Services started successfully without Nginx!"
    print_status "Application should be available at: http://localhost:8080"
    print_status "Database is available at: localhost:3306"
    print_status "Redis is available at: localhost:6379"
}

# Function to start services
start_services() {
    print_step "Starting CLS Docker services..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_status "Services started successfully!"
}

# Function to stop services
stop_services() {
    print_step "Stopping CLS Docker services..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        docker-compose down
    else
        docker compose down
    fi
    
    print_status "Services stopped successfully!"
}

# Function to restart services
restart_services() {
    print_step "Restarting CLS Docker services..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        docker-compose restart
    else
        docker compose restart
    fi
    
    print_status "Services restarted successfully!"
}

# Function to pull and restart
pull_restart() {
    print_step "Pulling and restarting CLS Docker services..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        docker-compose down
        docker-compose pull
        docker-compose up -d --force-recreate
    else
        docker compose down
        docker compose pull
        docker compose up -d --force-recreate
    fi
    
    print_status "Services pulled and restarted successfully!"
}

# Function to view logs
view_logs() {
    print_step "Viewing CLS Docker logs..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found."
        return 1
    fi
    
    cd "$project_dir"
    
    echo "Select service to view logs:"
    echo "1) Application (cls-app)"
    echo "2) Database (mysql-db)"
    echo "3) Redis (redis)"
    echo "4) Nginx (nginx)"
    echo "5) All services"
    
    read -p "Enter choice (1-5): " choice
    
    case $choice in
        1) service="cls-app" ;;
        2) service="mysql-db" ;;
        3) service="redis" ;;
        4) service="nginx" ;;
        5) service="" ;;
        *) print_error "Invalid choice"; return 1 ;;
    esac
    
    if command_exists docker-compose; then
        docker-compose logs -f $service
    else
        docker compose logs -f $service
    fi
}

# Function to access application shell
access_shell() {
    print_step "Accessing CLS application shell..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        docker-compose exec cls-app bash
    else
        docker compose exec cls-app bash
    fi
}

# Function to access database shell
access_database() {
    print_step "Accessing MySQL database shell..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        docker-compose exec mysql-db mysql -u root -p
    else
        docker compose exec mysql-db mysql -u root -p
    fi
}

# Function to clean up
cleanup() {
    print_step "Cleaning up CLS Docker environment..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found."
        return 1
    fi
    
    cd "$project_dir"
    
    print_warning "This will remove all containers, volumes, and images. Are you sure?"
    read -p "Type 'yes' to confirm: " confirm
    
    if [ "$confirm" = "yes" ]; then
        if command_exists docker-compose; then
            docker-compose down -v --rmi all
        else
            docker compose down -v --rmi all
        fi
        
        print_status "Cleanup completed!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Function to run in development mode
development_mode() {
    print_step "Starting in development mode with Mailhog..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        COMPOSE_PROFILES=development docker-compose pull
        COMPOSE_PROFILES=development docker-compose up -d
    else
        COMPOSE_PROFILES=development docker compose pull
        COMPOSE_PROFILES=development docker compose up -d
    fi
    
    print_status "Development services started!"
    print_status "Application: http://localhost:8080"
    print_status "Mailhog UI: http://localhost:8025"
}

# Function to run in production mode
production_mode() {
    print_step "Starting in production mode with SSL..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        COMPOSE_PROFILES=production docker-compose pull
        COMPOSE_PROFILES=production docker-compose up -d
    else
        COMPOSE_PROFILES=production docker compose pull
        COMPOSE_PROFILES=production docker compose up -d
    fi
    
    print_status "Production services started!"
    print_status "Application: https://${domain:-localhost}"
}

# Function to include Traccar
include_traccar() {
    print_step "Starting with Traccar GPS service..."
    
    local project_dir="${SCRIPT_DIR}/cls"
    
    if [ ! -d "$project_dir" ]; then
        print_error "Project directory not found. Please clone the project first."
        return 1
    fi
    
    cd "$project_dir"
    
    if command_exists docker-compose; then
        COMPOSE_PROFILES=traccar docker-compose pull
        COMPOSE_PROFILES=traccar docker-compose up -d
    else
        COMPOSE_PROFILES=traccar docker compose pull
        COMPOSE_PROFILES=traccar docker compose up -d
    fi
    
    print_status "Services with Traccar started!"
    print_status "Application: http://localhost:8080"
    print_status "Traccar: http://localhost:8082"
}

# Main execution function
main() {
    # Check if .env file exists and is valid
    check_env_file
    
    # Main interactive loop
    while true; do
        show_menu
        read -p "Select an option: " choice
        
        case $choice in
            1) step_setup_ssh ;;
            2) step_clone_project ;;
            3) step_create_docker_env ;;
            4) pull_and_start_with_nginx ;;
            5) pull_and_start_without_nginx ;;
            6) start_services ;;
            7) stop_services ;;
            8) restart_services ;;
            9) pull_restart ;;
            10) view_logs ;;
            11) access_shell ;;
            12) access_database ;;
            13) cleanup ;;
            d|D) development_mode ;;
            p|P) production_mode ;;
            t|T) include_traccar ;;
            q|Q) 
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
        
        if [ "$choice" != "q" ] && [ "$choice" != "Q" ]; then
            read -p "Press Enter to continue..."
        fi
    done
}

# Run main function
main "$@"