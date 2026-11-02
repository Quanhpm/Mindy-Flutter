#!/usr/bin/env node
// Đồng bộ chữ RN (src/modules/*/messages.ts) vào assets/i18n/{vi,en}.json dưới key `mdy.<namespace>`.
//   node --experimental-strip-types tool/rn_i18n_sync.mjs ../MindyMobile_Admin
// RN `useTranslation('teaching'); t('myClasses')`  ->  Flutter `t('mdy.teaching.myClasses')`.
// RN `t('attendance:session.historyTab')`          ->  Flutter `t('mdy.attendance.session.historyTab')`.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const rn = path.resolve(process.argv[2] ?? path.join(root, '../MindyMobile_Admin'));
const modules = path.join(rn, 'src/modules');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'rn-i18n-'));
globalThis.require = createRequire(import.meta.url);
const out = { vi: {}, en: {} };
globalThis.__i18n = {
  addResourceBundle(lng, ns, data) {
    out[lng][ns] = { ...(out[lng][ns] ?? {}), ...data };
  },
};

for (const name of fs.readdirSync(modules)) {
  const file = path.join(modules, name, 'messages.ts');
  if (!fs.existsSync(file)) continue;
  const dir = path.join(modules, name);
  const source = fs
    .readFileSync(file, 'utf8')
    .replace(/^import i18n from '@\/translations';$/m, 'const i18n = (globalThis as any).__i18n;')
    .replace(
      /^import (\w+) from '\.\/([\w.-]+\.json)';$/gm,
      (_, id, json) => `const ${id} = JSON.parse(globalThis.require('fs').readFileSync(${JSON.stringify(path.join(dir, json))}, 'utf8'));`
    )
    .replace(/^import .*$/gm, '');
  const target = path.join(tmp, `${name}.mts`);
  fs.writeFileSync(target, source);
  await import(pathToFileURL(target).href);
}

// RN dùng key phẳng có dấu chấm ('home.noneTitle'); i18next tự tra được (ignoreJSONStructure),
// Translator Flutter tra theo cây nên tách thành object lồng. Trùng key thì dừng để sửa tay.
function unflatten(value, prefix = '') {
  if (typeof value !== 'object' || value === null) return value;
  const out = {};
  for (const [key, child] of Object.entries(value)) {
    const parts = key.split('.');
    let cursor = out;
    for (const part of parts.slice(0, -1)) {
      if (typeof cursor[part] === 'string') throw new Error(`i18n conflict: ${prefix}${key}`);
      cursor = cursor[part] ??= {};
    }
    const last = parts.at(-1);
    if (last in cursor) throw new Error(`i18n conflict: ${prefix}${key}`);
    cursor[last] = unflatten(child, `${prefix}${key}.`);
  }
  return out;
}

for (const lang of ['vi', 'en']) {
  out[lang] = unflatten(out[lang]);
  const file = path.join(root, `assets/i18n/${lang}.json`);
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  data.mdy = out[lang];
  fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
  console.log(lang, Object.keys(out[lang]).join(', '));
}
