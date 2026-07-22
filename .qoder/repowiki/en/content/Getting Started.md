# Getting Started

<cite>
**Referenced Files in This Document**
- [README.md](file://README.md)
- [pubspec.yaml](file://pubspec.yaml)
- [lib/main.dart](file://lib/main.dart)
- [android/app/build.gradle.kts](file://android/app/build.gradle.kts)
- [ios/Runner/Info.plist](file://ios/Runner/Info.plist)
- [web/index.html](file://web/index.html)
- [linux/runner/CMakeLists.txt](file://linux/runner/CMakeLists.txt)
- [macos/Runner/Info.plist](file://macos/Runner/Info.plist)
- [windows/runner/CMakeLists.txt](file://windows/runner/CMakeLists.txt)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Running the App](#running-the-app)
5. [Development Workflow](#development-workflow)
6. [Platform-Specific Setup](#platform-specific-setup)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

## Introduction
This guide helps you set up and run the Albatal Store Flutter application on your local machine. It covers prerequisites, installation steps, running the app across platforms, development workflow tips, platform-specific requirements, verification steps, and troubleshooting guidance.

## Prerequisites
Before you begin, ensure your environment meets the following requirements:

- Flutter SDK installed and configured
  - Use a stable channel for best compatibility
  - Verify installation with flutter doctor and resolve any reported issues
- A supported code editor or IDE (for example, VS Code or Android Studio) with Flutter and Dart extensions enabled
- Git installed to clone the repository
- Platform toolchains as needed:
  - Android: Android Studio with Android SDK, emulator or physical device
  - iOS/macOS: Xcode and an iOS simulator or device (macOS only)
  - Web: A modern browser (Chrome recommended)
  - Linux: CMake, GCC, and related build tools
  - Windows: Visual Studio with C++ workload and Windows SDK
  - macOS desktop: Xcode and required frameworks

Tip: Run flutter doctor after installing tools to confirm everything is ready.

**Section sources**
- [README.md](file://README.md)

## Installation
Follow these steps to install and prepare the project locally:

1. Clone the repository
   - Use git to clone the project into a local directory
2. Navigate to the project root
   - Change into the top-level folder that contains pubspec.yaml
3. Install dependencies
   - Run flutter pub get to fetch all packages listed in pubspec.yaml
4. Optional: Configure environment variables
   - If the app requires backend credentials or feature flags, create a local secrets file as indicated by the project’s configuration files (for example, staging secrets template)
   - Ensure sensitive values are not committed to version control

After completing these steps, your project should be ready to run.

**Section sources**
- [pubspec.yaml](file://pubspec.yaml)
- [secrets-staging.env](file://secrets-staging.env)

## Running the App
Once dependencies are installed, you can run the app on your preferred target:

- Mobile devices and emulators
  - Connect a device or start an emulator
  - Run the app using the standard Flutter run command
- Desktop targets
  - Ensure the platform toolchain is installed and configured
  - Select the appropriate desktop target when running
- Web
  - Start a web server or use the built-in dev server to launch in a browser

Use the Flutter run command with the desired target flag to select the platform. For example, specify android, ios, linux, macos, windows, or chrome.

**Section sources**
- [lib/main.dart](file://lib/main.dart)

## Development Workflow
- Hot reload and hot restart
  - While running the app, use hot reload to apply most UI changes instantly without losing state
  - Use hot restart if structural changes require a full rebuild
- Debugging
  - Launch your app from your IDE to access breakpoints, variable inspection, and call stacks
  - Use logging statements to trace runtime behavior
- Common tasks
  - Add new dependencies by editing pubspec.yaml and running flutter pub get
  - Regenerate localization artifacts if you modify ARB files
  - Rebuild native platform projects when changing platform configurations

For more details about the app structure and features, consult the documentation files in the docs directory.

[No sources needed since this section provides general guidance]

## Platform-Specific Setup
### Android
- Requirements
  - Android Studio with Android SDK and platform tools
  - An emulator or a connected Android device
- Build configuration
  - The Android module uses Gradle Kotlin DSL; verify minSdkVersion and compileSdkVersion align with your SDK setup
- Running
  - Select an Android device or emulator and run the app

**Section sources**
- [android/app/build.gradle.kts](file://android/app/build.gradle.kts)

### iOS
- Requirements
  - macOS with Xcode installed
  - An iOS simulator or a physical device
- Configuration
  - Ensure Info.plist exists and has required keys for permissions and app metadata
- Running
  - Open the iOS workspace in Xcode or run via Flutter with an iOS target

**Section sources**
- [ios/Runner/Info.plist](file://ios/Runner/Info.plist)

### Web
- Requirements
  - A modern browser (Chrome recommended)
- Configuration
  - The web entry point and manifest are provided under the web directory
- Running
  - Run the app targeting Chrome or another supported browser

**Section sources**
- [web/index.html](file://web/index.html)

### Linux
- Requirements
  - CMake, GCC, and other build essentials
- Configuration
  - The Linux runner includes CMake configuration for building the desktop app
- Running
  - Run the app targeting Linux

**Section sources**
- [linux/runner/CMakeLists.txt](file://linux/runner/CMakeLists.txt)

### macOS (Desktop)
- Requirements
  - Xcode and required frameworks
- Configuration
  - The macOS runner includes Info.plist and build configs
- Running
  - Run the app targeting macOS

**Section sources**
- [macos/Runner/Info.plist](file://macos/Runner/Info.plist)

### Windows
- Requirements
  - Visual Studio with C++ workload and Windows SDK
- Configuration
  - The Windows runner includes CMake configuration for building the desktop app
- Running
  - Run the app targeting Windows

**Section sources**
- [windows/runner/CMakeLists.txt](file://windows/runner/CMakeLists.txt)

## Verification
To confirm your setup is correct:

- Check Flutter health
  - Run flutter doctor and address any reported issues
- List available devices
  - Use flutter devices to see connected devices and emulators
- Build and run
  - Build for each target platform you intend to support
- Validate assets and localization
  - Ensure fonts and images load correctly
  - Confirm localization files are processed if applicable

If the app launches successfully on your chosen platform(s), your environment is properly configured.

[No sources needed since this section provides general guidance]

## Troubleshooting
Common issues and resolutions:

- Flutter doctor reports missing components
  - Follow the prompts to install missing SDKs or plugins
  - Re-run flutter doctor until all checks pass
- Android build failures
  - Ensure Android SDK versions match those specified in the Android Gradle config
  - Sync Gradle and rebuild
- iOS build errors
  - Verify Xcode command line tools are selected
  - Clean derived data and rebuild
- Web build problems
  - Clear the web cache and rebuild
  - Try a different browser if issues persist
- Desktop builds fail
  - Install required compilers and SDKs for the target OS
  - Reconfigure CMake and regenerate build files
- Dependency resolution issues
  - Run flutter clean followed by flutter pub get
  - Update Flutter to a stable channel if necessary

For additional context, review the project’s README and documentation files.

[No sources needed since this section provides general guidance]

## Next Steps
- Explore the app structure under lib and features directories
- Read the walkthroughs and guides in the docs directory to understand core flows
- Set up Supabase integration according to the provided documentation
- Configure CI/CD pipelines and deployment scripts as needed

[No sources needed since this section provides general guidance]