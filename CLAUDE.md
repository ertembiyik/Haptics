# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Haptics is an iOS application built with Swift that enables users to send haptic feedback messages ("love") between friends. The app uses a modular architecture with local Swift packages and follows MVVM patterns with dependency injection.

## Build Commands

```bash
# Open project in Xcode
open Haptics.xcodeproj

# Build from command line
xcodebuild -scheme Haptics -configuration Debug build

# Build for release
xcodebuild -scheme Haptics -configuration Release build

# Clean and build
xcodebuild -scheme Haptics clean build

# Build for specific simulator
xcodebuild -scheme Haptics -destination 'platform=iOS Simulator,name=iPhone 15' build

# Resolve package dependencies
xcodebuild -resolvePackageDependencies
```

## Architecture & Code Organization

### Project Structure
- **Haptics/**: Main app target
  - `Resources/`: Assets, strings, storyboards
  - `Sources/Core/`: Shared utilities, extensions, base UI components
  - `Sources/DataFlow/`: Sessions (global state), managers, services
  - `Sources/UIFlow/`: UI screens and view-specific components

- **Packages/**: Local Swift packages for modular features
  - Each package is self-contained with its own Sources and Tests
  - Key packages: AuthSession, ConversationsSession, Effects, SharedUI

### Architecture Patterns

1. **MVVM with Observation**: ViewModels use `@Observable` macro for SwiftUI
2. **Session Pattern**: Global state managed through session protocols (AuthSession, ConversationsSession)
3. **Dependency Injection**: Uses Factory pattern with `@Injected` property wrapper
4. **Coordinator Pattern**: Navigation handled by coordinators

### Key Technical Components

- **Backend**: Firebase (Auth, Firestore, Realtime Database, Messaging)
- **UI Framework**: Primarily UIKit with SwiftUI for newer components
- **Layout**: PinLayout for UIKit views
- **Effects**: Custom Metal shaders in Effects package
- **Analytics**: PostHog and Firebase Analytics

### Code Style Requirements

- **Explicit self**: Always use `self.` for properties and methods
- **File Naming**: 
  - UIKit: `{Name}Controller.swift`
  - SwiftUI: `{Name}View.swift`
  - ViewModels: `{Name}ViewModel.swift`
- **Error Handling**: Prefer `do-catch` over optionals
- **Async**: Use Swift Concurrency (async/await) over GCD/Combine
- **One class/struct per file** (except ViewModel State enums)

### Common Development Tasks

When implementing new features:
1. Check existing patterns in similar features
2. Use dependency injection for services
3. Create separate view files for different states (skeleton, loaded, error)
4. Follow the established file organization within classes
5. Use domain-specific loggers (e.g., `Logger.conversations`, `Logger.auth`)

### Important Notes

- No test infrastructure currently exists
- Development primarily done through Xcode GUI
- Firebase configuration in `GoogleService-Info.plist`
- App uses Swift Package Manager exclusively (no CocoaPods)
- Minimum iOS version: 13.0