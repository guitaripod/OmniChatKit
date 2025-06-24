.PHONY: all update-spec build test clean docs

# Default target
all: update-spec build

# Update the OpenAPI specification
update-spec:
	@echo "Updating OpenAPI specification..."
	@./Scripts/update-openapi-spec.sh

# Build the package
build: update-spec
	@echo "Building OmniChatKit..."
	@swift build

# Run tests
test: update-spec
	@echo "Running tests..."
	@swift test

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@swift package clean
	@rm -rf .build
	@rm -f Sources/OmniChatKit/openapi.json

# Generate documentation
docs:
	@echo "Generating documentation..."
	@swift package generate-documentation

# Development build (with verbose output)
dev: update-spec
	@swift build -v

# Format code
format:
	@echo "Formatting code..."
	@swift-format -i -r Sources/ Tests/

# Lint code
lint:
	@echo "Linting code..."
	@swift-format lint -r Sources/ Tests/