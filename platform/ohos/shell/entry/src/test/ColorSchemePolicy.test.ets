import { describe, it, expect } from '@ohos/hypium';
import { ColorSchemePolicy } from '../main/ets/common/ColorSchemePolicy';

export default function colorSchemePolicyTest() {
  describe('ColorSchemePolicyTest', () => {
    it('maps only the dark configuration value to dark', 0, () => {
      expect(ColorSchemePolicy.isDark(ColorSchemePolicy.DARK)).assertTrue();
      expect(ColorSchemePolicy.isDark(1)).assertFalse();
      expect(ColorSchemePolicy.isDark(ColorSchemePolicy.NOT_SET)).assertFalse();
      expect(ColorSchemePolicy.isDark(7)).assertFalse();
    });
  });
}
