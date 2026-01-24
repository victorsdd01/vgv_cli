#!/bin/bash

# VGV CLI Uninstall Script
# This script removes the VGV CLI tool from your system

set -e

echo "🗑️  Uninstalling VGV CLI..."

# Check if CLI is installed
if ! command -v vgv &> /dev/null; then
    echo "❌ VGV CLI is not installed."
    exit 1
fi

# Show current version before uninstalling
echo "📋 Current version:"
vgv --version 2>/dev/null || echo "Version check failed"

echo ""
echo "⚠️  Are you sure you want to uninstall VGV CLI? (y/N)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🗑️  Removing VGV CLI..."
    
    # Deactivate the package
    dart pub global deactivate vgv
    
    # Remove from PATH if it was added
    if [[ ":$PATH:" == *":$HOME/.pub-cache/bin:"* ]]; then
        echo "🔧 Removing from PATH..."
        
        # Remove from shell config files
        if [[ "$SHELL" == *"zsh"* ]]; then
            sed -i '' '/export PATH.*\.pub-cache\/bin/d' ~/.zshrc
            echo "Removed from ~/.zshrc"
        elif [[ "$SHELL" == *"bash"* ]]; then
            sed -i '/export PATH.*\.pub-cache\/bin/d' ~/.bashrc
            echo "Removed from ~/.bashrc"
        elif [[ "$SHELL" == *"fish"* ]]; then
            sed -i '/set -gx PATH.*\.pub-cache\/bin/d' ~/.config/fish/config.fish
            echo "Removed from ~/.config/fish/config.fish"
        fi
    fi
    
    echo "✅ VGV CLI uninstalled successfully!"
    echo ""
    echo "💡 To reinstall later, run:"
    echo "   dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git"
else
    echo "❌ Uninstallation cancelled."
    exit 0
fi 