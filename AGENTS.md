# Flectar Mail agent guide

This file collects the review expectations that maintainers have applied to
Flectar Mail pull requests. Read it before preparing a branch, pushing, or
asking for review.

`CONTRIBUTING.md` is the source of truth for contribution policy. A current
maintainer review comment overrides this file.

Distilled from the review threads on PRs #76, #79, #80, #84, #85, #139, #150,
#151, #152, #162, #163, #165, #209, and the privacy split in #282-#284.
Last updated: 2026-11-09.

## Read first

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contribution policy, licensing,
  translations, local validation.
- [`platform/README.md`](platform/README.md) — platform layers and capability
  aliases.
- [`.agents/skills/slint/SKILL.md`](.agents/skills/slint/SKILL.md) — Slint
  language, layout, screenshots and runtime checks.
- [`.github/pull_request_template.md`](.github/pull_request_template.md).

## Pull request shape

- One logical change per PR. Split unrelated fixes, build-environment changes,
  shared UI and platform hosts into separate PRs.
- Stack dependent PRs and link them in the description. Keep the first PR
  reviewable on its own; retarget the stacked PR after the base lands.
- Merge current `main` before asking for review. Resolve conflicts in the
  branch; do not leave them to the maintainer.
- Maintainers may push follow-up commits to your branch. **Pull before your
  next push. Do not force-push over maintainer commits.**
- Prefer adding a commit over rewriting a branch once review has started.
- Include the problem, the chosen solution, tests and user-visible effects in
  the PR description. Mention any platform or privacy work that was
  deliberately left out.
- Do not edit `lang/*/LC_MESSAGES/*.po`; Weblate owns the catalogs. Only commit
  the regenerated `lang/flectar-mail.pot`.
- Do not submit credentials, signing material, real mailbox data, or personal
  fixture data.

## Shared architecture first

Reviewers consistently redirect platform-specific shortcuts into shared seams:

- Host services belong on `PlatformContext`, not in global registries:
  `external_urls`, `notifications`, `privacy_consent`, documents, credentials
  and OAuth redirects.
- Attachments, backups, snapshots and certificate import go through
  `DocumentProvider` and `documents::run_request`; do not call a platform
  picker directly from shared code.
- Notifications go through the shared `NotificationHost` /
  `NotificationPublisher` seam. Do not hard-code a bundle name or ability
  name; build the `want` from `context.abilityInfo`.
- Shared code selects behavior with capability aliases (`mobile`, `desktop`,
  `linux_desktop`), not operating-system names.
- Do not reach into private `i_slint_core` internals. Use public APIs such as
  `slint::platform::duration_until_next_timer_update()`.
- Run asynchronous host work on the runtime. Do not block or await provider
  futures on the UI thread; mobile pickers use the presentation-hold pattern.
- When a shared behavior exists on Android and iOS, match it on a new host
  instead of inventing a different local policy.

## OpenHarmony platform rules

### Documents and pickers

- Stage picked files under generated cache names; keep the provider's display
  name as metadata through `ImportedDocument::with_name(...)`. Validate empty,
  `.`, `..`, `/`, `\` and control characters.
- Limits match Android and iOS:
  - one document: 512 MiB;
  - several documents: bounded by free space with a 64 MiB reserve;
  - single pick/save timeout: 10 minutes;
  - multi-select timeout: 1 hour.
- Check limits before copying. Do not add an arbitrary file-count clamp when
  the picker has no such limit.
- Release the presentation hold as soon as the picker window closes, before
  the copy, so a large import does not freeze the window.
- Multi-select must stage files one by one and discard partial copies on
  error or when the native side has given up.

### Input and IME

- Tell the IME when a field is a password field; do not always attach as
  `TEXT`.
- Subscribe to `sendFunctionKey` for soft-keyboard Enter.
- Place the candidate window from the surface's own screen position
  (`getComponentUtils().getRectangleById(...).screenOffset`), not from an
  assumed window origin. This must work maximized, full-screen, split and
  floating.
- Register the window listener once; use the surface's `onAreaChange` for
  layout changes.
- Reset modifiers and Caps Lock on focus loss. Do not assume modifier state
  survives window switches.

### Rendering and lifecycle

- Surface events carry an epoch. Reject stale queued `Surface` /
  `SurfaceDestroyed` events and hold the gate across GPU attach.
- Request a redraw after `SurfaceShown` and after a surface is recreated at the
  same size. Do not keep presenting while hidden.
- `present.rs` must check `stride >= row_bytes` and
  `(height - 1) * stride + row_bytes <= handle.size` before mapping or
  copying.
- Wait on and close the release fence; do not leak one fd per frame.
- Catch unwinding panics on the Slint thread, log the payload and fail fast
  instead of leaving a frozen window.
- On background, emit `suspendPreview`; release and reopen PDF resources.
- Use the public timer helper for idle wakeups; do not poll a private
  `i_slint_core` API.

### Credentials and assets

- Do not delete an Asset Store row before proving it is unreadable. A readable
  secret must survive a failed overwrite.
- Keep empty secrets as markers where the service rejects empty values.
- Respect the Asset Store secret-size limit; chunk large secrets the same way
  the Windows credential store does.

### Fonts

- Keep one font fallback policy. Export the font directory, Han families and
  fallback scripts from the backend, and let the shared renderer consume them.
- Do not name OpenHarmony fonts in shared code or add a platform-specific font
  check script.

### Packaging and CI

- `PackageHap` still fails locally with `00308018`; the project packages with
  `restool` and the existing `build-hap.sh` path. Do not regress that path.
- Pass the selected `PROFILE` to hvigor; strip release native libraries; ship
  `THIRD_PARTY_NOTICES.md`, `LICENSES/` and the PDFium license.
- Hide the app-icon switch on OpenHarmony: `enableDynamicIcon` is a system API.
- Run the OHOS clippy gate:
  `RUSTFLAGS="-D warnings" cargo clippy --manifest-path platform/ohos/Cargo.toml --locked -- -D warnings`.
- Derive SDK paths from `OHOS_SDK_ROOT` / `OHOS_SDK_NATIVE`. Do not hard-code a
  Cellar version, and keep the legacy `OHOS_SDK`, `OHOS_SYSROOT` and
  `OHOS_CXX_INC` variables on the same package.
- Device verification is required for OpenHarmony platform changes. List the
  flows you exercised on the HarmonyOS 2-in-1 (API 26): startup, IME, clipboard,
  PDF preview, picker flows, notifications, surface resize/teardown.

## Privacy and consent

Privacy work is deliberately split:

- Do not bundle a policy copy. Link to `https://flectar.com/mail/privacy/` in
  the UI language; the shared app already provides the localized URL.
- Do not intercept URLs in `bridge.rs`. Use the shared
  `privacy-policy-url` property.
- Keep the first-launch consent gate out of the host PR. The shared UI PR adds
  the `PrivacyConsent` service and the Settings -> About row; the platform PR
  adds the gate and the host callback.
- The consent screen must gate the XComponent and the native mail runtime.
  Nothing may process mail before acceptance.
- Request notification permission only after consent, not from
  `aboutToAppear` or the ability's page-load callback.
- Consent copy comes from HarmonyOS string resources, not ArkTS literals:
  English, Simplified Chinese, Spanish, Turkish and Russian, with English as
  the base fallback. All Chinese locales (including Traditional) use the
  Simplified Chinese page/copy; other unsupported languages fall back to
  English.
- Settings -> About must allow withdrawal. Clear the stored preference and
  exit; leave local mail and settings for the separate delete action.
- Follow the effective `AppTheme`, including presets, custom palettes and
  light/dark. Persist an `AppTheme` snapshot over the ArkTS bridge and use it
  for page background, surface, text, border, accent and primary colors.
- Draw consent icons with theme-colored strokes (ArkUI `Shape`/`Path`), not
  fixed-color SVGs.
- Keep shared withdrawal copy in Slint and Weblate; do not add it to the OHOS
  string resources.

## Translations

- Run `scripts/update-translation-template.sh` after changing `.slint` strings.
  Commit only `lang/flectar-mail.pot`.
- Do not edit `.po` catalogs; Weblate merges the template.
- Keep existing strings stable. Do not reflow or `--no-wrap` catalogs.
- New HarmonyOS resources need entries in every supported `string.json`
  language with the English base fallback.

## Validation before asking for review

Run the checks relevant to the change:

```bash
cargo fmt --all -- --check
python3 scripts/check-platform-gates.py
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked
slint-viewer --check ui/app.slint
```

For OpenHarmony changes, also run:

```bash
cargo fmt --manifest-path platform/ohos/Cargo.toml --all -- --check
RUSTFLAGS="-D warnings" cargo clippy --manifest-path platform/ohos/Cargo.toml --locked -- -D warnings
cargo check -p flectar-mail-ohos
# hvigor CompileArkTS / CompileResource via scripts/build-hap.sh
```

UI changes:

- Render the actual UI, not just a compile check.
- Check light and dark themes and the documented phone/tablet preview sizes.
- For mobile changes, verify on a device; do not claim device-tested without
  the device run.

## Review checklist

- [ ] One logical change, or a clearly stacked PR with a linked base.
- [ ] Branch merged with current `main`; no unresolved conflicts.
- [ ] No force-push over maintainer commits.
- [ ] Host services use `PlatformContext` / shared seams.
- [ ] No private `i_slint_core` APIs.
- [ ] Async host work is on the runtime; UI thread is not blocked.
- [ ] Platform behavior matches Android/iOS where the same feature exists.
- [ ] Tests cover the changed behavior and review follow-ups.
- [ ] `cargo fmt`, clippy, tests, platform gates and translation checks pass.
- [ ] UI rendered in light/dark (and phone/tablet for responsive work).
- [ ] OpenHarmony changes verified on the device with the flows listed in the PR.
- [ ] No `.po` edits; `.pot` regenerated.
- [ ] No bundled privacy policy, URL interception, or consent gate in the host PR.
- [ ] Third-party sources/licenses and generative-tool assistance disclosed.
- [ ] No credentials, mailbox data, signing material or personal data.
