#!/bin/bash

# OmniChatKit Build Script

echo "Building OmniChatKit..."

# Clean previous build
echo "Cleaning build artifacts..."
swift package clean

# Fetch dependencies
echo "Fetching dependencies..."
swift package resolve

# Build the package
echo "Building package..."
swift build

# Run tests
echo "Running tests..."
swift test

# Build documentation (if you have DocC configured)
echo "Building documentation..."
swift package generate-documentation

echo "Build completed successfully!"