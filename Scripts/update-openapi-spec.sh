#!/bin/bash

# Script to download/update the OpenAPI specification
# This should be run before building to ensure you have the latest spec

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OPENAPI_URL="https://omnichat-7pu.pages.dev/api/openapi.json"
OPENAPI_FILE="$PROJECT_ROOT/Sources/OmniChatKit/openapi.json"

echo "Downloading OpenAPI specification from OmniChat..."
echo "URL: $OPENAPI_URL"
echo "Destination: $OPENAPI_FILE"

# Create directory if it doesn't exist
mkdir -p "$(dirname "$OPENAPI_FILE")"

# Download the spec
if curl -f -s -o "$OPENAPI_FILE" "$OPENAPI_URL"; then
    echo "✅ OpenAPI specification downloaded successfully"
    
    # Validate JSON
    if python3 -m json.tool "$OPENAPI_FILE" > /dev/null 2>&1; then
        echo "✅ OpenAPI specification is valid JSON"
    else
        echo "❌ Downloaded file is not valid JSON"
        exit 1
    fi
else
    echo "❌ Failed to download OpenAPI specification"
    exit 1
fi

echo ""
echo "You can now build the package with:"
echo "  swift build"