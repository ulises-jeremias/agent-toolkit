// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { McpSecretStore, type SecretCipher } from './mcp-secrets';

function cipher(available = true): SecretCipher {
  return {
    isEncryptionAvailable: () => available,
    encryptString: (value) => Buffer.from(value.split('').reverse().join('')),
    decryptString: (value) => value.toString().split('').reverse().join(''),
  };
}

describe('McpSecretStore', () => {
  let dir = '';
  let file = '';

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-mcp-secrets-'));
    file = path.join(dir, 'mcp-secrets.json');
  });

  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  it('stores only ciphertext and exposes environment values to the backend on demand', () => {
    const store = new McpSecretStore(file, cipher(), () => 'gnome_libsecret');
    expect(store.set('MCP_API_TOKEN', 'do-not-write-me')).toEqual({ ok: true });
    const raw = fs.readFileSync(file, 'utf8');
    expect(raw).not.toContain('do-not-write-me');
    expect(store.status()).toMatchObject({ available: true, names: ['MCP_API_TOKEN'], error: null });
    expect(store.environment()).toEqual({ MCP_API_TOKEN: 'do-not-write-me' });
    expect(fs.statSync(file).mode & 0o777).toBe(0o600);
  });

  it('fails closed when the platform has no secure credential backend', () => {
    const store = new McpSecretStore(file, cipher(), () => 'basic_text');
    expect(store.status().available).toBe(false);
    expect(store.set('MCP_API_TOKEN', 'secret').ok).toBe(false);
    expect(fs.existsSync(file)).toBe(false);
    expect(store.environment()).toEqual({});
  });

  it('rejects invalid names and values before writing', () => {
    const store = new McpSecretStore(file, cipher(), () => 'gnome_libsecret');
    expect(store.set('not-an-env-name', 'secret').ok).toBe(false);
    expect(store.set('MCP_TOKEN', '').ok).toBe(false);
    expect(store.set('MCP_TOKEN', `x${'x'.repeat(8192)}`).ok).toBe(false);
    expect(fs.existsSync(file)).toBe(false);
  });

  it('removes a credential without returning its value', () => {
    const store = new McpSecretStore(file, cipher(), () => 'gnome_libsecret');
    store.set('MCP_API_TOKEN', 'secret');
    expect(store.remove('MCP_API_TOKEN')).toEqual({ ok: true });
    expect(store.status().names).toEqual([]);
    expect(store.environment()).toEqual({});
    expect(new McpSecretStore(file, cipher(), () => 'gnome_libsecret').managedNames()).toEqual(['MCP_API_TOKEN']);
  });
});
