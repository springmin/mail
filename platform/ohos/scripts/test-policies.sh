#!/bin/sh
# Run the pure OHOS policy tests without the DevEco previewer/local-test
# runtime. The canonical suite is Hypium under entry/src/test; this script is a
# self-hosted/CI fallback that executes the same policy classes with Bun.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COMMON="$HERE/../shell/entry/src/main/ets/common"
command -v bun >/dev/null 2>&1 || {
    echo "bun is required for this fallback (Hypium tests remain canonical)" >&2
    exit 2
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/flectar-policy.XXXXXX")
trap 'rm -rf "$TMP"' 0
cp "$COMMON/PickerPolicy.ets" "$TMP/PickerPolicy.ts"
cp "$COMMON/ImeFocusState.ets" "$TMP/ImeFocusState.ts"
cp "$COMMON/ColorSchemePolicy.ets" "$TMP/ColorSchemePolicy.ts"

cat > "$TMP/test.ts" <<'TS'
import assert from 'node:assert';
import { PickerPolicy } from './PickerPolicy.ts';
import { ImeFocusAction, ImeFocusState } from './ImeFocusState.ts';
import { ColorSchemePolicy } from './ColorSchemePolicy.ts';

assert.equal(PickerPolicy.MAX_IMPORT_BYTES, 50 * 1024 * 1024);
assert.equal(PickerPolicy.isAllowedSize(0), true);
assert.equal(PickerPolicy.isAllowedSize(25 * 1024 * 1024), true);
assert.equal(PickerPolicy.isAllowedSize(PickerPolicy.MAX_IMPORT_BYTES), true);
assert.equal(PickerPolicy.isAllowedSize(PickerPolicy.MAX_IMPORT_BYTES + 1), false);
assert.equal(PickerPolicy.isAllowedSize(-1), false);
assert.equal(PickerPolicy.extensionOf('file:///cache/Report.PDF'), '.PDF');
assert.equal(PickerPolicy.stagedName('uuid', '.pdf'), 'import-uuid.pdf');

const state = new ImeFocusState();
assert.equal(state.request(true).action, ImeFocusAction.Attach);
assert.equal(state.request(false).action, ImeFocusAction.Queue);
assert.equal(state.completeAttach(true), false);
assert.equal(state.isAttached, true);
assert.equal(state.request(true).action, ImeFocusAction.Reuse);
assert.equal(state.request(false).action, ImeFocusAction.Detach);
assert.equal(state.request(true).action, ImeFocusAction.Queue);
assert.equal(state.completeDetach(), true);
assert.equal(state.isAttached, false);
assert.equal(state.fail(), undefined);

assert.equal(ColorSchemePolicy.isDark(0), true);
assert.equal(ColorSchemePolicy.isDark(1), false);
assert.equal(ColorSchemePolicy.isDark(-1), false);
console.log('OHOS policy tests passed');
TS

bun "$TMP/test.ts"
