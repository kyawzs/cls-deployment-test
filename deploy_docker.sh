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

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Function to create environment file
create_env_file() {
    print_step "Setting up environment configuration..."
    
    local env_file="${SCRIPT_DIR}/cls/.env"
    local env_template="${SCRIPT_DIR}/cls/.env.docker"
    
    if [ ! -f "$env_file" ]; then
        if [ -f "$env_template" ]; then
            print_status "Creating .env file from template..."
            cp "$env_template" "$env_file"
            print_warning "Please edit ${env_file} with your configuration before continuing."
            read -p "Press Enter after editing the .env file..."
        else
            print_error "Environment template not found at ${env_template}"
            exit 1
        fi
    else
        print_status "Environment file already exists."
    fi
}

# Function to show menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "  CLS Docker Deployment Script"
    echo "=========================================="
    echo ""
    echo "Available options:"
    echo "  1) Build and start all services"
    echo "  2) Start services (if already built)"
    echo "  3) Stop all services"
    echo "  4) Restart all services"
    echo "  5) Rebuild and restart"
    echo "  6) View logs"
    echo "  7) Access application shell"
    echo "  8) Access database shell"
    echo "  9) Clean up (remove containers and volumes)"
    echo "  d) Development mode (with Mailhog)"
    echo "  p) Production mode (with SSL)"
    echo "  t) Include Traccar service"
    echo "  q) Quit"
    echo ""
}

# Function to build and start services
build_and_start() {
    print_step "Building and starting CLS Docker services..."
    
    cd "${SCRIPT_DIR}/cls"
    
    # Build and start services
    if command_exists docker-compose; then
        docker-compose up -d --build
    else
        docker compose up -d --build
    fi
    
    print_status "Services started successfully!"
    print_status "Application should be available at: http://localhost:8080"
    print_status "Database is available at: localhost:3306"
    print_status "Redis is available at: localhost:6379"
}

# Function to start services
start_services() {
    print_step "Starting CLS Docker services..."
    
    cd "${SCRIPT_DIR}/cls"
    
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
    
    cd "${SCRIPT_DIR}/cls"
    
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
    
    cd "${SCRIPT_DIR}/cls"
    
    if command_exists docker-compose; then
        docker-compose restart
    else
        docker compose restart
    fi
    
    print_status "Services restarted successfully!"
}

# Function to rebuild and restart
rebuild_restart() {
    print_step "Rebuilding and restarting CLS Docker services..."
    
    cd "${SCRIPT_DIR}/cls"
    
    if command_exists docker-compose; then
        docker-compose down
        docker-compose up -d --build --force-recreate
    else
        docker compose down
        docker compose up -d --build --force-recreate
    fi
    
    print_status "Services rebuilt and restarted successfully!"
}

# Function to view logs
view_logs() {
    print_step "Viewing CLS Docker logs..."
    
    cd "${SCRIPT_DIR}/cls"
    
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
    
    cd "${SCRIPT_DIR}/cls"
    
    if command_exists docker-compose; then
        docker-compose exec cls-app bash
    else
        docker compose exec cls-app bash
    fi
}

# Function to access database shell
access_database() {
    print_step "Accessing MySQL database shell..."
    
    cd "${SCRIPT_DIR}/cls"
    
    if command_exists docker-compose; then
        docker-compose exec mysql-db mysql -u root -p
    else
        docker compose exec mysql-db mysql -u root -p
    fi
}

# Function to clean up
cleanup() {
    print_step "Cleaning up CLS Docker environment..."
    
    cd "${SCRIPT_DIR}/cls"
    
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
    
    cd "${SCRIPT_DIR}/cls"
    
    if command_exists docker-compose; then
        COMPOSE_PROFILES=development docker-compose up -d --build
    else
        COMPOSE_PROFILES=development docker compose up -d --build
    fi
    
    print_status "Development services started!"
    print_status "Application: http://localhost:8080"
    print_status "Mailhog UI: http://localhost:8025"
}

# Function to run in production mode
production_mode() {
    print_step "Starting in production mode with SSL..."
    
    cd "${SCRIPT_DIR}/cls"
    
    if command_exists docker-compose; then
        COMPOSE_PROFILES=production docker-compose up -d --build
    else
        COMPOSE_PROFILES=production docker compose up -d --build
    fi
    
    print_status "Production services started!"
    print_status "Application: https://${CLS_DOMAIN:-localhost}"
}

# Function to include Traccar
include_traccar() {
    print_step "Starting with Traccar GPS service..."
    
    cd "${SCRIPT_DIR}/cls"
    
    if command_exists docker-compose; then
        COMPOSE_PROFILES=traccar docker-compose up -d --build
    else
        COMPOSE_PROFILES=traccar docker compose up -d --build
    fi
    
    print_status "Services with Traccar started!"
    print_status "Application: http://localhost:8080"
    print_status "Traccar: http://localhost:8082"
}

# Main execution function
main() {
    # Check prerequisites
    check_prerequisites
    
    # Create environment file
    create_env_file
    
    # Load environment variables
    if [ -f "${SCRIPT_DIR}/cls/.env" ]; then
        source "${SCRIPT_DIR}/cls/.env"
    fi
    
    # Main interactive loop
    while true; do
        show_menu
        read -p "Select an option: " choice
        
        case $choice in
            1) build_and_start ;;
            2) start_services ;;
            3) stop_services ;;
            4) restart_services ;;
            5) rebuild_restart ;;
            6) view_logs ;;
            7) access_shell ;;
            8) access_database ;;
            9) cleanup ;;
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
