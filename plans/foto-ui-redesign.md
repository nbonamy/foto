# Foto UI redesign

## Goal

Replace `macos_ui` with a Foto-owned desktop UI based on the airy gallery direction, with first-class light and dark themes, while preserving navigation, filesystem operations, viewer behavior, keyboard shortcuts, and scrolling performance.

## Guardrails

- Keep the existing `GridView.builder` and sidebar virtualization unless profiling proves a replacement is safe.
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

- [ ] Replace `MacosApp` with `MaterialApp` while preserving localization, providers, navigation, and platform menus.
- [ ] Add a Foto-owned window shell with stable sidebar, toolbar, gallery, and inspector regions.
- [ ] Add a lightweight resizable split pane for the inspector.
- [ ] Keep native window dragging limited to toolbar background regions that contain no controls.
- [ ] Hoist sidebar visibility into `BrowserState`; remove the `MacosWindowScope` dependency.
- [ ] Preserve gallery focus and current selection while toggling panels.
- [ ] Add widget tests for minimum/wide layouts, sidebar visibility, inspector resizing, focus preservation, and both brightnesses.

Commit: `feat: add foto window shell and split panes`

## Phase 3: toolbar and controls

- [ ] Add Foto icon buttons, grouped controls, tooltips, hover/pressed/focus states, and popup menus.
- [ ] Replace the back button and folder, sidebar, inspector, and sort controls.
- [ ] Preserve every existing callback and localized label.
- [ ] Add widget tests for each action, selected state, disabled state, tooltip, popup selection, and keyboard activation.

Commit: `feat: replace browser toolbar with foto controls`

## Phase 4: sidebar redesign

- [ ] Restyle Favorites and Devices with the airy gallery hierarchy in light and dark modes.
- [ ] Preserve the single enclosing scroll viewport, non-scrollable favorites reorder list, and fixed-extent virtualized directory rows.
- [ ] Preserve mounted-volume watching, favorite reordering/removal, tree expansion, selection, and context menus.
- [ ] Add a rebuild-boundary regression test proving sidebar scrolling does not rebuild the browser shell.
- [ ] Extend sidebar tests for hover, focus, selection, reorder behavior, empty favorites, and dark appearance.

Commit: `feat: redesign foto sidebar navigation`

## Phase 5: gallery redesign

- [ ] Make the gallery image-first with responsive tile sizing, refined spacing, and restrained labels.
- [ ] Add semantic hover, focus, selection-ring, rename, folder, loading, and empty states.
- [ ] Keep lazy `GridView.builder` construction and predictable row geometry.
- [ ] Avoid per-tile blur, shader masks, and expensive animated shadows.
- [ ] Add widget tests for image/folder tiles, rename behavior, light/dark selection, empty/loading states, and bounded child creation for large lists.

Commit: `feat: redesign gallery thumbnails and selection states`

## Phase 6: inspector redesign

- [ ] Replace the current plain table with an inset rounded inspector surface.
- [ ] Group file, capture, camera, and image metadata without changing metadata loading behavior.
- [ ] Add clear empty, loading, single-selection, multiple-selection, missing-file, and unsupported-metadata states.
- [ ] Reserve layout space for a future histogram without calculating one in this migration.
- [ ] Add focused tests for state transitions, stale async result rejection, grouping, overflow, and both appearances.

Commit: `feat: redesign foto metadata inspector`

## Phase 7: dialogs and remaining controls

- [ ] Replace `MacosAlertDialog`, `MacosSheet`, `PushButton`, and `MacosTextField` with Foto-owned Material-based components.
- [ ] Preserve destructive confirmation, prompt validation, rename cancellation, and keyboard behavior.
- [ ] Replace remaining `MacosTheme` typography and brightness reads with semantic theme tokens.
- [ ] Add dialog, prompt, rename, cancellation, semantics, and keyboard tests.

Commit: `feat: replace foto dialogs and text inputs`

## Phase 8: native appearance and dependency removal

- [ ] Keep System mode following macOS appearance changes live.
- [ ] Synchronize explicit Light and Dark choices with the native `NSVisualEffectView` appearance.
- [ ] Verify the viewer remains intentionally dark and unaffected by browser appearance switching.
- [ ] Remove every `macos_ui` import and remove the dependency from `pubspec.yaml` and the lockfile.
- [ ] Require `rg "macos_ui|MacosApp|MacosWindow|MacosTheme" lib test pubspec.yaml` to return no matches.
- [ ] Add appearance synchronization tests at the Dart/native-channel boundary.

Commits:

- `feat: sync foto appearance with the native window`
- `chore: remove macos ui`

## Phase 9: final verification

- [ ] Run `dart format --output=none --set-exit-if-changed lib test`.
- [ ] Run `flutter analyze`.
- [ ] Run every focused UI test suite.
- [ ] Run the complete `flutter test` suite.
- [ ] Build the macOS debug and release applications.
- [ ] Manually verify System, Light, and Dark modes at minimum and wide window sizes.
- [ ] Manually verify navigation, selection, rename, copy/paste/move/delete, context menus, inspector, sidebar, viewer transitions, fullscreen, and shortcuts.
- [ ] Profile a large folder and confirm that sidebar/gallery scrolling remains lazy and does not trigger shell-wide rebuilds.
- [ ] Review all commits individually before requesting merge approval.

Commit: `test: lock foto ui behavior and performance`

## Cancellation strategy

Until explicit merge approval, the redesign exists only in `/Users/nbonamy/src/foto-ui-redesign` on `codex/foto-ui-redesign`. Failure is cheap: stop work, keep `main` at stable commit `3abfe9a` or later, and delete the worktree and branch after confirmation. No redesign commit will be pushed or merged automatically.

## Key learnings

Append durable lessons here at the end of implementation. Focus on reusable Flutter desktop patterns, performance boundaries, theme architecture, testing strategy, and worktree/commit practices rather than a list of changed files.
