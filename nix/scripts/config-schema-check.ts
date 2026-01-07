import fs from "node:fs";
import path from "node:path";
import { validateConfigObject } from "./src/config/validation.ts";

const samplePath = process.argv[2];
if (!samplePath) {
  console.error("usage: config-schema-check <sample-json>");
  process.exit(2);
}

const resolved = path.resolve(samplePath);
let raw: string;
try {
  raw = fs.readFileSync(resolved, "utf8");
} catch (err) {
  console.error(`failed to read sample config: ${resolved}`);
  console.error(err);
  process.exit(2);
}

let parsed: unknown;
try {
  parsed = JSON.parse(raw);
} catch (err) {
  console.error(`invalid JSON in sample config: ${resolved}`);
  console.error(err);
  process.exit(2);
}

const result = validateConfigObject(parsed);
if (result.ok) {
  console.log("config schema check: ok");
  process.exit(0);
}

console.error("config schema check failed:");
for (const issue of result.issues) {
  console.error(`- ${issue.path}: ${issue.message}`);
}
process.exit(1);
