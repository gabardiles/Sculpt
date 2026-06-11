/**
 * Editorial imagery — borrowed placeholders, hotlinked for now.
 * ⚠ Replace with owned/licensed photography before any public launch.
 * Swap a URL here and it changes everywhere.
 */

export const DAY_IMAGES: Record<number, string> = {
  1: "https://i.pinimg.com/736x/7c/c0/4b/7cc04b50df885c43912674adeade8dda.jpg",
  2: "https://i.pinimg.com/736x/2e/76/26/2e7626ad34c738659c53477b0a92108f.jpg",
  3: "https://i.pinimg.com/736x/f4/c9/76/f4c976234ae0d3f082bdb69e6d7cc2ff.jpg",
  4: "https://i.pinimg.com/736x/a0/e4/8b/a0e48b4d2262b4945ac582f13c15700f.jpg",
  5: "https://i.pinimg.com/736x/a8/94/a0/a894a05fde1c24e028b747c3210374ba.jpg",
};

export const HERO_IMAGE =
  "https://i.pinimg.com/1200x/c6/43/91/c643919ad2af2f53350fbf6374cce76e.jpg";

export function dayImage(index: number): string {
  return DAY_IMAGES[index] ?? HERO_IMAGE;
}
