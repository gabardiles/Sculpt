// Generates the favicon + app icons from brand tokens.
// A soft heart on a dusty-pink gradient. Run: node scripts/generate-icons.mjs
import sharp from "sharp";
import { mkdirSync } from "node:fs";

// Brand: --blush #E8C8C4, --blush-deep #C9938E, --bg #FBF7F6
const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#F0D6D2"/>
      <stop offset="55%" stop-color="#E8C8C4"/>
      <stop offset="100%" stop-color="#C9938E"/>
    </linearGradient>
    <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#9A6A65" flood-opacity="0.25"/>
    </filter>
  </defs>
  <rect width="512" height="512" rx="112" fill="url(#bg)"/>
  <path filter="url(#soft)" fill="#FBF7F6"
    d="M256 392
       C256 392 132 320 132 232
       C132 188 166 156 206 156
       C232 156 250 170 256 186
       C262 170 280 156 306 156
       C346 156 380 188 380 232
       C380 320 256 392 256 392 Z"/>
</svg>`;

mkdirSync("public/icons", { recursive: true });
const buf = Buffer.from(svg);

// PWA icons (referenced by manifest.ts)
await sharp(buf).resize(192, 192).png().toFile("public/icons/icon-192.png");
await sharp(buf).resize(512, 512).png().toFile("public/icons/icon-512.png");

// iOS home-screen / "Add to Home Screen"
await sharp(buf).resize(180, 180).png().toFile("public/apple-touch-icon.png");

// Browser tab favicon — Next.js App Router serves src/app/icon.png + apple-icon.png
await sharp(buf).resize(256, 256).png().toFile("src/app/icon.png");
await sharp(buf).resize(180, 180).png().toFile("src/app/apple-icon.png");

console.log("Wrote PWA icons, apple-touch-icon, and app/icon.png + apple-icon.png");
