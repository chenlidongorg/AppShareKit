# ScienceLabUI

The user-approved app-wide contract is maintained in the host repository at `Documentation/APP_CONSTITUTION.md` (2026-10-02). It supersedes historical examples below. Every existing and new tool follows the same layout and interactions; broad rollout waits for the user's first-three-tool physical-device acceptance.

Ordinary stages use system background and primary/secondary text in light and dark appearances. Only a documented scientific need, such as a dark-field interference experiment, selects `appearance: .dark`; controls, text and export must follow that same appearance. Scientific object/series colors retain their verified meaning and schematic disclosures.

The title/subtitle have no card, background or border. Only the subdued title appears initially; tapping it shows/hides the still more subdued subtitle. Focus hides both. Minimized readouts contain only the header. Maximized width is capped at 600 points in wide windows or 360 in narrow windows; height is one third of the unobscured current window. Its default anchor is immediately above the dock. The entire header except its toggle remains draggable in both modes, and each mode retains its own moved anchor.

The header's accessibility action uses the same minimized/maximized transition as its single state button. The public legacy expanded mode remains source compatible, but the normal toggle and accessibility action do not enter that third presentation.

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
    subtitle: LocalizedInfo.Subtitle,
    showsTitle: true, // The shared shell owns the title below its controls.
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

- `subtitle: String? = nil`: tap the title to reveal/hide this text; initially hidden
- `showsTitle: Bool = true`: subdued, unframed title below the top controls; omit duplicate outer titles
- `isCaptureConfirmed: Bool = false`: confirmation in the secondary menu icon and capture item
- `primaryAction: ScienceLabPrimaryAction = .simulation`
- `appearance: ScienceLabAppearance = .system`: `.dark` only for documented dark-field science
- `palette: ScienceLabPalette = .standard`
- `labels: ScienceLabLabels = .init()`
- `initialReadoutMode: ScienceLabReadoutMode = .minimized`

For non-simulation tools, `ScienceLabPrimaryAction(title: "Search", systemImage: "magnifyingglass", isEnabled: true)` changes the first button's presentation. Its callback is still `onToggleRun`; supply the tool's real action rather than introducing fake simulation state. The second button remains Common Parameters. Set `isEnabled` false when the primary action is unavailable.

`ScienceLabLabels` includes native-language resources for all 52 existing tool locales, including export and focus controls. Its public mutable properties allow existing host localizations to override individual values:

```swift
var labels = ScienceLabLabels()
labels.start = LocalizedInfo.localized("action.start")
labels.pause = LocalizedInfo.localized("action.pause")
```

Locale resources are checked for matching keys and valid property-list syntax; these checks do not replace runtime layout review.

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
- Bottom-centered pair of 48-point icon buttons: combined Start/Pause and Common Parameters, with localized accessibility names
- Upper-right order: Help, Advanced Parameters, More (capture/reset). Controls overlay the full-size stage; no header/dock row or outer margin consumes canvas space
- Upper-left focus toggle hides top controls, navigation dismissal, and readouts while retaining the bottom two controls. Restoring focus preserves readout position/mode and scientific state
- The host can supply `scienceLabNavigationAction` to place its existing dismissal callback in the chrome layer; an existing outer header should then be omitted
- Output data is inside the stage in an ultra-thin-material/native-glass panel
- Initially minimized means header only; all output data is hidden, with no data summary in the header
- The entire header except the toggle button is draggable; stage gestures, readout scrolling and sheet sliders remain separate
- One combined toggle expands directly to maximized data or minimizes back to the header. Its icon and VoiceOver label change with its state
- VoiceOver actions on the handle include center, reset position, minimize/restore and maximize/restore
- Normalized positioning preserves proportional placement across rotation, split view, panel size changes and maximize/restore
- Geometry sanitizes non-finite input and clamps panel origin and dimensions inside the stage
- Maximized readouts scroll vertically with no content-length limit. Overlaying the stage is intentional; minimizing immediately returns stage space
- An optional ordinary expanded mode remains available through VoiceOver actions; when too short for a usable scrolling region, it presents the header instead
- Resize, rotation, panel mode changes and leaving the active scene cancel an unfinished drag. GestureState discards that transient movement and retains the last committed normalized anchor
- Dock controls are always icon-only; header controls retain 44-point targets and full accessibility names
- At 740×300 points of safe-area space, the canvas receives all 740×300 points. Very small proposals still clamp data geometry; the containing host must supply enough room for accessible controls
- Shell respects the host safe area; it never consults a screen singleton or ignores safe areas

## Materials and accessibility

Glass applies only to controls and the data overlay, never the animation canvas. Swift 6.2+ and iOS/Mac Catalyst 26 checks jointly guard native `glassEffect` and `GlassEffectContainer`. Older SDKs compile the fallback branch; iOS 15–25 receives SwiftUI ultra-thin material. Reduce Transparency replaces these materials with opaque adaptive surfaces. Reduce Motion disables panel mode/location transitions. Scientific animation is intentionally left under the host's existing behavior.

Common-parameter sheets support medium/large detents on iOS 16+, use large at accessibility Dynamic Type, and use a normal system sheet on iOS 15. Knowledge opens its own large sheet.

UI automation identifiers include `scienceLab.stage`, `scienceLab.focus`, `scienceLab.primaryAction`, `scienceLab.commonParameters`, `scienceLab.advancedParameters`, `scienceLab.moreActions`, `scienceLab.capture`, `scienceLab.reset`, `scienceLab.knowledge`, `scienceLab.readouts`, `scienceLab.readouts.dragHandle`, `scienceLab.readouts.content`, and `scienceLab.readouts.toggle`. Presented sheets use `scienceLab.commonParameters.sheet` / `scienceLab.knowledge.sheet`; their Done buttons append `.done` to the respective sheet identifier.

## Image export and sharing

On iOS / Mac Catalyst 15+, `ScienceLabExportPresenter.present(image:title:presenter:onSave:)` opens one export preview per foreground window. Supply an explicit originating `UIViewController` when available. The optional host save callback receives the normalized image and a `Result<Void, Error>` completion; the host keeps control of photo-library permissions.

The preview prepares an original-pixel-size PNG with normalized orientation and alpha, shows the image and file dimensions, and offers native sharing and saving. Processing blocks repeated actions. Preparation, save and share errors show retry. Cancelling a native share returns to preview; closing the preview ignores late save callbacks and removes its temporary PNG. Cancelling cannot undo a save already sent to the host. iPad sharing uses the preview's own view with an in-bounds source rectangle.

## Validation status and required Mac checkpoint

The original delivery was authored on Linux without Swift or Xcode. The local Mac baseline test build found missing `contentImage` in an old share test, ambiguous `CGFloat.infinity` in geometry tests, and a missing CoreGraphics import that would become a Swift 6 error. These source issues have been repaired. On 2026-10-02, 34 native simulator tests passed (23 geometry, 10 PNG/export, 1 composer). The new stage and focus interaction still requires host UI acceptance; source and localization checks do not confirm it.

`Tests/ScienceLabUITests/ScienceLabGeometryTests.swift` contains 23 geometry XCTest cases covering edge clamps, panel sizes, tiny proposals, normalized positioning, rotation, restoration, compact landscape, Dynamic Type, invalid geometry and cancelled transient movement. CoreGraphics is imported conditionally so these geometry helpers remain usable without SwiftUI. `ScienceLabExportTests.swift` adds 10 UIKit tests for PNG pixels/orientation/alpha, temporary files, cancellation, deduplication and retry. Actual header dragging, scene interruption and iPad share anchoring still require runtime UI validation.

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
