#!/bin/bash

# GPU Monitor iOS Setup Script
# This script automates the creation of the Xcode project for iOS/iPadOS

set -e

echo "🚀 Setting up GPU Monitor for iOS/iPadOS..."
echo ""

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ xcodegen is not installed"
    echo ""
    echo "Would you like to install it via Homebrew? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        if ! command -v brew &> /dev/null; then
            echo "❌ Homebrew is not installed"
            echo "Please install Homebrew from https://brew.sh"
            exit 1
        fi
        echo "📦 Installing xcodegen..."
        brew install xcodegen
    else
        echo ""
        echo "Please follow the manual setup instructions in README.md"
        exit 1
    fi
fi

echo "✅ xcodegen is installed"
echo ""

# Generate the Xcode project
echo "🔨 Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ Xcode project generated successfully!"
echo ""
echo "📱 Opening project in Xcode..."
open GPUMonitorIOS.xcodeproj

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Wait for Xcode to open"
echo "2. Select your target device (iPhone or iPad simulator)"
echo "3. Click the Run button (▶️) or press Cmd+R"
echo "4. Make sure your iOS device is on the same network as your GPU servers"
echo ""
echo "💡 Tip: Edit servers.json to configure your GPU server addresses"
