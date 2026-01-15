#!/bin/bash

# GitLab Docker Compose Auto-Update Script
# Save as: update-gitlab.sh
# Make executable: chmod +x update-gitlab.sh

set -e  # Exit on error

# Configuration
COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="backups"
LOG_FILE="$LOG_FILE.$(date +%Y-%m-%d)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# NTFY Configuration (change these or set via environment variables)
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-gitlab-updates}"
NTFY_PRIORITY="${NTFY_PRIORITY:-default}"

# Default options
AUTO_MODE=false
FORCE_UPDATE=false
SKIP_BACKUP=false
CHECK_ONLY=false
DRY_RUN=false

# Logging function
log() {
    local message="$1"
    local level="${2:-INFO}"
    local color="${NC}"
    
    case "$level" in
        "ERROR") color="$RED" ;;
        "SUCCESS") color="$GREEN" ;;
        "WARNING") color="$YELLOW" ;;
        "INFO") color="$BLUE" ;;
    esac
    
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${color}[$level]${NC} $message" | tee -a "$LOG_FILE"
}

# Send ntfy notification
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-$NTFY_PRIORITY}"
    
    # Skip if NTFY_TOPIC is not set
    [ -z "$NTFY_TOPIC" ] && return 0
    
    log "Sending ntfy notification: $title" "INFO"
    
    # Use curl to send notification
    curl -s \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -d "$message" \
        "${NTFY_SERVER}/${NTFY_TOPIC}" > /dev/null 2>&1 || \
        log "Failed to send ntfy notification" "WARNING"
}

# Error handling with ntfy notification
handle_error() {
    local error_msg="$1"
    local exit_code="${2:-1}"
    
    log "ERROR: $error_msg" "ERROR"
    send_ntfy "GitLab Update Failed ❌" "Error: $error_msg\nTimestamp: $(date)\nLog: $(tail -20 "$LOG_FILE")" "high"
    exit $exit_code
}

# Print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "GitLab Docker Compose Auto-Update Script"
    echo
    echo "Options:"
    echo "  -a, --auto           Auto mode (non-interactive)"
    echo "  -b, --backup         Create backup before update"
    echo "  -n, --no-backup      Skip backup"
    echo "  -f, --force          Force update even if no new version detected"
    echo "  -c, --check-only     Only check for updates, don't update"
    echo "  -d, --dry-run        Show what would be done without actually doing it"
    echo "  --ntfy-topic TOPIC   Set ntfy topic (default: gitlab-updates)"
    echo "  --ntfy-server URL    Set ntfy server URL (default: https://ntfy.sh)"
    echo "  --compose-file FILE  Specify docker-compose file (default: docker-compose.yml)"
    echo "  --backup-dir DIR     Specify backup directory (default: backups)"
    echo "  -h, --help           Show this help message"
    echo
    echo "Environment variables:"
    echo "  NTFY_TOPIC           Set ntfy topic"
    echo "  NTFY_SERVER          Set ntfy server URL"
    echo
    echo "Examples:"
    echo "  $0 --auto --backup"
    echo "  $0 --check-only"
    echo "  $0 --force --no-backup"
    echo "  NTFY_TOPIC=my-gitlab $0 --auto"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--auto)
                AUTO_MODE=true
                shift
                ;;
            -b|--backup)
                SKIP_BACKUP=false
                shift
                ;;
            -n|--no-backup)
                SKIP_BACKUP=true
                shift
                ;;
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            -c|--check-only)
                CHECK_ONLY=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --ntfy-topic)
                NTFY_TOPIC="$2"
                shift 2
                ;;
            --ntfy-server)
                NTFY_SERVER="$2"
                shift 2
                ;;
            --compose-file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

# Check if Docker and Docker Compose are available
check_dependencies() {
    log "Checking dependencies..." "INFO"
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        handle_error "Docker is not installed"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1 && ! command -v docker compose >/dev/null 2>&1; then
        handle_error "Docker Compose is not installed"
    fi
    
    # Determine docker compose command
    if command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        DOCKER_COMPOSE_CMD="docker compose"
    fi
    
    log "✓ Dependencies verified" "SUCCESS"
    log "Using $DOCKER_COMPOSE_CMD" "INFO"
}

# Backup current configuration and data
backup_gitlab() {
    log "Creating backup..." "INFO"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would create backup in $BACKUP_DIR/$TIMESTAMP" "INFO"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR/$TIMESTAMP"
    
    # Backup docker-compose file
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "$BACKUP_DIR/$TIMESTAMP/docker-compose.yml"
        log "✓ Backed up docker-compose.yml" "SUCCESS"
    fi
    
    # Backup environment file if exists
    if [ -f ".env" ]; then
        cp ".env" "$BACKUP_DIR/$TIMESTAMP/.env"
        log "✓ Backed up .env" "SUCCESS"
    fi
    
    # Create data backup using GitLab's backup command
    log "Creating GitLab data backup..." "INFO"
    if $DOCKER_COMPOSE_CMD exec -T gitlab gitlab-backup create 2>/dev/null; then
        log "✓ GitLab backup created" "SUCCESS"
        send_ntfy "GitLab Backup Created ✅" "Backup completed successfully in $BACKUP_DIR/$TIMESTAMP" "low"
    else
        log "Note: Could not create GitLab backup via container command" "WARNING"
        send_ntfy "GitLab Backup Warning ⚠️" "Could not create GitLab backup via container command" "low"
    fi
    
    log "✓ Backup created in $BACKUP_DIR/$TIMESTAMP" "SUCCESS"
}

# Check for available updates
check_updates() {
    log "Checking for updates..." "INFO"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would check for updates" "INFO"
        return 0
    fi
    
    # Pull latest images to check for updates
    if ! $DOCKER_COMPOSE_CMD pull --quiet 2>/dev/null; then
        log "Failed to pull images to check for updates" "WARNING"
    fi
    
    # Check current version
    CURRENT_VERSION=$($DOCKER_COMPOSE_CMD images gitlab 2>/dev/null | grep gitlab | awk '{print $2}' | head -1 || echo "unknown")
    
    # Get latest version from pulled image
    LATEST_VERSION=$(docker image inspect gitlab/gitlab-ce:latest --format='{{.RepoTags}}' 2>/dev/null | tr -d '[]' | cut -d':' -f2 || echo "unknown")
    
    log "Current version: $CURRENT_VERSION" "INFO"
    log "Latest version available: $LATEST_VERSION" "INFO"
    
    if [ "$FORCE_UPDATE" = true ]; then
        log "Force update requested, proceeding..." "WARNING"
        return 0
    fi
    
    if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "unknown" ]; then
        log "Update available!" "SUCCESS"
        send_ntfy "GitLab Update Available 📦" "Update available: $CURRENT_VERSION → $LATEST_VERSION" "default"
        return 0
    else
        log "Already on latest version" "SUCCESS"
        return 1
    fi
}

# Perform the update
perform_update() {
    log "Performing update..." "INFO"
    send_ntfy "GitLab Update Started ⚡" "Starting GitLab update process\nFrom: $CURRENT_VERSION\nTo: $LATEST_VERSION" "default"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would perform update:" "INFO"
        log "  - Stop containers" "INFO"
        log "  - Pull latest images" "INFO"
        log "  - Start containers" "INFO"
        return 0
    fi
    
    # Stop containers
    log "Stopping containers..." "INFO"
    if ! $DOCKER_COMPOSE_CMD down; then
        handle_error "Failed to stop containers"
    fi
    
    # Pull latest images
    log "Pulling latest images..." "INFO"
    if ! $DOCKER_COMPOSE_CMD pull; then
        handle_error "Failed to pull latest images"
    fi
    
    # Start containers
    log "Starting containers..." "INFO"
    if ! $DOCKER_COMPOSE_CMD up -d; then
        handle_error "Failed to start containers"
    fi
    
    # Wait for GitLab to be healthy
    log "Waiting for GitLab to be healthy..." "INFO"
    sleep 30
    
    # Check if GitLab is running
    if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
        log "✓ GitLab is running" "SUCCESS"
        
        # Get new version after update
        NEW_VERSION=$($DOCKER_COMPOSE_CMD images gitlab 2>/dev/null | grep gitlab | awk '{print $2}' | head -1 || echo "unknown")
        
        send_ntfy "GitLab Update Successful ✅" "Update completed successfully!\nFrom: $CURRENT_VERSION\nTo: $NEW_VERSION\nTimestamp: $(date)" "default"
    else
        handle_error "GitLab may not be running properly after update"
    fi
}

# Interactive confirmation (only used in non-auto mode)
confirm_action() {
    local message="$1"
    local default="${2:-y}"
    
    if [ "$AUTO_MODE" = true ]; then
        return 0  # Auto mode always confirms
    fi
    
    local prompt="[y/N]"
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    fi
    
    read -p "$message $prompt: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z "$REPLY" && "$default" = "y" ]]; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    log "=== GitLab Docker Compose Update Script ===" "INFO"
    log "Mode: $( [ "$AUTO_MODE" = true ] && echo "Auto" || echo "Interactive" )" "INFO"
    log "Dry run: $DRY_RUN" "INFO"
    log "NTFY topic: ${NTFY_TOPIC:-Not set}" "INFO"
    
    # Send start notification
    if [ "$AUTO_MODE" = true ] && [ -n "$NTFY_TOPIC" ]; then
        send_ntfy "GitLab Auto-Update Started 🤖" "Auto-update process started at $(date)" "default"
    fi
    
    check_dependencies
    
    # Backup decision
    if [ "$SKIP_BACKUP" = false ]; then
        if [ "$AUTO_MODE" = true ] || confirm_action "Create backup before updating?" "y"; then
            backup_gitlab
        fi
    else
        log "Skipping backup (--no-backup flag set)" "WARNING"
    fi
    
    # Check for updates
    if check_updates || [ "$FORCE_UPDATE" = true ]; then
        if [ "$CHECK_ONLY" = true ]; then
            log "Check-only mode, exiting without update" "INFO"
            exit 0
        fi
        
        if [ "$AUTO_MODE" = true ] || confirm_action "Proceed with update?" "y"; then
            perform_update
            log "✓ Update completed successfully!" "SUCCESS"
        else
            log "Update cancelled" "WARNING"
            send_ntfy "GitLab Update Cancelled 🛑" "Update was cancelled by user" "low"
        fi
    else
        log "No update needed" "INFO"
    fi
    
    log "=== Script finished ===" "SUCCESS"
}

# Run main function with all arguments
main "$@"
