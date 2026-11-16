# DEXTER VN Manual Drag Trainer V2 (iOS)

A real, app-local manual drag practice app using C++ coordinate processing through Objective-C++ and SwiftUI.

## Included
- Trainer canvas with target, finger path visualization, per-stroke measurements
- C++ smoothing / path-distance / duration / speed / straightness / stability metrics
- Sensitivity and smoothing settings (applied in trainer engine)
- Save/apply presets
- Session history and averages
- iOS document-directory JSON persistence
- SwiftUI tabs and responsive layout

## Build
1. Create a SwiftUI iOS project in Xcode (deployment target iOS 15+).
2. Add `Core/DexterCore.hpp`, `Bridge/DexterBridge.h`, `Bridge/DexterBridge.mm`, `UI/ContentView.swift`.
3. Ensure `.mm` is compiled as Objective-C++.
4. Add a bridging header with `#import "Bridge/DexterBridge.h"`.
5. Set C++ Language Dialect to C++17.
6. Use `ContentView()` as app root and build/sign IPA from Xcode.

## Honest scope
This is a standalone practice trainer. Its sensitivity/smoothing affects the trainer only, not Free Fire. iOS does not let a normal IPA inject touch filters into another game's controls. The app does not contain game hooks, aimbot, auto-fire, or recoil manipulation.
