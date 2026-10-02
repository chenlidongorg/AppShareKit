# ScienceLabUI

Dependency-free, generic SwiftUI presentation shell for the ScienceandExperiment tool family. Scientific models, controllers, captures, renderers, gestures and original data colors remain owned by the calling module.

## Integration

The standalone `Package.swift` is a validation harness. To integrate into AppShareKit, copy `Sources/ScienceLabUI` and `Tests/ScienceLabUITests`, then add:

```swift
// Package level (keep the existing iOS 13 / Mac Catalyst 13 minimums):
defaultLocalization: "en"

// Product:
.library(name: "ScienceLabUI", targets: ["ScienceLabUI"])

// Targets:
.target(name: "ScienceLabUI", dependencies: [], resources: [.process("Resources")]),
.testTarget(name: "ScienceLabUITests", dependencies: ["ScienceLabUI"])
```

Consumer targets add `.product(name: "ScienceLabUI", package: "AppShareKit")`, then `import ScienceLabUI`. All SwiftUI shell types are iOS 15 / Mac Catalyst 15 gated. AppShareKit's existing product and iOS 13 package minimum do not change. The app's iOS 16 minimum is sufficient.

```swift
ScienceLabShell(
    title: LocalizedInfo.Title,
    showsTitle: false, // An outer app header already owns this title.
    isRunning: viewModel.isRunning,
    isCaptureConfirmed: isCaptureConfirmed,
    onToggleRun: { viewModel.toggleRun() },
    onReset: { viewModel.reset() },
    onCapture: handleCapture,
    onParameters: { viewModel.isParameterSheetPresented = true },
    stage: { size in
        Image(uiImage: viewModel.stageImage(for: size))
            .resizable()
            .interpolation(.high)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged {
                viewModel.handleStageDrag(location: $0.location, size: size)
            })
    },
    controls: { quickControlsContent },
    readouts: { resultRows },
    knowledge: { explanationContent }
)
```

Keep all existing lifecycle/timer/controller/sheet modifiers on the host. `onParameters` opens advanced/uncommon settings. `controls` is presented by the bottom Common Parameters button in a separate sheet. Pass the controls' content, not an already-wrapped `NavigationView`, `Form`, `ScrollView`, or parameter sheet. The shell supplies navigation and scrolling. `readouts` and `knowledge` similarly receive plain content.

Stage receives its actual proposed `CGSize` every layout pass. Do not retain `UIScreen.main.bounds.height` sizing, outer scroll views or old fixed minimum stage heights when migrating. Rendering/capture aspect ratios remain the host's responsibility. The shell does not call scientific actions automatically when opening sheets or resizing.

### Public API

The shell has four generic view parameters (`Stage`, `Controls`, `Readouts`, `Knowledge`) and no `AnyView`. Required values are `title`, `isRunning`, the four callbacks and the four builders shown above. Optional values are:

- `showsTitle: Bool = true`: compact HUD title; use false for existing outer titles / hidden header style
- `isCaptureConfirmed: Bool = false`: confirmation in the secondary menu icon and capture item
- `primaryAction: ScienceLabPrimaryAction = .simulation`
- `palette: ScienceLabPalette = .standard`
- `labels: ScienceLabLabels = .init()`
- `initialReadoutMode: ScienceLabReadoutMode = .expanded`

For non-simulation tools, `ScienceLabPrimaryAction(title: "Search", systemImage: "magnifyingglass", isEnabled: true)` changes the first button's presentation. Its callback is still `onToggleRun`; supply the tool's real action rather than introducing fake simulation state. The second button remains Common Parameters. Set `isEnabled` false when the primary action is unavailable.

`ScienceLabLabels` loads English, Simplified Chinese and Traditional Chinese resources by default. Its public mutable properties allow existing host localizations to override individual values:

```swift
var labels = ScienceLabLabels()
labels.start = LocalizedInfo.localized("action.start")
labels.pause = LocalizedInfo.localized("action.pause")
```

Untranslated locales fall back to English. This target does not claim that all existing tool locales have new shell translations.

### Outer navigation header

`ScienceLabNavigationHeader(title:subtitle:isBack:labels:onDismiss:)` replaces an outer app wrapper's header without changing navigation selection or dismissal logic. `subtitle` defaults to nil, `isBack` to false, and `labels` to the localized defaults. Text and the 44×44 close/back button occupy separate HStack columns. The title truncates to one line; subtitle uses at most two lines and is visually omitted in compact vertical size classes or accessibility Dynamic Type. The full title and subtitle remain one VoiceOver header label in every layout. The close/back control inherits the environment palette and shared glass/material/opaque treatment. Identifiers are `scienceLab.navigation.title` and `scienceLab.navigation.dismiss`.

### Scientific colors

`ScienceLabPalette` separates interface `accent`, `positive`, `warning`, `canvas` and opaque accessibility surfaces from scientific color roles: position, velocity, acceleration, force, energy, substance, structure and reference.

```swift
let palette = ScienceLabPalette(scientificOverrides: [
    .velocity: existingVelocityColor,
    .acceleration: existingAccelerationColor
])
// New content can read @Environment(\.scienceLabPalette) and color(for:).
// Existing renderers and legends can retain their own colors unchanged.
```

Use textual labels, symbols and units in addition to color; the shell cannot infer or rewrite existing scientific semantics.

## Interaction and layout

- No outer ScrollView: the stage is visible immediately
- Bottom-centered pair: combined Start/Pause and Common Parameters
- Upper-right trailing button: Advanced Parameters; adjacent menu: capture/reset; dedicated information button: knowledge sheet
- Output data is inside the stage in an ultra-thin-material/native-glass panel
- Drag only its handle/title region; stage gestures, readout scrolling and sheet sliders remain separate
- Minimize, restore and maximize buttons have explicit VoiceOver labels
- VoiceOver actions on the handle include center, reset position, minimize/restore and maximize/restore
- Normalized positioning preserves proportional placement across rotation, split view, panel size changes and maximize/restore
- Geometry sanitizes non-finite input and clamps panel origin and dimensions inside the stage
- Expanded/maximized readouts scroll internally; ordinary output panel leaves the majority of stage area visible on normal supported screen sizes
- Compact-height or accessibility Dynamic Type uses icon-only dock labels with full accessibility names, leaving the type size untouched and preserving 44-point targets
- At 740×300 points of safe-area space, the stage is 184 points tall. A host must supply at least 116 points of available height for the fixed 44-point interactive chrome to fit; severely smaller arbitrary proposals cannot preserve both a useful stage and accessible controls
- Shell respects the host safe area; it never consults a screen singleton or ignores safe areas

## Materials and accessibility

Glass applies only to controls and the data overlay, never the animation canvas. Swift 6.2+ and iOS/Mac Catalyst 26 checks jointly guard native `glassEffect` and `GlassEffectContainer`. Older SDKs compile the fallback branch; iOS 15–25 receives SwiftUI ultra-thin material. Reduce Transparency replaces these materials with opaque adaptive surfaces. Reduce Motion disables panel mode/location transitions. Scientific animation is intentionally left under the host's existing behavior.

Common-parameter sheets support medium/large detents on iOS 16+, use large at accessibility Dynamic Type, and use a normal system sheet on iOS 15. Knowledge opens its own large sheet.

UI automation identifiers include `scienceLab.stage`, `scienceLab.primaryAction`, `scienceLab.commonParameters`, `scienceLab.advancedParameters`, `scienceLab.moreActions`, `scienceLab.capture`, `scienceLab.reset`, `scienceLab.knowledge`, `scienceLab.readouts`, `scienceLab.readouts.dragHandle`, `scienceLab.readouts.content`, `scienceLab.readouts.minimize`, and `scienceLab.readouts.maximize`. Presented sheets use `scienceLab.commonParameters.sheet` / `scienceLab.knowledge.sheet`; their Done buttons append `.done` to the respective sheet identifier.

## Validation status and required Mac checkpoint

This delivery was authored on Linux, which has **no Swift or Xcode toolchain installed**. It has **not been Swift-compiled**, and XCTest, previews, Simulator, VoiceOver, native iOS 26 materials and physical touch behavior have **not been executed** here. Source and localization consistency checks are not a substitute for a Mac build.

`Tests/ScienceLabUITests/ScienceLabGeometryTests.swift` contains 14 pure-geometry XCTest cases covering edge clamps, oversized bounds, minimized/expanded/maximized sizes, tiny proposals, drag normalization, rotation, restoration, compact landscape, Dynamic Type sizing and invalid geometry. Its geometry implementation imports Foundation only. SwiftUI files use `#if canImport(SwiftUI)`, so a future Linux Swift installation can run those geometry tests without SwiftUI, but no such test execution has occurred in this workspace.

Before rollout:

1. Build the integrated ScienceLabUI target and three representative migrated modules in the iOS 16 app
2. Run the geometry XCTest suite on an iOS Simulator scheme
3. Check iPhone portrait/landscape and iPad split view, including resize while the panel is dragged/minimized/maximized
4. Check both Common Parameters and Advanced Parameters, capture/reset, dedicated knowledge, and existing controller/timer lifecycle behavior
5. Check every Dynamic Type size, VoiceOver labels/actions, Reduce Transparency and Reduce Motion
6. Build with an older supported Xcode SDK (material branch) and Xcode 26/Swift 6.2+ (native glass branch)
7. Capture side-by-side stage screenshots and confirm no original renderer colors/units/legends changed

## Apple primary references

- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
- [Accessibility custom actions](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:))
- [Reduce Transparency environment](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)
- [Dynamic Type environment](https://developer.apple.com/documentation/swiftui/environmentvalues/dynamictypesize)
- [Presentation detents](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))
