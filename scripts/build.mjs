#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, rmSync, statSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const ROOT_DIR = resolve('.');
const SRC_DIR = join(ROOT_DIR, 'src');
const DIST_DIR = join(ROOT_DIR, 'dist');

console.log('🌱 [Build] Starting build for AI Gardening Mentor Prototype...');
const startTime = Date.now();

try {
  if (!existsSync(SRC_DIR)) {
    throw new Error(`Source directory "${SRC_DIR}" does not exist.`);
  }

  // Clean previous dist directory
  if (existsSync(DIST_DIR)) {
    rmSync(DIST_DIR, { recursive: true, force: true });
  }
  mkdirSync(DIST_DIR, { recursive: true });

  // Copy all assets and source files from src to dist
  cpSync(SRC_DIR, DIST_DIR, { recursive: true });

  // Compute built files count and total size
  let fileCount = 0;
  let totalBytes = 0;

  function walk(dir) {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else {
        fileCount++;
        totalBytes += statSync(fullPath).size;
      }
    }
  }
  walk(DIST_DIR);

  const duration = Date.now() - startTime;
  const kbSize = (totalBytes / 1024).toFixed(1);
  console.log(`✅ [Build] Successfully compiled ${fileCount} files (${kbSize} KB) to "dist/" in ${duration}ms.`);
  process.exit(0);
} catch (error) {
  console.error('❌ [Build] Failed to build:', error.message);
  process.exit(1);
}
