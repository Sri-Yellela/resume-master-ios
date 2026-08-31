#!/usr/bin/env node
/**
 * Rebuild the target's file references and Sources phase from what is ACTUALLY on disk.
 *
 * This exists because of a real defect: JobRepository.swift and LinkedInAuthService.swift were
 * committed to disk but never added to the target, so they never compiled. One of them was
 * referenced from ResumeBuilderView, which broke the build — and a file on disk that the target
 * does not know about is invisible in exactly the way that is hardest to spot in a diff.
 *
 * It also repairs `sourceTree = <group;`. The generator that produced this project lost the `>`
 * (PowerShell redirection ate it), and a bare `<group` is an OpenStep plist parse error: Xcode
 * cannot open the project at all.
 *
 *   node scripts/sync-xcode-project.mjs           # apply
 *   node scripts/sync-xcode-project.mjs --check   # CI: exit 1 if stale
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, relative, sep, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT    = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC_DIR = join(ROOT, "ResumeMaster", "ResumeMaster");
const PBX     = join(ROOT, "ResumeMaster", "ResumeMaster.xcodeproj", "project.pbxproj");
const CHECK   = process.argv.includes("--check");

const EOL = "\r\n";           // this file is CRLF throughout; keep it that way
const I2  = " ".repeat(8);    // object indent
const I4  = " ".repeat(16);   // list-item indent

// Deterministic ids, so a re-run of an unchanged tree produces no diff.
const oid = (s) => createHash("md5").update(s).digest("hex").slice(0, 24).toUpperCase();

const walk = (dir) => readdirSync(dir).flatMap((n) => {
  const full = join(dir, n);
  return statSync(full).isDirectory() ? walk(full) : [full];
});

const swift = walk(SRC_DIR)
  .filter((f) => f.endsWith(".swift"))
  .map((f) => relative(SRC_DIR, f).split(sep).join("/"))
  .sort();

const original = readFileSync(PBX, "utf8");
let lines = original.split(EOL);

// 1. Repair every eaten '>'.
lines = lines.map((l) => l.replaceAll("sourceTree = <group;", 'sourceTree = "<group>";'));

const isBuildFile = (l) => l.includes("isa = PBXBuildFile");
const isSwiftRef  = (l) => l.includes("isa = PBXFileReference") && l.includes("sourcecode.swift");

const buildFileAt = lines.findIndex(isBuildFile);
const swiftRefAt  = lines.findIndex(isSwiftRef);
if (buildFileAt < 0 || swiftRefAt < 0) throw new Error("pbxproj: could not locate the generated regions");

const meta = swift.map((path) => {
  const base = path.split("/").pop();
  return { path, base, ref: oid("ref:" + path), build: oid("build:" + path) };
});

const buildFileBlock = meta.map((m) =>
  `${I2}${m.build} /* ${m.base} in Sources */ = {isa = PBXBuildFile; fileRef = ${m.ref} /* ${m.base} */; };`);
const swiftRefBlock = meta.map((m) =>
  `${I2}${m.ref} /* ${m.base} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${m.path}"; sourceTree = "<group>"; };`);

// 2. Swap the two contiguous generated regions in place, longest-lived indices last.
const spliceRun = (arr, startIdx, pred, replacement) => {
  let end = startIdx;
  while (end < arr.length && pred(arr[end])) end++;
  arr.splice(startIdx, end - startIdx, ...replacement);
};
// Splice the later region first so the earlier index stays valid.
if (swiftRefAt > buildFileAt) {
  spliceRun(lines, swiftRefAt, isSwiftRef, swiftRefBlock);
  spliceRun(lines, buildFileAt, isBuildFile, buildFileBlock);
} else {
  spliceRun(lines, buildFileAt, isBuildFile, buildFileBlock);
  spliceRun(lines, swiftRefAt, isSwiftRef, swiftRefBlock);
}

// 3. Rewrite a parenthesised list that begins on `openLine` and ends at the line holding `);`.
const rewriteList = (openPred, body) => {
  const open = lines.findIndex(openPred);
  if (open < 0) throw new Error("pbxproj: list not found");
  let close = open + 1;
  while (close < lines.length && !lines[close].trimStart().startsWith(");")) close++;
  lines.splice(open + 1, close - (open + 1), ...body);
};

rewriteList(
  (l) => l.includes("/* Sources */") && l.includes("PBXSourcesBuildPhase"),
  meta.map((m) => `${I4}${m.build} /* ${m.base} in Sources */,`));

// The group's children must name every reference, or the Xcode navigator shows an empty folder.
rewriteList(
  (l) => l.includes("/* ResumeMaster */") && l.includes("isa = PBXGroup"),
  [`${I4}64488557C2EBEE21EA19BF06 /* Info.plist */,`,
   ...meta.map((m) => `${I4}${m.ref} /* ${m.base} */,`)]);

const out = lines.join(EOL);

if (CHECK) {
  if (out !== original) {
    console.error("project.pbxproj is stale — run: node scripts/sync-xcode-project.mjs");
    process.exit(1);
  }
  console.log(`project.pbxproj is current (${swift.length} Swift files).`);
} else {
  writeFileSync(PBX, out);
  console.log(`Synced ${swift.length} Swift files into the ResumeMaster target.`);
}
