#!/bin/bash

# VGV CLI Installation Script
# This script installs the VGV CLI tool globally

set -e

echo "🚀 Installing VGV CLI..."

# Check if Dart is installed
if ! command -v dart &> /dev/null; then
    echo "❌ Dart is not installed. Please install Dart first:"
    echo "   https://dart.dev/get-dart"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first:"
    echo "   https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check Dart SDK version compatibility
DART_VERSION=$(dart --version 2>&1 | grep -o 'Dart VM version: [0-9]\+\.[0-9]\+' | cut -d' ' -f4)
REQUIRED_VERSION="3.7.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$DART_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ Dart version $DART_VERSION is not compatible. Required: >= $REQUIRED_VERSION"
    echo "   Please update Dart: https://dart.dev/get-dart"
    exit 1
fi

# Install the CLI globally
echo "📦 Installing VGV CLI..."
dart pub global activate --source path .

# Ensure .pub-cache/bin exists
mkdir -p "$HOME/.pub-cache/bin"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.pub-cache/bin:"* ]]; then
    echo "🔧 Adding to PATH..."
    
    # Detect shell and add to appropriate config file
    if [[ "$SHELL" == *"zsh"* ]]; then
        CONFIG_FILE="$HOME/.zshrc"
        EXPORT_LINE='export PATH="$PATH:$HOME/.pub-cache/bin"'
    elif [[ "$SHELL" == *"bash"* ]]; then
        CONFIG_FILE="$HOME/.bashrc"
        EXPORT_LINE='export PATH="$PATH:$HOME/.pub-cache/bin"'
    elif [[ "$SHELL" == *"fish"* ]]; then
        CONFIG_FILE="$HOME/.config/fish/config.fish"
        EXPORT_LINE='set -gx PATH $PATH $HOME/.pub-cache/bin'
    else
        echo "⚠️  Unknown shell: $SHELL"
        echo "Please add $HOME/.pub-cache/bin to your PATH manually"
        CONFIG_FILE=""
    fi
    
    if [[ -n "$CONFIG_FILE" ]]; then
        # Check if the export line already exists
        if ! grep -q "$HOME/.pub-cache/bin" "$CONFIG_FILE" 2>/dev/null; then
            echo "" >> "$CONFIG_FILE"
            echo "# VGV CLI PATH" >> "$CONFIG_FILE"
            echo "$EXPORT_LINE" >> "$CONFIG_FILE"
            echo "✅ Added to $CONFIG_FILE"
        else
            echo "✅ PATH already configured in $CONFIG_FILE"
        fi
    fi
else
    echo "✅ PATH already includes $HOME/.pub-cache/bin"
fi

# Verify installation
echo "🔍 Verifying installation..."
if command -v vgv &> /dev/null; then
    echo "✅ VGV CLI installed successfully!"
    echo ""
    echo "🎯 Usage:"
    echo "  vgv"
    echo "  vgv --version"
    echo "  vgv --help"
    echo ""
    echo "📚 For more information, visit:"
    echo "  https://github.com/victorsdd01/vgv_cli"
    echo ""
    echo "🚀 Happy coding with VGV!"
    echo ""
    echo "💡 Note: If you just installed, you may need to restart your terminal"
    echo "   or run: source $CONFIG_FILE"
else
    echo "❌ Installation verification failed"
    echo "Please try restarting your terminal or run: source $CONFIG_FILE"
    exit 1
fi 