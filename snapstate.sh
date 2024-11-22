#!/usr/bin/env bash

# SnapState - Intelligent System State Manager
# A system configuration snapshot and rollback tool using overlayfs

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SNAPSTATE_ROOT="/var/lib/snapstate"
OVERLAY_DIR="$SNAPSTATE_ROOT/overlay"
SNAPSHOT_DIR="$SNAPSTATE_ROOT/snapshots"
WORKDIR="$SNAPSTATE_ROOT/work"
CONFIG_FILE="/etc/snapstate.conf"
LOG_FILE="/var/log/snapstate.log"

# Directories to track (default)
TRACKED_DIRS=(
    "/etc"
    "/usr/local/etc"
    "/boot/loader"
    "/var/lib/pacman"
)

# Pacman hook directory
PACMAN_HOOK_DIR="/etc/pacman.d/hooks"

# Function to initialize logging
setup_logging() {
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        chmod 640 "$LOG_FILE"
    fi
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}Error: $message${NC}" >&2
    elif [[ "$level" == "INFO" ]]; then
        echo -e "${BLUE}$message${NC}"
    fi
}

# Function to check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "This script must be run as root"
        exit 1
    fi
}

# Function to create necessary directories
create_directories() {
    mkdir -p "$SNAPSTATE_ROOT" "$OVERLAY_DIR" "$SNAPSHOT_DIR" "$WORKDIR"
    chmod 700 "$SNAPSTATE_ROOT" "$OVERLAY_DIR" "$SNAPSHOT_DIR" "$WORKDIR"
}

# Function to setup overlay filesystem
setup_overlay() {
    local dir="$1"
    local snapshot_name="$2"
    local target_dir="$OVERLAY_DIR/$(basename "$dir")"
    local work_dir="$WORKDIR/$(basename "$dir")"
    local upper_dir="$SNAPSHOT_DIR/$snapshot_name/$(basename "$dir")"
    
    mkdir -p "$target_dir" "$work_dir" "$upper_dir"
    
    mount -t overlay overlay \
        -o lowerdir="$dir",upperdir="$upper_dir",workdir="$work_dir" \
        "$target_dir"
    
    if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Failed to setup overlay for $dir"
        return 1
    fi
    
    log_message "INFO" "Successfully setup overlay for $dir"
    return 0
}

# Function to create a snapshot
create_snapshot() {
    local snapshot_name="$1"
    if [[ -z "$snapshot_name" ]]; then
        snapshot_name="snapshot_$(date +%Y%m%d_%H%M%S)"
    fi
    
    log_message "INFO" "Creating snapshot: $snapshot_name"
    
    # Create snapshot directory
    mkdir -p "$SNAPSHOT_DIR/$snapshot_name"
    
    # Setup overlays for each tracked directory
    for dir in "${TRACKED_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            setup_overlay "$dir" "$snapshot_name"
        fi
    done
    
    # Store metadata
    cat > "$SNAPSHOT_DIR/$snapshot_name/metadata.json" << EOF
{
    "name": "$snapshot_name",
    "created": "$(date -Iseconds)",
    "tracked_dirs": [
        $(printf '"%s",' "${TRACKED_DIRS[@]}" | sed 's/,$//')
    ],
    "pacman_packages": "$(pacman -Q)"
}
EOF
    
    log_message "INFO" "Snapshot $snapshot_name created successfully"
}

# Function to list snapshots
list_snapshots() {
    log_message "INFO" "Listing available snapshots"
    
    echo -e "${BLUE}Available Snapshots:${NC}"
    for snapshot in "$SNAPSHOT_DIR"/*; do
        if [[ -f "$snapshot/metadata.json" ]]; then
            local name=$(jq -r '.name' "$snapshot/metadata.json")
            local created=$(jq -r '.created' "$snapshot/metadata.json")
            echo -e "${GREEN}$name${NC} - Created: $created"
        fi
    done
}

# Function to rollback to a snapshot
rollback_snapshot() {
    local snapshot_name="$1"
    local component="$2"
    
    if [[ ! -d "$SNAPSHOT_DIR/$snapshot_name" ]]; then
        log_message "ERROR" "Snapshot $snapshot_name does not exist"
        return 1
    fi
    
    log_message "INFO" "Rolling back to snapshot: $snapshot_name"
    
    if [[ -n "$component" ]]; then
        # Rollback specific component
        if [[ ! " ${TRACKED_DIRS[@]} " =~ " /$component " ]]; then
            log_message "ERROR" "Component $component is not tracked"
            return 1
        fi
        
        rsync -aAX --delete \
            "$SNAPSHOT_DIR/$snapshot_name/$component/" "/$component/"
    else
        # Rollback all components
        for dir in "${TRACKED_DIRS[@]}"; do
            if [[ -d "$SNAPSHOT_DIR/$snapshot_name/$(basename "$dir")" ]]; then
                rsync -aAX --delete \
                    "$SNAPSHOT_DIR/$snapshot_name/$(basename "$dir")/" "$dir/"
            fi
        done
    fi
    
    log_message "INFO" "Rollback completed successfully"
}

# Function to install pacman hooks
install_pacman_hooks() {
    mkdir -p "$PACMAN_HOOK_DIR"
    
    # Create pre-transaction hook
    cat > "$PACMAN_HOOK_DIR/snapstate-pre.hook" << EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creating system snapshot before pacman transaction...
When = PreTransaction
Exec = /usr/local/bin/snapstate create pre_pacman_\$(date +%Y%m%d_%H%M%S)
EOF
    
    # Create post-transaction hook
    cat > "$PACMAN_HOOK_DIR/snapstate-post.hook" << EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creating system snapshot after pacman transaction...
When = PostTransaction
Exec = /usr/local/bin/snapstate create post_pacman_\$(date +%Y%m%d_%H%M%S)
EOF
    
    log_message "INFO" "Pacman hooks installed successfully"
}

# Function to cleanup old snapshots
cleanup_snapshots() {
    local keep_count="$1"
    [[ -z "$keep_count" ]] && keep_count=5
    
    log_message "INFO" "Cleaning up old snapshots, keeping $keep_count most recent"
    
    local snapshots=($(ls -t "$SNAPSHOT_DIR"))
    local count=${#snapshots[@]}
    
    if [[ $count -gt $keep_count ]]; then
        for ((i=keep_count; i<count; i++)); do
            rm -rf "$SNAPSHOT_DIR/${snapshots[i]}"
            log_message "INFO" "Removed old snapshot: ${snapshots[i]}"
        done
    fi
}

# Function to show help
show_help() {
    cat << EOF
SnapState - Intelligent System State Manager

Usage: snapstate <command> [options]

Commands:
    init              Initialize SnapState
    create [name]     Create a new snapshot
    list             List available snapshots
    rollback <name>   Rollback to a snapshot
    cleanup [count]   Cleanup old snapshots
    help             Show this help message

Options:
    --component=DIR   Specify component for rollback

Examples:
    snapstate init
    snapstate create my_snapshot
    snapstate rollback my_snapshot --component=etc
    snapstate cleanup 5
EOF
}

# Main execution
main() {
    check_root
    setup_logging
    
    case "$1" in
        "init")
            create_directories
            install_pacman_hooks
            ;;
        "create")
            create_snapshot "$2"
            ;;
        "list")
            list_snapshots
            ;;
        "rollback")
            local component=""
            if [[ "$3" == "--component="* ]]; then
                component="${3#--component=}"
            fi
            rollback_snapshot "$2" "$component"
            ;;
        "cleanup")
            cleanup_snapshots "$2"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
