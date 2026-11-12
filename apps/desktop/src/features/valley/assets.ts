import manifestJson from '../../../public/valley/manifest.json';

/** Art produced by scripts/gen-valley-art.mjs; the renderer reads only this manifest. */
export interface ValleyManifestEntry {
  file: string;
  w: number;
  h: number;
  frames: number;
  frameMs: number[] | null;
  sha256: string;
}

const SPRITES = (manifestJson as { sprites: Record<string, ValleyManifestEntry> }).sprites;

/** Lookup by asset name (no extension). Unknown names render nothing rather than a broken image. */
export function manifestEntry(name: string): ValleyManifestEntry | undefined {
  return SPRITES[name];
}

export function valleyUrl(file: string): string {
  return `/valley/${file}`;
}
