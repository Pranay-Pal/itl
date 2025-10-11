
<!-- Purpose: Short, actionable guidance so AI coding agents are productive in this repo -->
# Copilot instructions for the ITL Flutter app

```instructions

This repository contains two parallel codepaths: the active app code (under `lib/`) and an older, legacy app implementation kept in `lib2/`.

Key rule (read before editing or reusing code):

- `lib2` is a legacy, reference-only copy of the old UI and app flow. It exists to help engineers and automated agents understand the previous UI, navigation, and business logic patterns.
- Do NOT import code directly from `lib2` into `lib/` or the new app. Treat `lib2` as a sandboxed, read-only snapshot. Any code you need should be copied into the appropriate `lib/` location and adapted (namespaces, package imports, null-safety, architectural changes) — do not create cross-folder imports that would tightly couple the new app to the legacy folder.

Guidance for AI coding agents and contributors:

1. When you need to understand UI or logic:
   - Read files in `lib2/` to learn the previous implementation (widgets, routing, state shape, network calls, UX nuances). Use it as a walkthrough only.
   - Summarize relevant UI flows, data shapes, and helper utilities in comments or design notes before copying.

2. When reusing code from `lib2`:
   - Copy minimal, well-scoped logic into `lib/` or a new package under `lib/src/`.
   - Update imports to use package-relative imports (`package:itl/...`) and fix any null-safety or API mismatches.
   - Replace any direct file-system, platform, or build-time paths that referenced the legacy project layout.
   - Add tests for any behavior you port to ensure parity and to document intended behavior.

3. Prohibited actions:
   - Do not add `lib2` to the app's import graph (no `import '../lib2/...'` or package exports that expose lib2).
   - Do not rely on `lib2` during CI, builds, or runtime. CI should build the app using `lib/` only.

4. Practical tips for agents:
   - Prefer extracting a small code sample and running a focused static/format/lint check locally after porting.
   - When uncertain about intent, create a short note in the new code (`// FROM lib2: <file path> - reason for copy`) and open an issue or PR description that references the original `lib2` file.
   - If you discover sensitive values or secrets in `lib2`, flag them immediately — do not copy secrets into `lib/`.

5. Maintenance:
   - `lib2/` is allowed to remain in-tree as documentation. When the rewrite stabilizes, create a `lib2/README.md` explaining its purpose and then consider archiving or removing it in a follow-up cleanup PR.

If you are an automated agent editing this repo, follow these instructions strictly. If something in `lib2` seems required but can't be safely ported, add an item to the repository issues or a developer note instead of creating direct dependencies.

Minimal contract for porting code from `lib2` to `lib/`:

- Input: reference file(s) inside `lib2/` (paths, small snippets)
- Output: adapted, package-relative implementation under `lib/` with tests and updated imports
- Error modes: missing dependencies, runtime API changes, null-safety mismatches (fail fast with tests)
- Success: new code compiles and tests pass, and PR description documents the `lib2` origin

Edge cases to watch for:
- Widgets that depend on global singletons or legacy state must be refactored to new state management before copying.
- Differences in package versions/API signatures between legacy code and current dependencies.
- Platform-specific code (Android/iOS) may reference native channels that are no longer present.

Follow-up tasks for humans: create `lib2/README.md` that explains this policy and lists the highest-value files to inspect first (e.g., screens and pusher/chat services).

```
