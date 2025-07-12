#!/bin/bash

echo "🚀 OmniChat CLI - Seamless Authentication Demo"
echo "=============================================="
echo ""
echo "This demo shows how easy it is to authenticate with Apple Sign In."
echo ""
echo "Press Enter to continue..."
read

echo "Step 1: Running 'omnichat auth apple'"
echo "Your browser will open automatically for sign in..."
echo ""

./.build/release/omnichat auth apple

echo ""
echo "Great! You're now authenticated. Let's check your status:"
echo ""
echo "Step 2: Running 'omnichat auth status'"
echo ""

./.build/release/omnichat auth status

echo ""
echo "Now you can start chatting!"
echo "Try: ./.build/release/omnichat chat"