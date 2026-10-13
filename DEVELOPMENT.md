# Development Guide

This document describes how to build, test, and contribute to PumkinRaidApp.

## Prerequisites

- macOS 14.0 or later
- Xcode 16.0 or later with Command Line Tools
- Swift 6.0 or later
- Node.js 22+ and npm (for WebAssembly target in `Platforms/Web`)

## Building and Testing

### Apple Native App

```bash
# Build package targets
swift build

# Run unit and integration tests
swift test
```

### Web Target

```bash
cd Platforms/Web
npm install
npm test
```

## Release Workflow

All releases follow semantic versioning incrementing by `0.0.1` per iteration on branch `feat/v<next-version>`.
