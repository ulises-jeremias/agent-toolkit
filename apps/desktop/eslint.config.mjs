import globals from 'globals';
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import prettier from 'eslint-plugin-prettier';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import { importX } from 'eslint-plugin-import-x';

export default [
  {
    ignores: [
      'node_modules/',
      'coverage/',
      'dist/',
      'build/',
      'dev-dist/',
      'public/',
      '__mocks__/',
      'src/theme/',
      'tools/',
      '**/*.d.ts',
      '**/*.gen.ts',
      'dist-electron/',
      'release/',
      'test-results/',
      'playwright-report/',
      '.prettierrc.js',
      'postcss.config.js',
      'electron/',
    ],
  },
  {
    files: ['**/*.{ts,tsx}'],
    ignores: ['vite.config.ts', 'vitest.config.ts', 'playwright.config.ts', 'electron/**/*'],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'module',
      parserOptions: {
        project: './tsconfig.json',
        tsconfigRootDir: import.meta.dirname,
      },
      globals: {
        ...globals.browser,
        ...globals.commonjs,
        ...globals.node,
        ...globals.es2020,
      },
    },
    plugins: {
      'react-hooks': reactHooks,
    },
  },
  {
    files: ['vite.config.ts', 'vitest.config.ts', 'playwright.config.ts', 'e2e/**/*.ts'],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'module',
      parserOptions: {
        project: './tsconfig.json',
        tsconfigRootDir: import.meta.dirname,
      },
      globals: {
        ...globals.node,
        ...globals.es2020,
      },
    },
  },
  {
    files: ['**/*.{js,mjs,cjs}'],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'module',
      globals: {
        ...globals.node,
        ...globals.es2020,
      },
    },
  },
  js.configs.recommended,
  // Template-faithful: base recommended set (no type-aware rules).
  // Strict type safety is enforced by `pnpm type-check` (tsc, both projects).
  ...tseslint.configs.recommended,
  {
    // eslint-plugin-import-x's TypeScript resolver does not support
    // TypeScript 6 yet ("invalid interface loaded as resolver"); use the
    // node resolver. All app imports are relative, so nothing is lost.
    // Revisit when import-x supports TS6.
    files: ['**/*.{ts,tsx}'],
    settings: {
      'import-x/resolver': { node: true },
    },
  },
  react.configs.flat.recommended,
  react.configs.flat['jsx-runtime'],
  jsxA11y.flatConfigs.recommended,
  importX.flatConfigs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    plugins: {
      prettier,
      'react-hooks': reactHooks,
    },
    rules: {
      'prettier/prettier': 'error',
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'error',
      'import-x/no-unresolved': 'off',
    },
    settings: {
      react: {
        version: 'detect',
      },
    },
  },
];
