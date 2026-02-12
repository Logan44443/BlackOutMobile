# Blackout Card - iOS App

A private, group-based social coordination game. Pull your card, show up, or face the consequences.

## Overview

Blackout Card is a social accountability game where friends form private groups. Each member gets a limited number of "Blackout Cards" per period. Pulling a card commits you to a night out — if you don't show up, the group votes on whether to revoke your card privileges.

### Core Features

- **Groups**: Create and join private groups with configurable periods and card limits
- **Card Pulls**: Pull your Blackout Card to start a Night event and notify all group members
- **Night Feed**: Upload photos and videos during an active night for the group to see
- **Failure Votes**: Card pullers can initiate votes against members who don't show up (12-hour window)
- **Petition Restore**: Members who lost their card can petition the group for restoration
- **In-App Notifications**: Real-time banner notifications and a notification inbox
- **Admin Controls**: Period settings, card limits, and manual period resets

## Tech Stack

- **SwiftUI** (iOS 17+)
- **MVVM Architecture** with ObservableObject pattern
- **In-Memory DataStore** (designed for easy backend replacement)
- **Combine** for reactive data flow
- **PhotosUI** for media selection

## Project Structure

```
BlackOutMobile/
├── App/                    # App entry point & root navigation
│   ├── BlackOutMobileApp.swift
│   └── ContentView.swift
├── Models/                 # Data models (User, Group, Night, etc.)
│   └── Models.swift
├── Store/                  # In-memory data layer
│   └── DataStore.swift
├── ViewModels/             # Business logic & UI state
│   ├── AuthViewModel.swift
│   ├── GroupsViewModel.swift
│   ├── GroupHomeViewModel.swift
│   ├── NightViewModel.swift
│   ├── VoteViewModel.swift
│   └── AdminSettingsViewModel.swift
├── Views/
│   ├── Auth/               # Login & Sign Up
│   ├── Groups/             # Groups list & creation
│   ├── GroupHome/          # Group details & actions
│   ├── Night/              # Night feed & media upload
│   ├── Vote/               # Voting & petitions
│   ├── Admin/              # Group admin settings
│   └── Components/         # Reusable UI components
├── Utilities/              # Extensions & helpers
├── Assets.xcassets/        # App assets
└── Info.plist
```

## Getting Started

### Prerequisites

- Xcode 15+ (for iOS 17 SDK)
- macOS Sonoma or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the Xcode project)

### Setup

#### Option A: Using XcodeGen (Recommended)

1. Install XcodeGen if you haven't:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd BlackOutMobile
   xcodegen generate
   ```

3. Open the generated project:
   ```bash
   open BlackOutMobile.xcodeproj
   ```

4. Select a simulator and run (Cmd+R)

#### Option B: Manual Xcode Setup

1. Open Xcode → File → New → Project → iOS App
2. Set product name to "BlackOutMobile", interface to SwiftUI, language to Swift
3. Delete the template files Xcode generates
4. Drag the `BlackOutMobile/` source folder into the project navigator
5. Ensure all `.swift` files are included in the target's "Compile Sources"
6. Set deployment target to iOS 17.0
7. Build and run

### Demo Mode

On the login screen, tap **"Load Demo Data"** to populate the app with sample users and groups:

- **Alice Johnson** (alice@demo.com) — Admin of "Weekend Crew"
- **Bob Smith** (bob@demo.com) — Member of "Weekend Crew", Admin of "College Friends"
- **Charlie Davis** (charlie@demo.com) — Member of both groups
- **Diana Lee** (diana@demo.com) — Member of "Weekend Crew"

Demo data logs you in as Alice automatically.

## Architecture Notes

### DataStore

The `DataStore` is a singleton `@MainActor ObservableObject` that holds all app data in memory. It provides:

- CRUD operations for all data types
- Business logic enforcement (card limits, vote rules, petition limits)
- Automatic vote resolution via a 30-second timer
- In-app notification broadcasting with banner display

**Future Database Integration**: Replace `DataStore` methods with API calls to your backend. The ViewModel layer doesn't need to change — it only calls DataStore methods and observes published properties.

### Rules Implemented

| Rule | Implementation |
|------|---------------|
| One active Night per group | `pullCard()` checks for existing active night |
| Cards required to pull | Checks `cardsRemaining > 0` before allowing pull |
| Only puller starts votes | `startFailureVote()` verifies `night.pulledByUserId == currentUser` |
| One vote per user per case | `castVote()` checks for existing vote |
| 12-hour vote window | `closesAt = opensAt + 12 hours`, auto-resolved by timer |
| Majority threshold | Yes votes must exceed No votes (ties = fail, no votes = fail) |
| One petition per period | Checks existing petition since `lastResetAt` |
| Period reset | Restores all cards, closes active night, clears petition tracking |

## Roadmap

- [ ] Backend database integration (Firebase/Supabase/custom API)
- [ ] SMS/Push notifications
- [ ] Real-time updates via WebSockets
- [ ] User profile with avatar upload
- [ ] Group invite links/codes
- [ ] Video playback in night feed
- [ ] Scheduled period auto-reset
- [ ] Group chat
