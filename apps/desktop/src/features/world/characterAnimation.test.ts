import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const css = readFileSync('src/features/world/world.module.css', 'utf8');

describe('world character animation', () => {
  it('animates live Person and job characters at idle speed', () => {
    expect(css).toContain(".entity[data-kind='character'] .entitySprite");
    expect(css).toMatch(
      /\.entity\[data-kind='character'\] \.entitySprite \{\s*animation: decor-frame 1\.8s steps\(2\) infinite;/,
    );
  });

  it('keeps working characters faster than idle ones', () => {
    expect(css).toMatch(
      /\.entity\[data-activity='working'\] \.entitySprite \{\s*animation: decor-frame 0\.9s steps\(2\) infinite;/,
    );
  });

  it('tints live character shadows with the durable Person accent', () => {
    expect(css).toContain('var(--person-accent');
  });

  it('disables character animation for reduced motion', () => {
    const reduced = css.slice(css.indexOf('@media (prefers-reduced-motion: reduce)'));
    expect(reduced).toContain(".entity[data-kind='character'] .entitySprite");
    expect(reduced).toContain('animation: none;');
  });
});
