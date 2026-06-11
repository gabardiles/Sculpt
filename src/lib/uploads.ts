/** Client-side mirror of the bucket limits (10 MB, images only). */
export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

export function validateImageFile(file: File): string | null {
  if (!file.type.startsWith("image/")) {
    return "That doesn't look like a photo.";
  }
  if (file.size > MAX_UPLOAD_BYTES) {
    return "That photo is over 10 MB — pick a smaller one.";
  }
  return null;
}
