import { describe, it, expect } from '@ohos/hypium';
import { PickerPolicy } from '../main/ets/common/PickerPolicy';

export default function pickerPolicyTest() {
  describe('PickerPolicyTest', () => {
    it('accepts sizes inside the import limit', 0, () => {
      expect(PickerPolicy.isAllowedSize(0)).assertTrue();
      expect(PickerPolicy.isAllowedSize(PickerPolicy.MAX_IMPORT_BYTES)).assertTrue();
      expect(PickerPolicy.isAllowedSize(PickerPolicy.MAX_IMPORT_BYTES + 1)).assertFalse();
      expect(PickerPolicy.isAllowedSize(-1)).assertFalse();
    });

    it('keeps a conservative extension only', 0, () => {
      expect(PickerPolicy.extensionOf('file:///cache/Report.PDF')).assertEqual('.PDF');
      expect(PickerPolicy.extensionOf('file:///cache/archive.tar.gz')).assertEqual('.gz');
      expect(PickerPolicy.extensionOf('file:///cache/no-extension')).assertEqual('');
      expect(PickerPolicy.extensionOf('file:///cache/a.b%20c')).assertEqual('.b');
      expect(PickerPolicy.extensionOf('file:///cache/.hidden')).assertEqual('');
    });

    it('builds a random staging name without the picked name', 0, () => {
      expect(PickerPolicy.stagedName('uuid-1234', '.pdf')).assertEqual('import-uuid-1234.pdf');
      expect(PickerPolicy.stagedName('uuid-1234', '')).assertEqual('import-uuid-1234');
    });
  });
}
