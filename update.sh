#!/bin/bash

# FlutterForge CLI Update Script
# This script updates the FlutterForge CLI tool to the latest version

set -e

echo "🔄 Updating FlutterForge CLI..."

# Check current version
echo "📋 Current version:"
flutterforge --version

echo ""
echo "📦 Updating to latest version..."

# Update to latest version
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

echo ""
echo "✅ FlutterForge CLI updated successfully!"
echo ""
echo "📋 New version:"
flutterforge --version

echo ""
echo "🚀 Happy coding with Flutter!" 