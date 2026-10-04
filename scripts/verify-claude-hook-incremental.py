#!/usr/bin/env python3
"""Verify Claude hooks with isolated synthetic metadata; optionally benchmark batches.

No real Claude transcripts, Spill stores, labels, or diagnostics are read. Both
the canonical adapter and its bundled copy run the same regression suite.
--negative-control accepts an earlier adapter copy to reproduce the old bugs;
those expected failures are evidence for the regression fixtures, not gates.
--benchmark optionally compares that copy against the canonical adapter using
identical fixtures. Timings measure local instrumented processing, not tokens
or billed API cost. There are deliberately no timing assertions in the tests.
"""

import argparse
import json
import pathlib
import sys
import unittest

# Resolve the repo-owned verification package for both direct CLI and unittest.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from claude_hook_tests import ADAPTERS, suite_for
from claude_hook_tests.benchmark import benchmark


def load_tests(loader, tests, pattern):
    return unittest.TestSuite(suite_for(adapter) for adapter in ADAPTERS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--negative-control", type=pathlib.Path, help="Reproduce old bugs against a saved adapter copy; expected failures exit successfully.")
    parser.add_argument("--benchmark", action="store_true", help="Run optional synthetic local processing measurements after tests.")
    parser.add_argument("--baseline-adapter", type=pathlib.Path, help="Saved adapter copy for paired optional benchmark.")
    parser.add_argument("--benchmark-repeats", type=int, default=7)
    args = parser.parse_args()
    if args.benchmark_repeats < 1:
        parser.error("--benchmark-repeats must be positive")
    if args.negative_control:
        # These tests intentionally reject the known pre-fix behavior.
        print("Running intentional negative controls against a saved pre-fix adapter.", flush=True)
        controls = (
            "test_partial_json_tail_resumes_without_loss",
            "test_partial_utf8_tail_resumes_without_loss",
            "test_history_partial_tail_resumes_without_loss",
            "test_unchanged_eof_does_not_open_transcript",
            "test_session_subagent_imports_when_main_has_no_delta",
            "test_legacy_subagent_imports_when_main_has_no_delta",
            "test_old_subagents_are_not_excluded_by_lookback",
            "test_history_batch_loads_timeline_once",
        )
        result = unittest.TextTestRunner(verbosity=1).run(suite_for(args.negative_control, controls))
        reproduced = {test._testMethodName for test, _ in result.failures}
        if result.errors or reproduced != set(controls):
            return 1
        print(json.dumps({"negative_controls_reproduced": len(reproduced), "expected_failures": True}, sort_keys=True))
        if args.benchmark:
            benchmark([("baseline", args.negative_control)], args.benchmark_repeats)
        return 0
    combined = unittest.TestSuite(suite_for(adapter) for adapter in ADAPTERS)
    result = unittest.TextTestRunner(verbosity=2).run(combined)
    if not result.wasSuccessful():
        return 1
    if args.benchmark:
        adapters = [("canonical", ADAPTERS[0]), ("bundled", ADAPTERS[1])]
        if args.baseline_adapter:
            adapters.insert(0, ("baseline", args.baseline_adapter))
        benchmark(adapters, args.benchmark_repeats)
    return 0


if __name__ == "__main__":
    sys.exit(main())
