# 📸 SnapState

> Intelligent system state manager for Arch Linux using overlayfs technology

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-Support-1793D1?logo=arch-linux&logoColor=white)](https://archlinux.org/)

## Overview

SnapState is an advanced system state management tool that uses overlayfs to create efficient, component-level snapshots of your Arch Linux system. It enables granular rollbacks without requiring full system restores and integrates with pacman for automatic state capture.

## Features

### Core Functionality
- 🔄 Efficient system state snapshots using overlayfs
- 🎯 Component-level rollback capability
- 🔄 Automatic state capture via pacman hooks
- 📊 Detailed metadata tracking
- 🧹 Intelligent cleanup of old snapshots

### Technical Features
- Uses overlayfs for efficient storage
- Rsync-based rollback system
- JSON-based metadata storage
- Pacman hook integration
- Component-specific tracking
- Comprehensive logging

## Installation

```bash
# Clone the repository
git clone https://github.com/justkelvin/snapstate.git

# Enter directory
cd snapstate

# Make executable
chmod +x snapstate.sh

# Install to system path
sudo cp snapstate.sh /usr/local/bin/snapstate

# Initialize SnapState
sudo snapstate init
```

## Usage

### Basic Commands

```bash
# Create a snapshot
sudo snapstate create [snapshot_name]

# List available snapshots
sudo snapstate list

# Rollback to a snapshot
sudo snapstate rollback <snapshot_name>

# Rollback specific component
sudo snapstate rollback <snapshot_name> --component=etc

# Cleanup old snapshots
sudo snapstate cleanup [keep_count]
```

### Tracked Directories
By default, SnapState tracks:
- `/etc`
- `/usr/local/etc`
- `/boot/loader`
- `/var/lib/pacman`

### Pacman Integration
SnapState automatically creates snapshots:
- Before pacman transactions
- After successful pacman transactions

## Configuration

The main configuration file is located at `/etc/snapstate.conf`.
Customize tracked directories and retention policies here.

```bash
# Example configuration
TRACKED_DIRS=(
    "/etc"
    "/usr/local/etc"
    "/custom/config/dir"
)
RETENTION_DAYS=30
MAX_SNAPSHOTS=10
```

## Directory Structure

```
/var/lib/snapstate/
├── overlay/         # Overlay mount points
├── snapshots/       # Snapshot storage
│   ├── snapshot_20240114_120000/
│   │   ├── etc/
│   │   ├── boot/
│   │   └── metadata.json
│   └── ...
└── work/           # Overlay work directories
```

## Technical Details

### Snapshot Creation
1. Sets up overlayfs for tracked directories
2. Creates isolated upper layers
3. Stores metadata including:
   - Timestamp
   - Tracked directories
   - Package state
   - System information

### Rollback Process
1. Verifies snapshot integrity
2. Mounts overlay filesystem
3. Synchronizes files using rsync
4. Verifies successful rollback
5. Updates system state

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Development Roadmap

- [ ] GUI interface
- [ ] Network synchronization
- [ ] Compression options
- [ ] Dependency tracking
- [ ] Automatic testing
- [ ] Performance metrics
- [ ] Extended metadata
- [ ] Backup integration

## Requirements

- Arch Linux
- overlayfs support
- rsync
- jq (for JSON processing)
- root privileges

## Security

- All operations require root privileges
- Snapshots are stored with restricted permissions
- Metadata is validated before rollback
- Logging of all operations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and bug reports:
1. Check existing issues
2. Create a new issue with:
   - System information
   - SnapState logs
   - Steps to reproduce
   - Expected behavior

## Acknowledgments

- Inspired by BTRFS snapshots
- Built for the Arch Linux community
- Thanks to all contributors
