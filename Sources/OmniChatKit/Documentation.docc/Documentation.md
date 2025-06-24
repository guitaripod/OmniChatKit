# ``OmniChatKit``

A comprehensive Swift client for the OmniChat API with full type safety and modern Swift concurrency.

## Overview

OmniChatKit provides a complete Swift implementation of the OmniChat API, generated from the official OpenAPI specification using swift-openapi-generator. It offers type-safe access to all 43 API endpoints with support for streaming responses, file uploads, and comprehensive error handling.

### Key Features

- **Complete API Coverage**: Every endpoint from the OmniChat API is implemented
- **Type Safety**: Generated from OpenAPI spec ensuring compile-time safety
- **Modern Swift**: Built with Swift 5.9 features including actors and structured concurrency
- **Multi-Platform**: Supports iOS, macOS, watchOS, tvOS, visionOS, and Linux
- **Streaming Support**: Real-time chat responses via Server-Sent Events
- **File Operations**: Upload and download with progress tracking
- **Flexible Authentication**: Support for Clerk, JWT, and API key authentication

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Authentication>
- <doc:ErrorHandling>

### Chat Operations

- ``OmniChatClient/chat(messages:model:conversationId:temperature:maxTokens:stream:webSearch:imageGenerationOptions:userApiKeys:ollamaBaseUrl:)``
- ``OmniChatClient/chatStream(messages:model:conversationId:temperature:maxTokens:webSearch:imageGenerationOptions:userApiKeys:ollamaBaseUrl:)``
- <doc:StreamingResponses>

### Conversation Management

- ``OmniChatClient/getConversations()``
- ``OmniChatClient/createConversation(title:model:)``
- ``OmniChatClient/deleteConversation(id:)``
- ``OmniChatClient/updateConversationV1(id:title:isArchived:)``

### Message Operations

- ``OmniChatClient/getConversationMessages(conversationId:)``
- ``OmniChatClient/createMessage(conversationId:role:content:model:parentId:)``

### File Operations

- ``OmniChatClient/uploadFile(file:fileName:conversationId:messageId:)``
- ``OmniChatClient/downloadFile(key:)``
- ``FileTransferManager``
- <doc:FileTransfers>

### Search

- ``OmniChatClient/search(query:limit:)``

### User & Billing

- ``OmniChatClient/getUserProfileV1()``
- ``OmniChatClient/getBatteryStatus()``
- ``OmniChatClient/createCheckoutSession(type:planId:isAnnual:batteryUnits:returnUrl:)``

### Models

- ``OmniChatClient/getAvailableModels()``

### Protocols

- ``OmniChatClientProtocol``
- ``AuthenticationProviding``
- ``TokenRefreshing``
- ``RequestIntercepting``
- ``ResponseValidating``

### Error Types

- ``OmniChatError``
- ``AuthenticationError``
- ``APIError``
- ``NetworkError``
- ``StreamError``