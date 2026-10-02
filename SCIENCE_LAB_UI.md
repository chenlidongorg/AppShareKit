# ScienceLabUI

The user-approved app-wide contract is maintained in the host repository at `Documentation/APP_CONSTITUTION.md` (2026-10-02, subsequently amended). It supersedes historical examples below. The user confirmed the first-three-tool physical-device build 1.3 (10) on 2026-10-03 and authorized migration of the remaining tools. That clears the initial rollout gate; every additional tool still needs its own scientific review, genuine native execution, interaction checks and screenshots.

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

### Choosing stage gesture ownership

`stageInteractionPolicy: ScienceLabStageInteractionPolicy = .bounded2D` is an explicit integration choice. Existing callers keep the validated two-dimensional observation camera without source changes. Three-dimensional worlds and other viewers whose camera/object gestures are part of their scientific interaction select `.toolManaged`:

```swift
ScienceLabShell(
    title: LocalizedInfo.Title,
    isRunning: viewModel.isRunning,
    stageInteractionPolicy: .toolManaged,
    onToggleRun: viewModel.toggleRun,
    onReset: viewModel.resetWorldAndExperiment,
    onCapture: handleCapture,
    onParameters: showAdvancedParameters,
    stage: { size in NativeWorldView(size: size, model: viewModel) },
    controls: { quickControlsContent },
    readouts: { resultRows },
    knowledge: { explanationContent }
)
```

In `.toolManaged`, the shell places the stage directly in the existing SwiftUI hierarchy. It installs no shared `StageController`, nested hosting root, two-finger recognizers or affine camera transform. The tool keeps its own world-camera zoom/pan/orbit, object hit testing, cancellation, resize/background handling and export camera. Its scientific limits need not be the two-dimensional 1–3× range. The shell adds no rotation to either policy. Controls and readouts retain the same window coordinates, chrome, focus behavior and data layout in both policies.

More → Reset always calls the real `onReset`. Only `.bounded2D` also resets the shared observation camera to one times/zero offset. A native world reset must explicitly reset its own camera when appropriate. The shared stage emits no synthetic camera accessibility value in `.toolManaged`; a tool may expose meaningful world-camera accessibility on its own stage child. It must not report the inactive two-dimensional camera as a one-times world camera.

Renderer type alone does not select a policy. The current inventory includes SceneKit camera/editing stages in SpatialStructureKit and AlphaFoldBoardKit, embedded WebGL viewers that deliberately keep gestures in their canvas, and custom three-dimensional projection/orbit stages in BlochSphereDynamicsKit and MolecularGeometryVSEPRKit. These are `.toolManaged` candidates requiring individual scientific and runtime acceptance. A Canvas or bitmap renderer can still represent a three-dimensional world. No RealityKit stage was found in the inspected tool sources; future RealityKit viewers use the same explicit ownership rule.

Choose the policy for a stable scientific tool/mode, not for focus or playback changes. Changing policies swaps the stage presentation subtree and can recreate the tool's native view. The tool must define its world-state lifetime accordingly and verify the transition if it exposes one.

### Shared observation camera (`.bounded2D`)

The default `.bounded2D` shell supports two-finger pinch (1–3 times) and two-finger translation. Only the stage is transformed; controls, title, readouts and their hit targets remain in the shell's original window coordinates. One-times observation always shows the complete stage. Camera offsets are bounded by the enlarged content, so panning cannot expose empty space. No rotation gesture is added.

`ScienceLabViewportState` stores camera geometry separately from experimental state. A moving pinch centroid applies its translation once, using a common gesture baseline. Rotation/window resize preserves the committed scale and proportional pan, then clamps it to the current window. An unfinished gesture is discarded on resize, scene interruption or unsupported contact count. Focus preserves the camera. More → Reset returns the camera to 1×/zero offset and still invokes the tool's existing reset callback. Export remains the tool's complete scientific record, independent from this observation camera.

The UIKit bridge is a dedicated stage container with pinch, exactly-two-touch pan and an early two-finger intent gate. It is not a full-screen touch-catching overlay. Chrome/readouts are sibling views above the container; touches targeting them do not enter the stage's recognizers. The inner `UIHostingController` receives the original stage size and the complete SwiftUI environment, including appearance, scene and palette. It ignores the safe area already included by the outer shell. UIKit transforms the hosting view while retaining its original bounds; a scientific SwiftUI `DragGesture` in `.local` therefore receives original untransformed content coordinates. Do not apply another inverse mapping in a tool callback.

Single-finger experimental dragging must distinguish normal release from cancellation. In `.bounded2D`, a stage child view (not a parent outside the shell) can read `@Environment(\.scienceLabStageInteraction)`. Each native `StageController` owns a new `ScienceLabStageInteraction`; the shell does not retain this context across native controller lifetimes. The context is merged into the copied environment **before** the nested hosting root receives the entire environment. This ensures the child receives its actual controller's context even when its parent has a different context. Focus preserves the controller; a legitimate remount gets a new context, so deferred cleanup of the old controller cannot cancel the new one. `.toolManaged` does not inject or publish this shared cancellation context; native world tools own their gesture arbitration and cancellation rather than subscribing to the environment key's inactive default context.

`ScienceLabStageInteraction` publishes `isViewportManipulating` and `cancellationGeneration`. Subscribe to `$cancellationGeneration.dropFirst()` to cancel/restore unfinished object interaction, and synchronously guard `canReleaseObject` before treating a normal drag end as a scientific release. The shared container marks two-finger intent and publishes cancellation **before** cancelling the scientific child touch sequence. A single-finger movement immediately fails the intent gate and proceeds normally; no delay timer or test-only gesture is used. A third contact locks and reverts the entire camera sequence until all contacts lift.

Removing a stage immediately closes its release gate and callbacks without publishing during SwiftUI's render transaction. It invalidates queued updates and the old camera binding, then strongly retains the controller until the next main turn. Only then does it publish scientific cancellation and remove its gestures/hosting child using proper containment; it never re-enables a dismantled stage. This addresses confirmed teardown `SIGABRT` crashes in the pre-fix 235319 host matrices, whose preserved crash stacks enter `dismantle → interrupt → @Published cancellationGeneration → SwiftUI GraphHost` (`Audit/tests/viewport-dismiss-crashes/`). The new native regressions really remove/reinsert the SwiftUI representable and check deferred cancellation, callback deduplication, stale resize suppression and weak controller release. Their execution and the full corrected host matrices are recorded separately; historical failures are not replaced with source-review claims.

In `.bounded2D`, `scienceLab.stage` exposes JSON camera diagnostics (`scale`, `offsetX`, `offsetY`) to DEBUG UI tests. Release VoiceOver receives only the localized percentage, with no machine fields or stage HUD. Pure geometry/gesture-state tests and native hosting-coordinate/environment tests verify the contract; actual pinch/pan, return-gesture arbitration, multitouch interruption and iPad resizing require runtime acceptance for each adopted tool. The user's initial physical-device rollout gate has been completed; that does not certify additional tools or platform/window combinations.

### Public API

The shell has four generic view parameters (`Stage`, `Controls`, `Readouts`, `Knowledge`) and no `AnyView`. Required values are `title`, `isRunning`, the four callbacks and the four builders shown above. Optional values are:

- `subtitle: String? = nil`: tap the title to reveal/hide this text; initially hidden
- `showsTitle: Bool = true`: subdued, unframed title below the top controls; omit duplicate outer titles
- `isCaptureConfirmed: Bool = false`: confirmation in the secondary menu icon and capture item
- `primaryAction: ScienceLabPrimaryAction = .simulation`
- `appearance: ScienceLabAppearance = .system`: `.dark` only for documented dark-field science
- `stageInteractionPolicy: ScienceLabStageInteractionPolicy = .bounded2D`: `.toolManaged` retains native/scientific world-camera and object gestures
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

The new explicit stage-policy API is source-ready. Three added tests construct actual `ScienceLabShell`/UIKit/SceneKit hierarchies: an omitted policy retains the existing three-recognizer observation container; a tool-managed native scene preserves its camera, own recognizers, full-window identity transform and native object hit test across playback/chrome updates and resizing; a real policy change dismantles the old bounded controller with deferred cancellation and weak release without cancelling the new native world. Their native execution is pending scheduling. These tests do not synthesize touches or certify any tool's orbit/pan/object gesture behavior. Previously passed default-policy evidence below remains a baseline to rerun, not acceptance of this API change or a migrated 3D tool.

The initial policy run (`Audit/tests/AppShareKit-20261003-012503.xcresult`) passed 60/61 tests: all prior 58 tests, default-policy integration and real policy-transition cleanup passed. The native-world update test timed out while incorrectly requiring a chrome-only `isRunning` change to invoke an otherwise unchanged `UIViewRepresentable`. SwiftUI may legitimately preserve that unchanged scene without calling its update method. The revised test also changes an explicit scene-object radius and checks that the actual `SCNSphere` geometry updates while preserving the same native camera/view/recognizers; all full-window, hit-test and camera assertions remain. Its rerun is pending. The original failure is retained rather than counted as acceptance.

The first three independently pushed tool packages were also recompiled/tested against immutable remote AppShareKit revision `6d747a5d63eb36e0ac1182aa7f74d3d94a86b16d`: Spring 29, Acid 31 and Cell 21, **81/81 native tests**, with exact checkout/lock/source evidence in `Audit/tests/three-representatives-remote-final-verification-20261003-004029.json`. The user subsequently confirmed physical-device build 1.3 (10). This is the completed first-batch rollout checkpoint; final acceptance still requires the remaining tools and supported window/share/permission cases.

The corrected host matrices on 2026-10-03 actually passed **13/13 UI tests**: `Audit/tests/Host-viewport-dismiss-fixed-dark-20261003-002436.xcresult` (iPhone 17 Pro / iOS 26.5, dark, 7/7) and `Audit/tests/Host-viewport-compact-fixed-light-20261003-002436.xcresult` (iPhone SE 3 / iOS 17.2, light, 6/6). Both recorded zero skipped tests, empty runtime-warning lists, unchanged frozen sources and successful attachment export. No new app crashes were found after the four preserved pre-fix crash records.

These are two actual iPhone window sizes in portrait/landscape. Real XCTest pinch exercised the representative stages' 1–3× bounds, stable controls/readout frames, focus/rotation/background camera retention and More → Reset. Acid's scientific curve values stayed unchanged during observation. A real zoomed single-finger Spring mass drag/release started the experiment and continued beyond the former eight-second cutoff. Normal help/parameters/floating readout/export/share/return workflows were rerun; return assertions require the real Home page and a foreground running app, so a crash cannot pass merely because the tool disappeared. Evidence includes full-screen screenshots and accessibility attachments, whose visual comparison is tracked separately.

This automated matrix does **not** certify independent pure two-finger translation, third-finger cancellation, iPad split-view/window resizing, Mac windows or physical-device behavior. Those remaining gestures/platform cases need their own explicit runtime evidence. Remote dependency loading and the user's later physical-device confirmation are recorded above as separate completed checkpoints. No source, test or manifest was changed to record these host results.

The 2026-10-03 teardown repair passed **58/58 AppShareKit native tests** and **29/29 Spring tests**, zero failures/skips, using iPhone 18 Pro / iOS 27 (`3C973D2E-9BC0-471D-A498-D05A1DF5FB72`): `Audit/tests/{AppShareKit,SpringMassOscillatorLabKit}-20261003-002128.xcresult`. Actual SwiftUI removal with weak native-controller release took 1.051 s; actual stage identity replacement with distinct hosted environment contexts took 0.024 s; production queued-resize suppression/idempotent cancellation took 0.006 s. The native log contains no “Publishing changes from within view updates” warnings. The environment probe deliberately supplies a different parent interaction and confirms that the real child receives its own native controller's context. `Audit/tests/viewport-teardown-native-verification-20261003.json` records all four packages' unchanged Sources/Tests and byte-exact restored manifests.

This repair was necessary because the pre-fix host exit matrices recorded actual teardown crashes on supported runtime versions and render-update warnings. Preserved faulting stacks are under `Audit/tests/viewport-dismiss-crashes/`; the native tests above do not replace the corrected host dismissal/foreground/home tests on iOS 17.2 and 26.5. This run used the local Shared development graph for Spring and did not itself claim remote dependency acceptance. The later host/remote/user checkpoints above supply their respective evidence.

The final local viewport/continuous-playback checkpoint on 2026-10-02 passed **55 AppShareKit native tests** (25 readout geometry, 10 export, 15 viewport geometry/state, 4 stage-interaction/actual UIKit hosting, 1 existing composer) with zero failures/skips: `Audit/tests/AppShareKit-20261002-234643.xcresult`. The same frozen-source serial run passed Spring 29, Acid 31 and Cell 21. `Audit/tests/viewport-continuous-final-verification-20261002.json` records before/after hashes, unchanged Sources/Tests and exact restoration of all four manifests. Tool tests used the local Shared development graph; they do not prove final immutable remote dependency loading. The early 234003 AppShare/Spring test-only `CGFloat.infinity` overload compilation failures remain preserved; explicit types fixed them without changing the scientific formulas or weakening assertions.

The stage-hosting test really constructs SwiftUI/UIKit views and verifies original dimensions, appearance/scene/Dynamic Type/interaction environment forwarding and native coordinate conversion through the affine transform. It does not synthesize an experimental pinch or certify multitouch arbitration. Host UI tests, actual return/overlay/multicontact behavior, supported old-system operation and iPad windows/sharing remain separate per-tool acceptance requirements. The first three tools' host and user checkpoints are recorded above.

The original delivery was authored on Linux without Swift or Xcode. The local Mac baseline test build found missing `contentImage` in an old share test, ambiguous `CGFloat.infinity` in geometry tests, and a missing CoreGraphics import that would become a Swift 6 error. These source issues have been repaired. On 2026-10-02, 34 native simulator tests passed (23 geometry, 10 PNG/export, 1 composer). The new stage and focus interaction still requires host UI acceptance; source and localization checks do not confirm it.

`Tests/ScienceLabUITests/ScienceLabGeometryTests.swift` contains 23 geometry XCTest cases covering edge clamps, panel sizes, tiny proposals, normalized positioning, rotation, restoration, compact landscape, Dynamic Type, invalid geometry and cancelled transient movement. CoreGraphics is imported conditionally so these geometry helpers remain usable without SwiftUI. `ScienceLabExportTests.swift` adds 10 UIKit tests for PNG pixels/orientation/alpha, temporary files, cancellation, deduplication and retry. Actual header dragging, scene interruption and iPad share anchoring still require runtime UI validation.

For each additional tool's adoption:

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
- [UIPinchGestureRecognizer](https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer)
- [UIPanGestureRecognizer touch count](https://developer.apple.com/documentation/uikit/uipangesturerecognizer/minimumnumberoftouches)
- [Gesture recognizer failure precedence](https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizer(_:shouldberequiredtofailby:))
- [UIHostingController](https://developer.apple.com/documentation/swiftui/uihostingcontroller)

## Tool-managed world policy native verification (2026-10-03)

The final frozen-source run `Audit/tests/AppShareKit-20261003-013003.xcresult` passed 61/61 real iPhone18Pro/iOS27 tests, zero failures/skips/runtime warnings. The new native SceneKit cases preserve the real camera, own recognizers, object hit testing, full-window frame and object-radius updates; default omitted policy retains the original bounded2D recognizers. Actual policy replacement releases the old hosting controller and deferred interaction context. Before/after Sources/Tests/manifest SHA-256 maps are equal in package-run-20261003-013003.json. The prior 60/61 run remains recorded; its test wrongly assumed a chrome-only change must update an unchanged UIViewRepresentable. It was corrected to supply a genuine scientific SCNSphere radius input while retaining the camera and gesture invariants. This native checkpoint is not individual 3D tool or final host/window acceptance.
