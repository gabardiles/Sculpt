// Generates PWA icons from a brand-token SVG mark. Run: node scripts/generate-icons.mjs
import sharp from "sharp";
import { mkdirSync } from "node:fs";

const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512">
  <rect width="512" height="512" fill="#FBF7F6"/>
  <circle cx="256" cy="256" r="150" fill="#E8C8C4"/>
  <text x="256" y="312" text-anchor="middle"
        font-family="Helvetica, Arial, sans-serif" font-size="170"
        font-weight="300" letter-spacing="4" fill="#2B2422">S</text>
</svg>`;

mkdirSync("public/icons", { recursive: true });
const buf = Buffer.from(svg);

await sharp(buf).resize(192, 192).png().toFile("public/icons/icon-192.png");
await sharp(buf).resize(512, 512).png().toFile("public/icons/icon-512.png");
await sharp(buf).resize(180, 180).png().toFile("public/apple-touch-icon.png");

console.log("Icons written to public/icons + public/apple-touch-icon.png");
