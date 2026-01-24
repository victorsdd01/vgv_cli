#!/bin/bash

echo "🧪 Testing VGV CLI..."
echo ""

# Test version
echo "1️⃣ Testing --version flag:"
dart run bin/vgv.dart --version
echo ""

# Test help
echo "2️⃣ Testing --help flag:"
dart run bin/vgv.dart --help
echo ""

echo "✅ Basic tests completed!"
echo ""
echo "💡 To test project generation, run:"
echo "   dart run bin/vgv.dart"
echo ""
echo "   Then follow the interactive prompts to create a test project."

