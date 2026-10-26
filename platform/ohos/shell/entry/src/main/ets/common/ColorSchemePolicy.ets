// OHOS ConfigurationConstant.ColorMode values used by the shell. Keeping the
// mapping here makes the light/dark decision testable without a UI context.
export class ColorSchemePolicy {
  static readonly NOT_SET: number = -1;
  static readonly DARK: number = 0;

  static isDark(mode: number): boolean {
    return mode === ColorSchemePolicy.DARK;
  }
}
