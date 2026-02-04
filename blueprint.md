
# Project Blueprint

## Overview

This document outlines the architecture, features, and implementation details of the Flutter application. It serves as a living document, updated with each new feature or significant change.

## Implemented Features

### Core Application

- **Framework:** Flutter
- **State Management:** Provider
- **Theming:** A comprehensive theme with light/dark modes, custom fonts (Google Fonts), and component styling.
- **Authentication:** Google Sign-In integration for user authentication.

### Receipt Scanner

- **Functionality:** Allows users to pick an image of a receipt from their gallery and uses Firebase AI's Gemini model to extract the total amount.
- **UI:**
    - An image container to display the selected receipt.
    - A "Pick Image" button to open the image gallery.
    - An "Analyze Receipt" button to trigger the AI analysis.
    - A loading indicator while the analysis is in progress.
    - A display area for the extracted total amount.
- **Dependencies:**
    - `image_picker`: For selecting images from the gallery.
    - `firebase_ai`: For accessing the Gemini model.
    - `firebase_core`, `firebase_auth`, `cloud_firestore`: For Firebase integration.

## Current Task: Implementing the Receipt Scanner

**Objective:** To add a new feature that allows users to scan receipts and extract the total amount using Firebase AI.

**Steps Taken:**

1.  **Initial Scaffolding:** Began with a basic Flutter application structure, including a `main.dart` file and a placeholder for the receipt scanner feature.
2.  **Dependency Management:**
    *   Encountered and resolved numerous dependency conflicts, particularly with the `firebase_ai` package and its related Firebase dependencies.
    *   Iteratively updated the `pubspec.yaml` file, eventually using `flutter pub upgrade --major-versions` to bring all packages to their latest compatible versions.
3.  **Code Implementation:**
    *   Created the `receipt_scanner.dart` file, which contains the UI and logic for the feature.
    *   Initially, there were errors due to incorrect package imports and API usage (`FirebaseVertexAI` vs. `FirebaseAI`).
    *   Corrected the code to use the `firebase_ai` package and the `FirebaseAI.googleAI().generativeModel()` API.
4.  **Finalization:**
    *   Successfully resolved all dependency issues and code errors.
    *   The application is now in a working state, with the receipt scanner feature fully implemented.
