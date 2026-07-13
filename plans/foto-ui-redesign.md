# Foto UI redesign

## Goal

Replace `macos_ui` with a Foto-owned desktop UI based on the airy gallery direction, with first-class light and dark themes, while preserving navigation, filesystem operations, viewer behavior, keyboard shortcuts, and scrolling performance.

## Guardrails

- Keep gallery and sidebar construction virtualized; dynamic tiling must use deterministic row geometry rather than eagerly laying out the whole library.
- Do not place blur, shaders, or animated effects inside thumbnail or sidebar scrolling subtrees.
- Use glass-like translucency only for stable chrome surfaces: sidebar, toolbar, and inspector.
- Do not add a third-party glass or desktop-widget library.
- Do not add mockup-only features such as albums, maps, or histograms during this migration.
- Add or update tests in every implementation increment.
- Run focused tests after each edit, then `flutter analyze` and the full test suite before every commit.
- Keep each commit independently buildable and revertible.
- Do not merge the worktree branch without explicit approval.

## Visual contract

Both appearances use the same semantic roles rather than direct color checks in widgets:

- canvas
- sidebar surface
- floating chrome surface
- elevated surface
- primary and secondary text
- divider and outline
- hover and pressed states
- selection fill and selection ring
- accent and destructive colors

The light appearance uses pearl and cool-gray surfaces with a blue-lilac accent. The dark appearance uses deep ink and graphite surfaces with a brighter lavender accent. Dark mode is designed independently and must not be implemented by mechanically inverting the light palette.

The photo gallery follows the approved mockup literally: image files have no persistent filename labels and retain their decoded aspect ratios in compact justified rows. Folder tiles keep a restrained name overlay because they must remain identifiable.

## Phase 0: establish the rollback boundary

- [x] Commit and push the sidebar scrolling and tree-virtualization work to `main`.
- [x] Create `/Users/nbonamy/src/foto-ui-redesign` from stable commit `3abfe9a`.
- [x] Create branch `codex/foto-ui-redesign`.
- [x] Resolve Flutter dependencies without copying environment files; the source repo has no `.env` files.
- [x] Run and record the worktree baseline: analyzer, focused sidebar tests, full tests, and macOS debug build.

Baseline verification on 2026-07-13: `flutter analyze` passed, all 3 focused sidebar tests passed, all 65 tests passed, and `flutter build macos --debug` produced `foto.app` successfully. Xcode emitted only the existing always-run Flutter Assemble script warning.

Commit: `chore: add foto ui redesign plan`

## Phase 1: theme foundation

- [x] Replace the current mutable `AppTheme` shell with semantic Foto theme definitions.
- [x] Add complete light and dark `ThemeData` plus a `ThemeExtension` for Foto-specific surfaces and interaction colors.
- [x] Persist System, Light, and Dark appearance through `Preferences`.
- [x] Configure macOS-appropriate typography, focus treatment, tooltips, menus, and scroll behavior.
- [x] Add tests for token completeness, brightness, contrast-critical pairs, preference defaults, persistence, and invalid stored values.

Phase 1 verification: focused theme and preference tests passed, `flutter analyze` passed, formatting was clean, and all 70 tests passed.

Commit: `feat: add foto light and dark theme foundations`

## Phase 2: custom window shell

- [x] Replace `MacosApp` with `MaterialApp` while preserving localization, providers, navigation, and platform menus.
- [x] Add a Foto-owned window shell with stable sidebar, toolbar, gallery, and inspector regions.
- [x] Add a lightweight resizable split pane for the inspector.
- [x] Keep native window dragging limited to toolbar background regions that contain no controls.
- [x] Hoist sidebar visibility into `BrowserState`; remove the `MacosWindowScope` dependency.
- [x] Preserve gallery focus and current selection while toggling panels.
- [ ] Add widget tests for minimum/wide layouts, sidebar visibility, inspector resizing, focus preservation, and both brightnesses.

Commit: `feat: add foto window shell and split panes`

## Phase 3: toolbar and controls

- [x] Add Foto icon buttons, grouped controls, tooltips, hover/pressed/focus states, and popup menus.
- [x] Replace the back button and folder, sidebar, inspector, and sort controls.
- [x] Preserve every existing callback and localized label.
- [ ] Add widget tests for each action, selected state, disabled state, tooltip, popup selection, and keyboard activation.

Commit: `feat: replace browser toolbar with foto controls`

## Phase 4: sidebar redesign

- [x] Restyle Favorites and Devices with the airy gallery hierarchy in light and dark modes.
- [x] Preserve the single enclosing scroll viewport, non-scrollable favorites reorder list, and fixed-extent virtualized directory rows.
- [x] Preserve mounted-volume watching, favorite reordering/removal, tree expansion, selection, and context menus.
- [ ] Add a rebuild-boundary regression test proving sidebar scrolling does not rebuild the browser shell.
- [ ] Extend sidebar tests for hover, focus, selection, reorder behavior, empty favorites, and dark appearance.

Commit: `feat: redesign foto sidebar navigation`

## Phase 5: gallery redesign

- [x] Make the gallery image-first with responsive justified rows, refined spacing, and no persistent image labels.
- [x] Add semantic hover, focus, selection-ring, rename, folder, loading, and empty states.
- [x] Keep lazy row construction and predictable, testable geometry.
- [x] Avoid per-tile blur, shader masks, and expensive animated shadows.
- [ ] Add widget tests for image/folder tiles, rename behavior, light/dark selection, empty/loading states, and bounded child creation for large lists. Bounded construction is now covered; the remaining states still need focused coverage.

Commit: `feat: redesign gallery thumbnails and selection states`

Dynamic tiling checkpoint: the custom justified-row algorithm preserves ordering, fills complete rows, avoids stretching the final row, and computes finite indexed geometry for 10,000 items. Visible image decodes feed their real aspect ratios back into a debounced relayout without a separate metadata read, which avoids eagerly opening every file on network folders. Analyzer, all 82 tests, and the macOS debug build passed.

Network-performance checkpoint: opening a chronologically sorted folder no longer starts EXIF reads for every image. The gallery uses creation dates from the native batch directory scan, keeps EXIF loading selection-driven, and builds only visible justified rows. Tests cover a 10,000-file network listing with zero image-metadata channel calls and bounded widget construction while scrolling.

## Phase 6: inspector redesign

- [x] Replace the current plain table with an inset rounded inspector surface.
- [x] Group file, capture, camera, and image metadata without changing metadata loading behavior.
- [x] Add clear empty, loading, single-selection, multiple-selection, missing-file, and unsupported-metadata states.
- [ ] Reserve layout space for a future histogram without calculating one in this migration.
- [ ] Add focused tests for state transitions, stale async result rejection, grouping, overflow, and both appearances.

Commit: `feat: redesign foto metadata inspector`

Inspector checkpoint: the inspector now uses compact grouped cards for file, capture, camera, and image data, filters empty values, and presents explicit empty and loading states. Focused inspector tests, analyzer, all 88 tests, and a macOS debug build passed.

## Phase 7: dialogs and remaining controls

- [x] Replace `MacosAlertDialog`, `MacosSheet`, `PushButton`, and `MacosTextField` with Foto-owned Material-based components.
- [x] Preserve destructive confirmation, prompt submission, rename cancellation, and keyboard behavior.
- [x] Replace remaining `MacosTheme` typography and brightness reads with semantic theme tokens.
- [ ] Add dialog, prompt, rename, cancellation, semantics, and keyboard tests.

Commit: `feat: replace foto dialogs and text inputs`

## Phase 8: native appearance and dependency removal

- [x] Keep System mode following macOS appearance changes live.
- [x] Synchronize explicit Light and Dark choices with the native `NSVisualEffectView` appearance.
- [ ] Verify the viewer remains intentionally dark and unaffected by browser appearance switching.
- [x] Remove every `macos_ui` import and remove the dependency from `pubspec.yaml` and the lockfile.
- [x] Require `rg "macos_ui|MacosApp|MacosWindow|MacosTheme" lib test pubspec.yaml` to return no matches.
- [x] Add appearance synchronization tests at the Dart/native-channel boundary.

Commits:

- `feat: sync foto appearance with the native window`
- `chore: remove macos ui`

Dependency-removal checkpoint: `macos_ui` and its transitive `macos_window_utils` dependency are absent from the resolved package graph. The zero-reference search passed, analyzer passed, all 84 tests passed, and the macOS debug application built successfully.

Appearance checkpoint: System remains the persisted default, the View menu exposes System/Light/Dark choices, and the Dart preference synchronizes explicit choices with `NSWindow.appearance` while System clears the override. The native-channel test, analyzer, all 85 tests, and a macOS debug build passed.

## Phase 9: final verification

- [x] Run `dart format --output=none --set-exit-if-changed lib test`.
- [x] Run `flutter analyze`.
- [x] Run every focused UI test suite.
- [x] Run the complete `flutter test` suite.
- [x] Build the macOS debug and release applications.
- [ ] Manually verify System, Light, and Dark modes at minimum and wide window sizes.
- [ ] Manually verify navigation, selection, rename, copy/paste/move/delete, context menus, inspector, sidebar, viewer transitions, fullscreen, and shortcuts.
- [ ] Profile a large folder and confirm that sidebar/gallery scrolling remains lazy and does not trigger shell-wide rebuilds.
- [ ] Review all commits individually before requesting merge approval.

Commit: `test: lock foto ui behavior and performance`

Post-redesign regression checkpoint: the fullscreen viewer now saves and restores the normal window level while temporarily rendering above the macOS menu bar. The inspector keeps EXIF objects on the main isolate, transfers only primitive image dimensions from its worker isolate, and has a selection-driven widget regression test. Focused tests, analyzer, all 96 tests, and the macOS debug build passed before relaunching the rebuilt app.

Fullscreen-info checkpoint: the viewer overlay no longer depends on inherited browser typography or the legacy neon-green style. It owns explicit 13-point SF system typography with fallbacks, regular weight, stable leading, tabular numerals, safe-area spacing, long-path truncation, and a dark rounded surface. Preference reactivity and the rendered overlay are covered by focused and golden tests; analyzer, all 99 tests, and the macOS debug build passed.

## Cancellation strategy

Until explicit merge approval, the redesign exists only in `/Users/nbonamy/src/foto-ui-redesign` on `codex/foto-ui-redesign`. Failure is cheap: stop work, keep `main` at stable commit `3abfe9a` or later, and delete the worktree and branch after confirmation. No redesign commit will be pushed or merged automatically.

## Key learnings

- A batch directory scan is only fast if the gallery does not immediately undo the win with per-file EXIF work. Network-sensitive metadata must remain visible-item or selection driven.
- Justified rows can keep photographic variety without sacrificing virtualization: compute small indexed row geometry eagerly, but construct only the visible row widgets.
- Decoded thumbnail dimensions are the cheapest trustworthy aspect-ratio source. Stable placeholder ratios prevent a uniform-grid flash without a separate metadata pass.
- A semantic `ThemeExtension` keeps owned chrome coherent across light and dark appearances and makes removing a UI framework dependency incremental rather than all-or-nothing.
- Deterministic light/dark golden previews are valuable when host screenshot permissions are unavailable, while focused geometry and channel-call tests protect the performance properties the screenshots cannot show.
- Keeping every migration checkpoint in an unpushed worktree branch made aggressive replacement safe: stable `main` never moved, and each verified slice remains independently reversible.
- Worker isolates should return primitive DTOs, not third-party metadata objects whose sendability is outside Foto's control; partial metadata failures must not erase already available file information.
- Borderless screen-sized windows still participate in macOS window levels. Covering the menu bar requires a temporary level change as well as the full screen frame, followed by exact restoration on exit.
- Fullscreen overlays should own their typography and safe-area behavior instead of inheriting browser theme defaults; a focused golden catches font fallback, spacing, and overflow regressions that structural widget tests miss.
