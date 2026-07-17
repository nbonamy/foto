# Folder-scoped similarity review

## Goal

Add a fast review workflow that finds visually similar photos in the open folder, compares the strongest candidates precisely, and offers an instant gallery loupe without turning Foto into a catalog-based photo library.

## Product boundary

- The open folder is the complete user-visible boundary. Similarity never searches parent, child, favorite, recent, or previously visited folders.
- Navigating away discards similarity results and comparison selection.
- Compare mode accepts two to four files from the open folder only.
- The loupe operates only on the currently hovered file tile.
- Versioned thumbnails and Vision feature prints may live in Foto's application cache, but they are implementation details rather than a cross-folder index or library.
- All analysis is explicit, cancellable, and read-only. Foto does not modify source images or write sidecars beside them.

## Interaction model

### Instant loupe

- Holding Space over a photo tile opens a rounded floating loupe near the pointer; releasing Space or leaving the tile closes it.
- The existing cached thumbnail appears immediately. Full-resolution detail replaces it when decoding completes.
- Pointer movement updates the inspected location continuously, accounting for the thumbnail's `BoxFit.cover` crop.
- No original file is loaded merely by hovering, and folders never show a loupe.

### Find similar

- A single selected photo enables **Find Similar** in the toolbar, Image menu, and context menu.
- Foto analyzes only file items in the current loaded folder snapshot. A review surface shows progress, allows cancellation, and fills incrementally with candidates ordered by distance.
- Results distinguish very-close candidates from broader visual similarity, but remain one ranked workflow rather than separate duplicate and similarity tools.
- The selected source stays pinned first. Users select one to three candidates and open Compare.
- Starting another scan or navigating folders cancels pending work and drops late results by generation token.

### Compare

- Compare opens two photos side by side, three with one wide pane above two panes, and four in a 2x2 grid.
- Zoom and pan are synchronized by default using normalized scale and focal position so differently sized images remain aligned.
- Sync can be toggled for independent inspection. Fit, 100%, and close actions remain directly available.
- Clicking a pane makes it active for metadata and keyboard actions. Compare itself is read-only in the first release.

## Technical design

### Loupe

- Extract cover-crop coordinate conversion into a pure, tested model.
- Add pointer reporting around file thumbnails without rebuilding the whole gallery for every event.
- Use a dedicated overlay widget with the cached provider as the immediate layer and `ImageFile` as the full-resolution layer.
- Keep full-resolution loading scoped to the lifetime of a held loupe.

### Visual features

- Add a native macOS Vision service using `VNGenerateImageFeaturePrintRequest` revision 1, compatible with Foto's macOS 12 deployment target.
- Generate feature prints from Foto's local 960 px cached thumbnail rather than reading the remote original again.
- Securely archive `VNFeaturePrintObservation` values beside the thumbnail cache under a separately versioned feature directory.
- Key observations by the same absolute path, modification timestamp, file size, pixel size, and cache version used by thumbnails.
- Bound native generation to two workers and expose a platform-channel distance operation with typed failures.
- Extend Clear Thumbnail Cache to clear feature prints as part of the same predictable user action.

### Similarity session

- Implement a folder-owned controller with source identity, immutable candidate snapshot, bounded scheduling, progress, cancellation, result ranking, and generation-token protection.
- Do not add a global database. Cached feature files accelerate repeat scans, while every visible result is derived from the current folder snapshot.
- Keep thresholds and result limits in a pure ranking policy with synthetic-distance unit tests; UI labels do not claim byte-for-byte identity.

### Synchronized comparison

- Isolate normalized zoom/focal-position propagation in a controller independent of widgets.
- Give each pane its own image controller and guard against feedback loops when applying shared state.
- Preload only the two to four compared originals and dispose all controllers when the route closes.

## Phases and checkpoint commits

1. `chore: add similarity review implementation plan`
   - Save this reviewed plan in the isolated worktree and verify the baseline.
2. `feat: add instant gallery loupe`
   - Add coordinate math, overlay behavior, Space lifecycle, and focused unit/widget tests.
   - Run focused tests, analyzer, and a macOS debug build before committing.
3. `feat: cache native visual feature prints`
   - Add Vision generation, secure persistence, identity invalidation, clear integration, platform contracts, and native source/contract tests.
   - Run focused tests, analyzer, and a macOS debug build before committing.
4. `feat: add folder similarity sessions`
   - Add bounded scheduling, cancellation, ranking, stale-result protection, progress state, and deterministic service tests.
   - Run focused tests, analyzer, and a macOS debug build before committing.
5. `feat: add similar photo review`
   - Add folder-scoped entry points, progressive results, candidate selection, empty/error/cancel states, localization, and widget tests.
   - Run focused tests, analyzer, and a macOS debug build before committing.
6. `feat: add synchronized photo comparison`
   - Add 2/3/4-pane layouts, normalized synchronized viewport state, active-pane controls, route integration, and controller/widget tests.
   - Run focused tests, analyzer, and a macOS debug build before committing.
7. `test: verify similarity review workflow`
   - Add light/dark golden coverage, integration seams from gallery to results to compare, README updates, and regression tests.
   - Run formatting, all tests, analyzer, and both debug and release macOS builds.
   - Append durable workflow and design learnings below before committing.

## Acceptance

- No similarity result can originate outside the open folder snapshot.
- Hover alone performs no full-resolution I/O; Space press/release controls the loupe deterministically.
- Repeated similarity scans reuse cached thumbnails and feature prints when source identity is unchanged.
- Modification, replacement, rename, cache-version change, or manual clearing cannot reuse a stale feature print.
- Cancellation prevents new analysis work and late native results cannot update a newer or disposed session.
- Compare supports exactly two to four current-folder photos and synchronized navigation remains stable without controller feedback loops.
- Existing large-gallery lazy rendering, viewer behavior, inspector behavior, and network-thumbnail cache remain green.

## Learnings

_Append durable workflow and design learnings after implementation._
