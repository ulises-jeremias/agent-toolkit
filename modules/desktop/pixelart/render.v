module pixelart

// VC2 sprite rendering pipeline (#1172 VC2): authored grid → RGBA expansion →
// raw-pixel gg Image (nearest-neighbor) → bounded cache → draw.
//
// Zero per-frame image creation, zero per-frame RGBA expansion. Images are
// created once per (sprite, palette, scale) key via the supported gg raw-pixel
// path (Image.init_sokol_image + Context.cache_image); the gg context owns the
// GPU resources and explicit cleanup goes through
// Context.remove_cached_image_by_idx. No custom PNG encoder, no GL bypass.

import gg
import sokol.gfx

// max_gpu_images bounds the number of live sprite images. Every gg.Image owns
// a sokol sampler and sokol's default sampler pool is 64, shared with the
// font atlases — exhausting it makes text glyphs silently disappear
// (SAMPLER_POOL_EXHAUSTED). VC5 grew the manifest past that budget, so the
// cache evicts the least-recently-drawn image once the bound is reached.
pub const max_gpu_images = 40

// SpriteCache holds GPU images keyed by "sprite_name:palette_id:scale",
// bounded by max_gpu_images with least-recently-used eviction.
pub struct SpriteCache {
mut:
	ctx       &gg.Context = unsafe { nil }
	images    map[string]gg.Image
	indices   map[string]int
	pixels    map[string][]u8 // keeps RGBA buffers alive behind Image.data
	last_used map[string]u64 // monotonic tick of the last image_for() hit
	tick      u64
	palettes  map[PaletteId]Palette
}

// lru_victim returns the key with the smallest tick ('' when empty).
fn lru_victim(last_used map[string]u64) string {
	mut victim := ''
	mut oldest := u64(0)
	mut first := true
	for k, t in last_used {
		if first || t < oldest {
			victim = k
			oldest = t
			first = false
		}
	}
	return victim
}

// evict releases one cache entry (GPU image + sampler + RGBA buffer).
fn (mut sc SpriteCache) evict(ck string) {
	if idx := sc.indices[ck] {
		sc.ctx.remove_cached_image_by_idx(idx)
	}
	sc.images.delete(ck)
	sc.indices.delete(ck)
	sc.pixels.delete(ck)
	sc.last_used.delete(ck)
}

// live_images reports how many GPU images the cache currently holds.
pub fn (sc &SpriteCache) live_images() int {
	return sc.images.len
}

// cache_key builds a string cache key from the sprite identity.
fn cache_key(s Sprite, pid PaletteId, scale int) string {
	return '${s.name}:${pid}:${scale}'
}

pub fn new_sprite_cache(ctx &gg.Context) &SpriteCache {
	return &SpriteCache{
		ctx: ctx
		palettes: {
			PaletteId.paper: paper_palette()
			PaletteId.ink:   ink_palette()
		}
	}
}

// image_for returns the cached (or newly created) nearest-neighbor gg Image
// for the sprite at the given integer scale in the given palette.
// Pipeline: grid → RGBA expansion → raw-pixel gg Image → cached.
pub fn (mut sc SpriteCache) image_for(s Sprite, pid PaletteId, scale int) gg.Image {
	ck := cache_key(s, pid, scale)
	sc.tick++
	sc.last_used[ck] = sc.tick
	if img := sc.images[ck] {
		// Images cached before sokol was ready have no GPU handle yet;
		// gg also retries these at startup, this just re-syncs our snapshot.
		if !img.simg_ok && gfx.is_valid() {
			mut live := sc.ctx.get_cached_image_by_idx(sc.indices[ck])
			live.init_sokol_image()
			sc.images[ck] = *live
			return *live
		}
		return img
	}
	// bound the pool before creating a new image: drop the least-recently
	// drawn entry (never the one being created — it was just touched)
	for sc.images.len >= max_gpu_images {
		mut oldest := lru_victim(sc.last_used)
		if oldest == ck || oldest == '' {
			// the fresh key is not in images yet; pick the oldest real image
			mut lu := sc.last_used.clone()
			lu.delete(ck)
			oldest = lru_victim(lu)
		}
		if oldest == '' {
			break
		}
		sc.evict(oldest)
	}
	pal := sc.palette(pid)
	w := s.width() * scale
	h := s.height() * scale
	// Store first so the backing array stays alive behind Image.data.
	sc.pixels[ck] = s.expand(pal, scale)
	buf := sc.pixels[ck]
	mut img := gg.Image{
		width: w
		height: h
		nr_channels: 4
		ok: true
		data: unsafe { buf.data }
		texture_filter: .nearest
	}
	if gfx.is_valid() {
		img.init_sokol_image()
	}
	idx := sc.ctx.cache_image(img)
	// The authoritative cached copy carries the gg-assigned id that
	// draw_image uses for lookup; keep our snapshot in sync with it.
	live := sc.ctx.get_cached_image_by_idx(idx)
	sc.images[ck] = *live
	sc.indices[ck] = idx
	return *live
}

// palette returns the palette for the given id.
pub fn (sc &SpriteCache) palette(pid PaletteId) Palette {
	return sc.palettes[pid] or { paper_palette() }
}

// draw renders a sprite at (x, y) window coords with the cached image at
// the given integer scale. Zero per-frame asset creation.
pub fn (mut sc SpriteCache) draw(s Sprite, pid PaletteId, x int, y int, scale int) {
	img := sc.image_for(s, pid, scale)
	w := f32(s.width() * scale)
	h := f32(s.height() * scale)
	sc.ctx.draw_image(f32(x), f32(y), w, h, img)
}

// draw_env draws an environment asset.
pub fn (mut sc SpriteCache) draw_env(a EnvironmentAsset, pid PaletteId, x int, y int, scale int) {
	sc.draw(environment_for(a), pid, x, y, scale)
}

// draw_agent draws an agent avatar for the given visual state.
pub fn (mut sc SpriteCache) draw_agent(state AgentVisualState, pid PaletteId, x int, y int, scale int) {
	sc.draw(agent_for_state(state), pid, x, y, scale)
}

// clear_cache releases cached images (call on shutdown; theme switches keep
// both palettes cached since the key space is bounded).
pub fn (mut sc SpriteCache) clear_cache() {
	for _, idx in sc.indices {
		sc.ctx.remove_cached_image_by_idx(idx)
	}
	sc.images = {}
	sc.indices = {}
	sc.pixels = {}
	sc.last_used = {}
}
