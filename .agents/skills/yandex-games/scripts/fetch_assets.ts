/**
 * fetch_assets.ts
 * Helper script to download open-source / CC0 assets (e.g. Minecraft textures, items, audio)
 * directly into the project's public/assets directory.
 *
 * Usage:
 *   bun run scripts/fetch_assets.ts
 */

import fs from "node:fs";
import path from "node:path";

const BASE_BLOCK_URL = "https://raw.githubusercontent.com/InventivetalentDev/minecraft-assets/1.20.1/assets/minecraft/textures/block/";
const BASE_ITEM_URL = "https://raw.githubusercontent.com/InventivetalentDev/minecraft-assets/1.20.1/assets/minecraft/textures/item/";
const BASE_SOUND_URL = "https://raw.githubusercontent.com/InventivetalentDev/minecraft-assets/1.20.1/assets/minecraft/sounds/";

// Common default blocks
const blocks = [
  "dirt.png",
  "stone.png",
  "cobblestone.png",
  "oak_planks.png",
  "diamond_block.png",
  "diamond_ore.png",
  "gold_block.png",
  "gold_ore.png",
  "emerald_block.png",
  "emerald_ore.png",
  "tnt_side.png",
  "tnt_top.png",
  "bedrock.png",
  "obsidian.png",
  "bookshelf.png",
  "sand.png",
  "ice.png"
];

// Common items
const items = [
  "diamond_pickaxe.png",
  "diamond.png",
  "emerald.png",
  "gold_ingot.png",
  "apple.png",
  "golden_apple.png",
  "cookie.png",
  "totem_of_undying.png"
];

// Common audio effects
const sounds = [
  { name: "pop.ogg", url: BASE_SOUND_URL + "random/pop.ogg" },
  { name: "click.ogg", url: BASE_SOUND_URL + "random/click.ogg" },
  { name: "explode.ogg", url: BASE_SOUND_URL + "random/explode1.ogg" },
  { name: "levelup.ogg", url: BASE_SOUND_URL + "random/levelup.ogg" }
];

async function download(url: string, dest: string) {
  try {
    const res = await fetch(url);
    if (!res.ok) {
      console.warn(`[SKIP] Could not fetch ${url} (HTTP ${res.status})`);
      return false;
    }
    const arrayBuffer = await res.arrayBuffer();
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, Buffer.from(arrayBuffer));
    console.log(`Saved ${dest} (${arrayBuffer.byteLength} bytes)`);
    return true;
  } catch (err) {
    console.warn(`[ERROR] Downloading ${url}:`, err);
    return false;
  }
}

async function main() {
  console.log("Fetching block textures...");
  for (const block of blocks) {
    await download(`${BASE_BLOCK_URL}${block}`, path.join("public", "assets", "blocks", block));
  }

  console.log("Fetching item textures...");
  for (const item of items) {
    await download(`${BASE_ITEM_URL}${item}`, path.join("public", "assets", "items", item));
  }

  console.log("Fetching sound effects...");
  for (const sound of sounds) {
    await download(sound.url, path.join("public", "assets", "sounds", sound.name));
  }

  console.log("Asset fetching completed!");
}

main().catch(console.error);
