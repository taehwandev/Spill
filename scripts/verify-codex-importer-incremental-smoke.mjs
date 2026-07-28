#!/usr/bin/env node

// Regression suite: Codex importer incremental byte-offset reading.
//
// Guards the behaviour a Stop hook depends on: a run must parse only the bytes
// appended since its last checkpoint, must never advance a checkpoint past an
// incomplete or unqueued record, and must restart a file that was truncated.

import { chmod, readFile, stat, writeFile } from "node:fs/promises";
import {
  check,
  equal,
  metaLine,
  runSuite,
  usageLine,
  withWorkspace,
} from "./codex-importer-test-support.mjs";

// 1. A second run over an unchanged file reads nothing, and after an append it
//    reads exactly the appended bytes.
async function testSecondRunReadsOnlyAppendedBytes() {
  await withWorkspace("append", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession01", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);

    const first = await workspace.importOnce();
    equal(first.imported_events, 1, "first run imports the initial record");
    const firstSize = (await stat(workspace.sessionPath())).size;
    equal((await workspace.trackedFile()).offset, firstSize, "checkpoint reaches end of file");

    const unchanged = await workspace.importOnce();
    equal(unchanged.scanned_bytes, 0, "unchanged file is not re-read");
    equal(unchanged.imported_events, 0, "unchanged file imports nothing");

    const appended = `${usageLine(new Date(), { input: 120, output: 20, totalInput: 220, totalOutput: 30 })}\n`;
    await workspace.appendSession(appended);

    const second = await workspace.importOnce();
    equal(second.scanned_bytes, Buffer.byteLength(appended), "second run reads only appended bytes");
    equal(second.imported_events, 1, "second run imports only the appended record");
    check(
      second.scanned_bytes < firstSize,
      "appended read is smaller than a whole-file read",
    );
  });
}

// 2/3. A trailing record without a newline stays outside the checkpoint until
//      the newline arrives.
async function testIncompleteTrailingRecord() {
  await withWorkspace("partial", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession02", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);
    await workspace.importOnce();
    const completeOffset = (await workspace.trackedFile()).offset;

    const partial = usageLine(new Date(), { input: 130, output: 30, totalInput: 230, totalOutput: 40 });
    await workspace.appendSession(partial);

    const withPartial = await workspace.importOnce();
    equal(withPartial.imported_events, 0, "incomplete trailing record is not imported");
    equal(
      (await workspace.trackedFile()).offset,
      completeOffset,
      "checkpoint does not cover an incomplete record",
    );

    await workspace.appendSession("\n");
    const completed = await workspace.importOnce();
    equal(completed.imported_events, 1, "record is imported once its newline arrives");
    equal(
      (await workspace.trackedFile()).offset,
      (await stat(workspace.sessionPath())).size,
      "checkpoint advances after the record completes",
    );
  });
}

// 4. A file shorter than its checkpoint is re-read from the start.
async function testTruncatedFileRestarts() {
  await withWorkspace("truncate", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession03", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
      usageLine(now, { input: 110, output: 15, totalInput: 210, totalOutput: 25 }),
    ]);
    await workspace.importOnce();
    const grownOffset = (await workspace.trackedFile()).offset;
    check(grownOffset > 0, "checkpoint recorded before truncation");

    const replacement = [
      metaLine("incrementalSession04", new Date()),
      usageLine(new Date(), { input: 7, output: 3, totalInput: 7, totalOutput: 3 }),
    ];
    await writeFile(workspace.sessionPath(), `${replacement.join("\n")}\n`, "utf8");
    const rotatedSize = (await stat(workspace.sessionPath())).size;
    check(rotatedSize < grownOffset, "rotated file is shorter than the stored checkpoint");

    const rerun = await workspace.importOnce();
    equal(rerun.scanned_bytes, rotatedSize, "truncated file is re-read from the start");
    equal(rerun.imported_events, 1, "records after truncation are imported");
    equal((await workspace.trackedFile()).offset, rotatedSize, "checkpoint resets to the new size");
  });
}

// 5. Schema 1 state (no per-file checkpoints) loads and upgrades in place.
async function testLegacyStateMigrates() {
  await withWorkspace("migrate", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession05", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);
    await writeFile(workspace.statePath, `${JSON.stringify({
      updatedAt: "2026-01-01T00:00:00.000Z",
      sentSpanIDs: ["span_legacyplaceholder00000"],
      sessionCursors: { deadbeefdeadbeefdeadbeef: { totalTokens: 5 } },
    }, null, 2)}\n`, "utf8");

    const summary = await workspace.importOnce();
    equal(summary.state_schema_version, 2, "summary reports the upgraded schema version");
    equal(summary.imported_events, 1, "legacy state still imports new records");

    const state = await workspace.state();
    check(Array.isArray(state.sentSpanIDs), "legacy sentSpanIDs survive the upgrade");
    check(
      state.sentSpanIDs.includes("span_legacyplaceholder00000"),
      "previously sent span ids are preserved",
    );
    check(
      state.sessionCursors.deadbeefdeadbeefdeadbeef !== undefined,
      "legacy session cursors are preserved",
    );
    check(Object.keys(state.sessionFiles ?? {}).length === 1, "upgrade records a per-file checkpoint");
  });
}

// 6. Each session file advances on its own checkpoint.
async function testIndependentPerFileOffsets() {
  await withWorkspace("multi", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSessionA1", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ], "rollout-a.jsonl");
    await workspace.writeSession([
      metaLine("incrementalSessionB1", now),
      usageLine(now, { input: 200, output: 20, totalInput: 200, totalOutput: 20 }),
    ], "rollout-b.jsonl");

    const first = await workspace.importOnce();
    equal(first.imported_events, 2, "both session files import on the first run");

    const appended = `${usageLine(new Date(), { input: 300, output: 30, totalInput: 500, totalOutput: 50 })}\n`;
    await workspace.appendSession(appended, "rollout-b.jsonl");

    const second = await workspace.importOnce();
    equal(second.scanned_bytes, Buffer.byteLength(appended), "only the appended file is re-read");
    equal(second.imported_events, 1, "only the appended file imports a record");

    const trackedA = await workspace.trackedFile("rollout-a.jsonl");
    const trackedB = await workspace.trackedFile("rollout-b.jsonl");
    equal(
      trackedA.offset,
      (await stat(workspace.sessionPath("rollout-a.jsonl"))).size,
      "untouched file keeps its own checkpoint",
    );
    equal(
      trackedB.offset,
      (await stat(workspace.sessionPath("rollout-b.jsonl"))).size,
      "appended file advances its own checkpoint",
    );
    check(trackedA.offset !== trackedB.offset, "checkpoints are tracked per file");
  });
}

// 7. A failure to queue events must not move the checkpoint past them.
async function testCheckpointNeverPassesUnqueuedRecords() {
  await withWorkspace("failure", async (workspace) => {
    const now = new Date();
    await workspace.writeSession([
      metaLine("incrementalSession07", now),
      usageLine(now, { input: 100, output: 10, totalInput: 100, totalOutput: 10 }),
    ]);

    await chmod(workspace.inbox, 0o500);
    let threw = false;
    try {
      await workspace.importOnce();
    } catch {
      threw = true;
    }
    await chmod(workspace.inbox, 0o700);

    check(threw, "import fails when its events cannot be queued");
    let tracked;
    try {
      tracked = await workspace.trackedFile();
    } catch {
      tracked = undefined;
    }
    check(
      tracked === undefined || tracked.offset === 0,
      "checkpoint does not advance past records that were never queued",
    );

    const recovered = await workspace.importOnce();
    equal(recovered.imported_events, 1, "the unqueued record is imported on the next run");
  });
}

const tests = [
  ["second run reads only appended bytes", testSecondRunReadsOnlyAppendedBytes],
  ["incomplete trailing record waits for its newline", testIncompleteTrailingRecord],
  ["truncated file restarts from the beginning", testTruncatedFileRestarts],
  ["legacy state migrates to the new schema", testLegacyStateMigrates],
  ["session files keep independent checkpoints", testIndependentPerFileOffsets],
  ["checkpoint never passes unqueued records", testCheckpointNeverPassesUnqueuedRecords],
];

await runSuite(tests);
