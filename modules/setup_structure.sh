#!/bin/bash

# Script to create the proper directory structure
# Run this once to organize all the modular scripts

echo "Creating Arch Linux Setup Script structure..."

# Create directories
mkdir -p lib
mkdir -p modules

echo "✓ Created directories: lib/ and modules/"

# Move/create files (this is a template - you'll need to create the actual files)
echo ""
echo "File structure should be:"
echo ""
echo "arch-setup/"
echo "├── main.sh              (Main orchestrator)"
echo "├── lib/"
echo "│   └── common.sh        (Shared functions)"
echo "└── modules/"
echo "    ├── gpu.sh           (GPU detection)"
echo "    ├── pacman.sh        (Pacman packages)"
echo "    ├── flatpak.sh       (Flatpak packages)"
echo "    ├── aur.sh           (AUR packages)"
echo "    ├── virt.sh          (Virtualization)"
echo "    ├── firewall.sh      (Firewall config)"
echo "    ├── drives.sh        (Drive mounting)"
echo "    └── plymouth.sh      (Plymouth config)"
echo ""
echo "Next steps:"
echo "1. Create each file with the provided content"
echo "2. Make all scripts executable:"
echo "   chmod +x main.sh lib/common.sh modules/*.sh"
echo "3. Run the main script:"
echo "   ./main.sh"
echo ""
echo "✓ Structure ready!"