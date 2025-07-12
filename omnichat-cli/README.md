# OmniChat CLI 🚀

A beautiful command-line interface for testing the OmniChatKit Swift package. Built with ❤️ for Linux and macOS.

## Features

- 🔐 **Seamless Authentication**: Browser-based Apple Sign In, JWT Bearer, Clerk, and API Keys
- 💬 **Interactive Chat**: Real-time streaming with beautiful formatting
- 🤖 **Model Listing**: Browse available AI models
- 🧪 **API Testing**: Verify your connection and authentication
- ⚙️ **Configuration**: Manage settings and preferences
- 🎨 **Beautiful Output**: Colored tables, progress bars, and spinners

## How It Works

This CLI uses the OmniChatKit package which generates all API client code at compile time using OpenAPI Generator. This ensures type safety and keeps the CLI in sync with the API specification automatically.

## Installation

### Prerequisites

- Swift 5.9+
- macOS 14.0+ or Linux
- The OpenAPI spec is compiled during build, so no manual generation needed!

### Build from Source

```bash
git clone https://github.com/yourusername/OmniChatKit.git
cd OmniChatKit/omnichat-cli
swift build -c release
sudo cp .build/release/omnichat /usr/local/bin/
```

## Quick Start

### 1. Authenticate

```bash
# Sign in with Apple (opens browser automatically)
omnichat auth apple

# Or use JWT bearer token
omnichat auth bearer --token "YOUR_JWT_TOKEN"

# Check authentication status
omnichat auth status
```

**Apple Sign In**: Simply run `omnichat auth apple` and your browser will open automatically. Complete the sign-in process and the CLI will handle the rest!

### 2. Start Chatting

```bash
# Interactive chat with default model
omnichat chat

# Chat with specific model
omnichat chat -m "claude-opus-4-20250514"

# Send a single message
omnichat chat "What is the meaning of life?"
```

### 3. Test Your Connection

```bash
# Run basic API tests
omnichat test

# List available models
omnichat models
```

## Configuration

Configuration is stored in `~/.omnichat-cli/config.json`:

```bash
# Set a configuration value
omnichat config set default_model "gpt-4o"

# List all configuration
omnichat config

# Show config file location
omnichat config path
```

## Authentication

### Apple Sign In
The CLI provides a seamless Apple Sign In experience:
1. Run `omnichat auth apple`
2. Your browser opens automatically
3. Sign in with your Apple ID
4. Return to the terminal - you're authenticated!

No need to manually copy tokens or deal with complex authentication flows.

### Token Storage
Authentication tokens are securely stored in `~/.omnichat-cli/token.json` with automatic expiration handling.

## Using the Generated API

The CLI demonstrates how to use the OmniChatKit generated client. Here's a simple example:

```swift
import OmniChatKit
import OpenAPIRuntime
import OpenAPIURLSession

// Create an authenticated client
let client = Client(
    serverURL: URL(string: "https://omnichat-7pu.pages.dev")!,
    transport: URLSessionTransport(),
    middlewares: [AuthMiddleware(headerName: "Authorization", headerValue: "Bearer \(token)")]
)

// Make API calls using the generated methods
let response = try await client.get_sol_api_sol_v1_sol_user_sol_profile(.init())

switch response {
case .ok(let ok):
    let user = try ok.body.json
    print("User ID: \(user.id)")
case .unauthorized:
    print("Authentication failed")
default:
    print("Unexpected error")
}
```

## Architecture

This CLI is intentionally minimal and focuses on demonstrating:
- How to use the OpenAPI-generated client
- Proper authentication handling with middleware
- Beautiful console output
- Error handling patterns

For a full-featured implementation, you would extend the commands to use all the generated API methods.

## Contributing

Contributions are welcome! The generated API client provides access to all endpoints - feel free to add more commands that demonstrate additional functionality.

## License

This CLI tool is part of the OmniChatKit project.