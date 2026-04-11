# Haptics

[![App Store](https://img.shields.io/badge/App_Store-Download-blue?logo=apple)](https://apps.apple.com/us/app/haptics-send-love-to-friends/id6503260004)
[![License](https://img.shields.io/badge/License-Apache_2.0-green.svg)](LICENSE)

Haptics is an iOS app that lets you send haptic feedback messages to friends — a simple tap to let someone know you're thinking of them.

Read about building Haptics on [Spotted In Prod](https://spottedinprod.com/posts/TODO).

## Getting Started

See [RUNNING.md](RUNNING.md) for setup, signing, Firebase config, and local backend instructions.

## Architecture

The app uses MVVM with dependency injection, a session pattern for global state, and coordinators for navigation. It's built primarily with UIKit (SwiftUI for newer screens), backed by Firebase.

See [CLAUDE.md](CLAUDE.md) for detailed architecture notes and code conventions.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
