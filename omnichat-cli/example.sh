#!/bin/bash

# OmniChat CLI Example Script
# This script demonstrates various features of the OmniChat CLI

set -e

echo "🚀 OmniChat CLI Demo"
echo "===================="
echo

# Check if omnichat is in PATH
if ! command -v omnichat &> /dev/null; then
    echo "⚠️  omnichat not found in PATH. Building and using local binary..."
    swift build -c release
    OMNICHAT="./.build/release/omnichat"
else
    OMNICHAT="omnichat"
fi

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}1. Checking Authentication Status${NC}"
$OMNICHAT auth status || echo "Not authenticated yet"
echo

echo -e "${BLUE}2. Listing Available Models${NC}"
$OMNICHAT models
echo

echo -e "${BLUE}3. Testing Chat (Non-interactive)${NC}"
if $OMNICHAT auth status &> /dev/null; then
    echo "Sending test message..."
    $OMNICHAT chat "Hello! Please respond with a short greeting." --no-stream
else
    echo -e "${YELLOW}Skipping - authentication required${NC}"
fi
echo

echo -e "${BLUE}4. Running API Tests${NC}"
if $OMNICHAT auth status &> /dev/null; then
    $OMNICHAT test
else
    echo -e "${YELLOW}Skipping - authentication required${NC}"
fi

echo
echo -e "${GREEN}✅ Demo completed!${NC}"
echo
echo "To authenticate and run all features:"
echo "  $OMNICHAT auth apple --id-token YOUR_TOKEN"
echo "  # or"
echo "  $OMNICHAT auth bearer --token YOUR_JWT"
echo
echo "For interactive chat:"
echo "  $OMNICHAT chat"