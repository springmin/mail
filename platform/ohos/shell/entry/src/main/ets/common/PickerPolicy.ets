// Pure picker policy used by the ArkTS shell; kept free of UI/file APIs so it
// can be covered by local unit tests on the host.
export class PickerPolicy {
  static readonly MAX_IMPORT_BYTES: number = 50 * 1024 * 1024;

  static isAllowedSize(size: number): boolean {
    return size >= 0 && size <= PickerPolicy.MAX_IMPORT_BYTES;
  }

  // Keep only a short, conservative extension. The picked file name itself is
  // never used as the staged cache name.
  static extensionOf(uri: string): string {
    const raw = uri.split('/').pop() ?? '';
    const dot = raw.lastIndexOf('.');
    if (dot <= 0) {
      return '';
    }
    return raw.substring(dot).replace(/[^A-Za-z0-9.]/g, '').substring(0, 12);
  }

  static stagedName(uuid: string, extension: string): string {
    return `import-${uuid}${extension}`;
  }
}
