#!/usr/bin/env node

// Regression suite: Codex importer schema, privacy and install-time behaviour.
//
// Covers the contract the metering pipeline depends on once records are read:
// the strict Spill event key set, the privacy boundary on checkpoint state, and
// the seeding path that keeps a first Stop hook run free of backlog.

import { stat } from "node:fs/promises";
import { readFile } from "node:fs/promises";
import {
  BREAKDOWN_KEYS,
  EVENT_KEYS,
  check,
  counters,
  equal,
  metaLine,
  usageLine,
  withWorkspace,
} from "./codex-importer-test-support.mjs";
import { runSuite } from "./codex-importer-test-support.mjs";

// 8. Events keep the strict schema, and state keeps the privacy contract.
async function testEventSchemaAndPrivacyContract() {
  await withWorkspace("schema", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession08", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);
    await workspace.importOnce();

    const events = await workspace.importedEvents();
    equal(events.length, 1, "one event is queued");
    const [event] = events;
    equal(JSON.stringify(Object.keys(event).sort()), JSON.stringify(EVENT_KEYS), "event uses the strict key set");
    equal(
      JSON.stringify(Object.keys(event.token_breakdown).sort()),
      JSON.stringify(BREAKDOWN_KEYS),
      "token_breakdown uses the strict key set",
    );
    equal(event.ai_tool, "codex", "event keeps the canonical codex tool label");
    equal(event.input_tokens, 100, "input tokens are the exact runtime value");
    equal(event.output_tokens, 10, "output tokens are the exact runtime value");
    equal(event.total_tokens, 110, "total tokens are the exact runtime value");
    check(/^span_[a-f0-9]{24}$/.test(event.span_id), "span id stays opaque");
    check(/^run_[a-f0-9]{24}$/.test(event.run_id), "run id stays opaque");

    const raw = await readFile(workspace.statePath, "utf8");
    check(!raw.includes(workspace.sessionPath()), "state stores no source path");
    check(!raw.includes(workspace.codexHome), "state stores no codex home path");
    check(!raw.includes("rollout-"), "state stores no session file name");
    check(!raw.includes("token_count"), "state stores no transcript content");
    for (const key of Object.keys((await workspace.state()).sessionFiles)) {
      check(/^[a-f0-9]{24}$/.test(key), "session files are keyed by an opaque hash");
    }
  });
}

// The budget bounds a hook run without dropping data, and --bootstrap lifts it.
// The budget bounds a hook run without dropping data, and the remainder resumes.
// The budget is floored at one maximal record, so it is exercised above that
// floor -- below it, a window could never contain a newline.
async function testBudgetDefersRatherThanSkips() {
  await withWorkspace("budget", async (workspace) => {
    const now = new Date();
    const filler = JSON.stringify({
      timestamp: now.toISOString(),
      type: "response_item",
      payload: { type: "message", content: "x".repeat(2000) },
    });
    const lines = [metaLine("incrementalSession09", now)];
    let usageRecords = 0;
    for (let index = 0; index < 1600; index += 1) {
      lines.push(filler);
      if (index % 80 === 0) {
        usageRecords += 1;
        lines.push(usageLine(new Date(now.getTime() + index), {
          input: 100 + index,
          output: 10,
          totalInput: 100 * usageRecords,
          totalOutput: 10 * usageRecords,
        }));
      }
    }
    await workspace.writeSession(lines);
    const totalSize = (await stat(workspace.sessionPath())).size;
    const budget = 1_200_000;
    check(totalSize > budget * 2, "fixture is large enough to need several budgeted runs");

    const budgeted = await workspace.importOnce(["--max-bytes", String(budget)]);
    check(budgeted.scanned_bytes <= budget, "run honours its byte budget");
    check(budgeted.scanned_bytes < totalSize, "budgeted run stops before the end of the file");
    equal(budgeted.deferred_files, 1, "remaining bytes are reported as deferred");

    let guard = 0;
    while ((await workspace.trackedFile()).offset < totalSize && guard < 50) {
      await workspace.importOnce(["--max-bytes", String(budget)]);
      guard += 1;
    }
    equal((await workspace.trackedFile()).offset, totalSize, "resumed runs reach the end of the file");
    equal((await workspace.importedEvents()).length, usageRecords, "every record is imported across runs");
  });
}

// A budget narrower than a single record must not stall the file forever.
async function testBudgetBelowOneRecordStillMakesProgress() {
  await withWorkspace("tinybudget", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession12", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);
    const totalSize = (await stat(workspace.sessionPath())).size;

    const tiny = await workspace.importOnce(["--max-bytes", "50"]);
    check(tiny.scanned_bytes > 0, "a budget below one record still consumes bytes");
    equal(tiny.imported_events, 1, "the record is imported despite the tiny budget");
    equal((await workspace.trackedFile()).offset, totalSize, "checkpoint reaches the end of the file");
  });
}

// Seeding marks existing files as read so the first hook run has no backlog.
async function testSeedOffsetsSkipsBootstrapWork() {
  await withWorkspace("seed", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession10", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);
    const size = (await stat(workspace.sessionPath())).size;

    const seeded = await workspace.importOnce(["--seed-offsets"]);
    equal(seeded.seeded_files, 1, "seeding records one file");
    equal(seeded.imported_events, 0, "seeding imports nothing");
    equal((await workspace.trackedFile()).offset, size, "seeding checkpoints the current size");

    const afterSeed = await workspace.importOnce();
    equal(afterSeed.scanned_bytes, 0, "the run after seeding has no backlog");

    const appended = `${usageLine(new Date(), { input: 140, output: 40, totalInput: 240, totalOutput: 50 })}\n`;
    await workspace.appendSession(appended);
    const live = await workspace.importOnce();
    equal(live.scanned_bytes, Buffer.byteLength(appended), "seeded file still reports later appends");
    equal(live.imported_events, 1, "records appended after seeding are imported");
  });
}

// Re-running setup must not seed over a checkpoint that still has pending data.
async function testSeedingLeavesTrackedFilesAlone() {
  await withWorkspace("reseed", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession11", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);
    await workspace.importOnce();
    const trackedOffset = (await workspace.trackedFile()).offset;

    const appended = `${usageLine(new Date(), { input: 150, output: 50, totalInput: 250, totalOutput: 60 })}\n`;
    await workspace.appendSession(appended);

    const reseed = await workspace.importOnce(["--seed-offsets"]);
    equal(reseed.seeded_files, 0, "re-seeding skips files that are already tracked");
    equal(
      (await workspace.trackedFile()).offset,
      trackedOffset,
      "re-seeding leaves an existing checkpoint untouched",
    );

    const recovered = await workspace.importOnce();
    equal(recovered.imported_events, 1, "records pending at re-seed time are still imported");
  });
}

const tests = [
  ["event schema and privacy contract hold", testEventSchemaAndPrivacyContract],
  ["byte budget defers instead of skipping", testBudgetDefersRatherThanSkips],
  ["budget below one record still progresses", testBudgetBelowOneRecordStillMakesProgress],
  ["seeding offsets avoids hook bootstrap", testSeedOffsetsSkipsBootstrapWork],
  ["re-seeding leaves tracked files alone", testSeedingLeavesTrackedFilesAlone],
];

await runSuite(tests);
