#!/bin/bash

# Script to generate OpenAPI code and commit it
# Run this before releasing a new version

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔄 Updating OpenAPI specification..."
"$SCRIPT_DIR/update-openapi-spec.sh"

echo ""
echo "🏗️  Building package to generate code..."
cd "$PROJECT_ROOT"
swift build

echo ""
echo "📝 Generated files:"
find Sources/OmniChatKit/Generated -name "*.swift" -type f | sort

echo ""
echo "✅ Code generation complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated code"
echo "2. Run tests: swift test"
echo "3. Commit the changes: git add Sources/OmniChatKit/Generated && git commit -m 'Update generated OpenAPI code'"
echo "4. Tag a new version: git tag 1.0.1"
echo "5. Push: git push origin main --tags"