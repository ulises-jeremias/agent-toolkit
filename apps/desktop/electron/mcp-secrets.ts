import fs from 'node:fs';
import path from 'node:path';
import { writeFileAtomic } from './harness-store';

export const MCP_SECRET_STORE_FILE = 'mcp-secrets.json';
const ENV_NAME = /^[A-Z_][A-Z0-9_]{0,127}$/;
const MAX_SECRET_LENGTH = 8_192;

export interface SecretCipher {
  isEncryptionAvailable(): boolean;
  encryptString(value: string): Buffer;
  decryptString(value: Buffer): string;
}

export interface McpSecretStatus {
  available: boolean;
  storage: string;
  names: string[];
  error: string | null;
}

interface EncryptedSecretStore {
  version: 1;
  values: Record<string, string>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function validName(name: unknown): name is string {
  return typeof name === 'string' && ENV_NAME.test(name);
}

function readStore(file: string): EncryptedSecretStore {
  try {
    const parsed: unknown = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (!isRecord(parsed) || parsed.version !== 1 || !isRecord(parsed.values)) {
      return { version: 1, values: {} };
    }
    const values: Record<string, string> = {};
    for (const [name, encoded] of Object.entries(parsed.values)) {
      if (validName(name) && typeof encoded === 'string' && /^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) {
        values[name] = encoded;
      }
    }
    return { version: 1, values };
  } catch {
    return { version: 1, values: {} };
  }
}

/** Credentials are encrypted by Electron's OS-backed safeStorage before disk writes. */
export class McpSecretStore {
  constructor(
    private readonly file: string,
    private readonly cipher: SecretCipher,
    private readonly secureBackend: () => string,
  ) {}

  status(): McpSecretStatus {
    const storage = this.secureBackend();
    const available = this.cipher.isEncryptionAvailable() && storage !== 'basic_text' && storage !== 'unknown';
    return {
      available,
      storage: displayStorage(storage),
      names: Object.keys(readStore(this.file).values).sort(),
      error: available ? null : 'A secure operating-system credential store is unavailable. No value was saved.',
    };
  }

  set(name: unknown, value: unknown): { ok: true } | { ok: false; message: string } {
    if (!validName(name)) return { ok: false, message: 'Use a valid environment variable name.' };
    if (typeof value !== 'string' || value.length === 0 || value.length > MAX_SECRET_LENGTH || value.includes('\0')) {
      return { ok: false, message: 'Enter a non-empty value up to 8,192 characters.' };
    }
    if (!this.status().available) {
      return { ok: false, message: 'A secure operating-system credential store is unavailable. No value was saved.' };
    }
    try {
      const store = readStore(this.file);
      store.values[name] = this.cipher.encryptString(value).toString('base64');
      writeFileAtomic(this.file, `${JSON.stringify(store, null, 2)}\n`);
      return { ok: true };
    } catch {
      return { ok: false, message: 'Could not encrypt or persist this credential. No plaintext value was written.' };
    }
  }

  remove(name: unknown): { ok: true } | { ok: false; message: string } {
    if (!validName(name)) return { ok: false, message: 'Invalid environment variable name.' };
    const store = readStore(this.file);
    if (!(name in store.values)) return { ok: true };
    delete store.values[name];
    try {
      writeFileAtomic(this.file, `${JSON.stringify(store, null, 2)}\n`);
      return { ok: true };
    } catch {
      return { ok: false, message: 'Could not update the encrypted credential store.' };
    }
  }

  environment(): Record<string, string> {
    if (!this.status().available) return {};
    const result: Record<string, string> = {};
    for (const [name, encoded] of Object.entries(readStore(this.file).values)) {
      try {
        result[name] = this.cipher.decryptString(Buffer.from(encoded, 'base64'));
      } catch {
        // A credential that cannot be decrypted is omitted; it is never logged.
      }
    }
    return result;
  }
}

function displayStorage(backend: string): string {
  if (backend === 'gnome_libsecret') return 'GNOME Keyring';
  if (backend.startsWith('kwallet')) return 'KWallet';
  if (backend === 'basic_text') return 'No secure keyring';
  if (backend === 'unknown') return 'Checking system keyring';
  return backend === 'macOS Keychain' || backend === 'Windows Credential Store' ? backend : 'System credential store';
}

export function electronStorageName(platform: string, linuxBackend: string): string {
  if (platform === 'darwin') return 'macOS Keychain';
  if (platform === 'win32') return 'Windows Credential Store';
  return linuxBackend;
}

export function mcpSecretStorePath(userData: string): string {
  return path.join(userData, MCP_SECRET_STORE_FILE);
}
