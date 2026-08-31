#!/usr/bin/env node
/**
 * Assert the vendored copy of the mobile API contract matches its recorded checksums.
 *
 * Per contract/README.md in the server repo: hash over LF-NORMALISED content. That repo has
 * core.autocrlf=true and no .gitattributes, so a checkout can legitimately carry CRLF, and hashing
 * raw bytes would fail on content that is byte-for-byte correct — a test that fails for the wrong
 * reason is a test that gets deleted.
 *
 * This answers "is my copy current?" It cannot answer "has the server changed since I copied?" —
 * nothing inside this repo can. That half is test/mobileApiContract.test.js in the server repo.
 */
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "Contract");
const sums = JSON.parse(readFileSync(join(DIR, "CHECKSUMS.json"), "utf8"));

let failed = 0;
for (const [name, expected] of Object.entries(sums.files)) {
  const normalised = readFileSync(join(DIR, name), "utf8").replaceAll("\r\n", "\n");
  const actual = createHash("sha256").update(Buffer.from(normalised, "utf8")).digest("hex");
  const ok = actual === expected;
  if (!ok) failed++;
  console.log(`${ok ? "OK  " : "FAIL"}  ${name}`);
  if (!ok) console.log(`      expected ${expected}\n      actual   ${actual}`);
}

console.log(`\ncontract version ${sums.contractVersion} — ${failed === 0
  ? "vendored copy is current."
  : `${failed} file(s) stale; re-copy from the server repo's contract/ directory.`}`);
process.exit(failed === 0 ? 0 : 1);
