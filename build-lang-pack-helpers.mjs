#!/usr/bin/env node
// Helper for build-lang-pack.sh — JSON operations without a jq dependency.
// Subcommands:
//   validate-json <file>                       Exits non-zero if not valid JSON.
//   count-keys <dir>                           Prints count of unique dotted scalar paths across *.json.
//   entry <json-args-file>                     Reads JSON-encoded args, prints pretty entry JSON.
//   update-manifest <manifest> <code> <entry>  Patches manifest.json atomically.

import { readFileSync, readdirSync, writeFileSync, renameSync } from "node:fs";
import { join } from "node:path";

const [, , sub, ...args] = process.argv;

function die(msg, code = 1) {
  process.stderr.write(`helper error: ${msg}\n`);
  process.exit(code);
}

function collectPaths(value, prefix, out) {
  if (value === null || typeof value !== "object") {
    out.add(prefix);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((v, i) => collectPaths(v, prefix ? `${prefix}.${i}` : String(i), out));
    return;
  }
  for (const [k, v] of Object.entries(value)) {
    collectPaths(v, prefix ? `${prefix}.${k}` : k, out);
  }
}

try {
  switch (sub) {
    case "validate-json": {
      const [file] = args;
      if (!file) die("validate-json requires <file>");
      JSON.parse(readFileSync(file, "utf8"));
      break;
    }

    case "count-keys": {
      const [dir] = args;
      if (!dir) die("count-keys requires <dir>");
      const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
      const paths = new Set();
      for (const f of files) {
        const data = JSON.parse(readFileSync(join(dir, f), "utf8"));
        collectPaths(data, f.replace(/\.json$/, ""), paths);
      }
      process.stdout.write(String(paths.size));
      break;
    }

    case "entry": {
      const [argsFile] = args;
      if (!argsFile) die("entry requires <json-args-file>");
      const a = JSON.parse(readFileSync(argsFile, "utf8"));
      const entry = {
        code: a.code,
        native_name: a.native_name,
        english_name: a.english_name,
        rtl: a.rtl,
        version: a.version,
        completeness: a.completeness,
        size_bytes: a.size_bytes,
        sha256: a.sha256,
        url: a.url,
      };
      process.stdout.write(JSON.stringify(entry, null, 2));
      break;
    }

    case "update-manifest": {
      const [manifestPath, code, entryPath] = args;
      if (!manifestPath || !code || !entryPath) {
        die("update-manifest requires <manifest> <code> <entry-json-file>");
      }
      const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
      const entry = JSON.parse(readFileSync(entryPath, "utf8"));
      manifest.generated_at = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
      const packs = Array.isArray(manifest.packs) ? manifest.packs : [];
      const filtered = packs.filter((p) => p && p.code !== code);
      filtered.push(entry);
      manifest.packs = filtered.sort((a, b) => String(a.code).localeCompare(String(b.code)));
      const tmp = `${manifestPath}.tmp.${process.pid}`;
      writeFileSync(tmp, JSON.stringify(manifest, null, 2) + "\n");
      renameSync(tmp, manifestPath);
      break;
    }

    default:
      die(`unknown subcommand: ${sub}`);
  }
} catch (err) {
  die(err.message || String(err), 2);
}
