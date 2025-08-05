#!/usr/bin/env ts-node
/**
 * boxify.ts – draws / refreshes boxed comment sections
 * Usage: node boxify.js .zig [.ts …] [--width 100]
 */
import * as fs from "fs";
import * as path from "path";
import { spawnSync } from "child_process";

/* ───────── CLI ───────── */
const exts: string[] = [];
let WIDTH = 100;
for (let i = 2; i < process.argv.length; ++i) {
  if (process.argv[i] === "--width") WIDTH = +process.argv[++i];
  else if (process.argv[i].startsWith(".")) exts.push(process.argv[i].toLowerCase());
}
if (!exts.length) {
  console.error("usage: boxify .zig [.ts …] [--width N]");
  process.exit(1);
}

/* ───────── drawing chars ───────── */
type Charset = { tl: string; tr: string; bl: string; br: string; fill: string };
const light: Charset = { tl: "┌", tr: "┐", bl: "└", br: "┘", fill: "─" };
const heavy: Charset = { tl: "╔", tr: "╗", bl: "╚", br: "╝", fill: "═" };

function buildTop(prefix: string, title: string, cs: Charset, width: number): string {
  const needed = prefix.length + 4 + title.length;
  if (width < needed) width = needed;
  const pad = width - prefix.length - 2 - title.length - 2;
  const left = Math.floor(pad / 2), right = pad - left;
  return prefix + cs.tl + cs.fill.repeat(left) + " " + title + " " +
         cs.fill.repeat(right) + cs.tr;
}
function buildBottom(prefix: string, cs: Charset, width: number): string {
  return prefix + cs.bl + cs.fill.repeat(width - prefix.length - 2) + cs.br;
}

/* ───────── utils ───────── */
function gitIgnored(p: string) {
  return spawnSync("git", ["check-ignore", "-q", p]).status === 0;
}
function walk(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e =>
    e.isDirectory() && e.name !== ".git"
      ? walk(path.join(dir, e.name))
      : path.join(dir, e.name));
}

/* markers */
const openRE  = /^\s*\/\/\s*\[box(!?)]\s+(.+?)\s*$/; // title mandatory
const closeRE = /^\s*\/\/\s*\[box(!?)]\s*$/;         // no title

/* ───────── main loop ───────── */
for (const file of walk(process.cwd())) {
  if (gitIgnored(file) || !exts.includes(path.extname(file).toLowerCase())) continue;

  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
  const out: string[] = [];
  let i = 0, changed = false;

  while (i < lines.length) {
    const open = openRE.exec(lines[i]);
    if (!open) {                      // normal line
      out.push(lines[i++]);
      continue;
    }

    /* opening marker found */
    const heavyFlag = open[1] === "!";
    const title     = open[2].trim();
    const cs        = heavyFlag ? heavy : light;
    const startLine = i;
    i++;                              // move past opening

    /* seek closing marker */
    let body: string[] = [];
    let foundClose = false;
    while (i < lines.length) {
      const close = closeRE.exec(lines[i]);
      if (close && (close[1] === open[1])) {          // must match style
        foundClose = true;
        i++;              // skip closing marker
        break;
      }
      body.push(lines[i++]);
    }
    if (!foundClose) {                // malformed → keep original text
      out.push(...lines.slice(startLine, i));
      console.warn(`boxify: no closing [box] for "${title}" in ${file}`);
      continue;
    }

    /* replace markers with borders */
    out.push(buildTop("// ", title, cs, WIDTH));
    out.push(...body);
    out.push(buildBottom("// ", cs, WIDTH));
    changed = true;
  }

  if (changed) {
    fs.writeFileSync(file, out.join("\n"), "utf8");
    console.log("boxed:", path.relative(process.cwd(), file));
  }
}
