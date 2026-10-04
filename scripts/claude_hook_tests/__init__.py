"""Isolated Claude hook verification, shared by the CLI and unittest loader."""

import unittest

from .fixtures import ADAPTERS
from .label_tests import LabelTimelineTests
from .subagent_tests import SubagentTests
from .transcript_tests import QueueEmissionTests, TranscriptIdentityTests, TranscriptTailTests


TEST_CASES = (
    TranscriptTailTests, TranscriptIdentityTests, QueueEmissionTests,
    SubagentTests, LabelTimelineTests,
)


def suite_for(adapter, selected=None):
    prefix = "Bundled" if adapter == ADAPTERS[1] else "Canonical"
    cases = [type(prefix + case.__name__, (case,), {"adapter": adapter}) for case in TEST_CASES]
    if selected is not None:
        return unittest.TestSuite(
            next(case(name) for case in cases if hasattr(case, name))
            for name in selected
        )
    return unittest.TestSuite(
        unittest.defaultTestLoader.loadTestsFromTestCase(case) for case in cases
    )
