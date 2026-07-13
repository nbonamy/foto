# Persistent thumbnail cache

## Goal

Make network-backed galleries fast after the first visit while improving first-pass thumbnail generation and preserving Foto's lazy visible-row loading.

## Decisions

- Cache thumbnails for all photos through one predictable pipeline; do not add network-volume detection.
- Store cache files under the system-resolved macOS caches directory at `com.nabocorp.foto/thumbnails/v1`.
- Generate 960 px native ImageIO thumbnails with at most two concurrent jobs. Preserve alpha-capable formats as PNG and encode photographic formats as JPEG.
- Key entries by cache version, absolute path, modification timestamp, file size, and requested pixel size. Flutter's decoded-image key uses the same identity.
- Cap the cache at 1 GB, touch entries on hits, and prune least-recently-used files to 900 MB in the background.
- Fall back to the original `FileImage` path if native generation or cache I/O fails.
- Add a localized **Clear Thumbnail Cache** application-menu action that clears disk and decoded-memory entries, then refreshes the gallery.

## Phases and commits

1. `chore: add thumbnail cache implementation plan`
2. `feat: add native thumbnail disk cache`
   - Add the platform-channel contract, ImageIO generation, atomic writes, bounded concurrency, LRU pruning, and native/Dart contract tests.
3. `feat: load gallery thumbnails from local cache`
   - Add the asynchronous cache image provider, metadata-derived identity, fallback behavior, and invalidation tests.
4. `feat: add thumbnail cache cleanup action`
   - Add localization and menu wiring, verify clearing behavior, run the full gate, and append learnings below.

Every phase runs focused tests plus analyzer and a macOS build before commit. The final phase runs all tests and both debug and release builds.

## Acceptance

- The first visible request generates one bounded thumbnail locally; subsequent app/folder visits do not read the remote original when metadata is unchanged.
- File modification, size change, rename, cache-format change, and manual clearing cannot reuse a stale thumbnail.
- Failures remain non-fatal and display the original image path as today.
- Large galleries remain lazy and native work never blocks the main thread.

## Learnings

_Append durable workflow and design learnings after implementation._
