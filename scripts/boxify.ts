#!/usr/bin/env ts-node
/* boxify.ts  – Auto-formats heading boxes (light/heavy) */
import * as fs from "fs";
import * as path from "path";
import { spawnSync } from "child_process";

/* ---------------- CLI ---------------- */
const exts: string[] = [];
let WIDTH = 100;

for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a === "--width") WIDTH = +process.argv[++i];
  else if (a.startsWith(".")) exts.push(a.toLowerCase());
}
if (!exts.length) {
  console.error("usage: boxify .zig [.ts …] [--width N]");
  process.exit(1);
}

/* -------------- char sets ------------ */
type Charset = { topLeft: string; topRight: string; bottomLeft: string;
                 bottomRight: string; fill: string };
const light: Charset = { topLeft: "┌", topRight: "┐",
                          bottomLeft: "└", bottomRight: "┘", fill: "─" };
const heavy: Charset = { topLeft: "╔", topRight: "╗",
                          bottomLeft: "╚", bottomRight: "╝", fill: "═" };

/* -------- helpers -------- */
const boxTopRE = /^\s*\/\/\s*(┌|╔).*?(┐|╗)\s*$/;
const markerRE = /^\s*\/\/\s*\[box!?]\s+(.+?)\s*$/;

function gitIgnored(p: string) {
  return spawnSync("git", ["check-ignore", "-q", p]).status === 0;
}
function walk(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true })
    .flatMap(e => e.isDirectory() && e.name !== ".git"
        ? walk(path.join(dir, e.name))
        : path.join(dir, e.name));
}
function centre(prefix: string, title: string, cs: Charset, w: number) {
  const fill = cs.fill;
  const need = prefix.length + 4 + title.length;
  if (w < need) w = need;
  const pad = w - prefix.length - 2 - title.length - 2;
  const left = Math.floor(pad / 2), right = pad - left;
  return prefix + cs.topLeft + fill.repeat(left) + " " + title + " " +
         fill.repeat(right) + cs.topRight;
}
function bottom(prefix: string, cs: Charset, w: number) {
  return prefix + cs.bottomLeft + cs.fill.repeat(w - prefix.length - 2) +
         cs.bottomRight;
}

/* -------- main loop ------- */
for (const file of walk(process.cwd())) {
  if (gitIgnored(file) ||
      !exts.includes(path.extname(file).toLowerCase())) continue;

  const src = fs.readFileSync(file, "utf8").split(/\r?\n/);
  const out: string[] = [];
  let changed = false;

  for (let i = 0; i < src.length; i++) {
    const ln = src[i];
    let m;

    /* new box marker */
    if ((m = markerRE.exec(ln))) {
      const raw = m[1].trim();
      const heavyStyle = ln.includes("[box!]");           // detect '!'
      const title = heavyStyle ? raw : raw;
      const cs = heavyStyle ? heavy : light;
      out.push(centre("// ", title, cs, WIDTH));
      out.push(bottom("// ", cs, WIDTH));
      changed = true;
      continue;
    }

    /* re-format existing top */
    if ((m = boxTopRE.exec(ln))) {
      const cs = m[1] === "┌" ? light : heavy;
      const title = ln.replace(/^\s*\/\/\s*[┌╔]/, "")
                      .replace(/[┐╗]\s*$/, "")
                      .replace(new RegExp(cs.fill, "g"), "")
                      .trim();
      out.push(centre("// ", title, cs, WIDTH));

      /* sync bottom if present */
      let j = i + 1;
      while (j < src.length && /^\s*$/.test(src[j])) j++;
      if (j < src.length &&
          /^\s*\/\/\s*[└╚]/.test(src[j])) {
        src[j] = bottom("// ", cs, WIDTH);
        changed = true;
      }
      continue;
    }

    out.push(ln);
  }

  if (changed) {
    fs.writeFileSync(file, out.join("\n"), "utf8");
    console.log("boxed:", path.relative(process.cwd(), file));
  }
}
