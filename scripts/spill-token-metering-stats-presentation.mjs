// Text presentation for read-only stats comparison projections.
export function appendComparisonSections(lines, report, { compact, number, percent }) {
  const accounting = report.input_accounting;
  lines.push("", "Input Accounting (exact recorded values)");
  lines.push(`  Fresh ${compact(accounting.fresh_tokens)} | Cache write ${compact(accounting.cache_write_tokens)} | Cache read ${compact(accounting.cache_read_tokens)} | Unclassified ${compact(accounting.unclassified_tokens)}`);
  lines.push(`  Coverage ${percent(accounting.input_coverage)} input | ${percent(accounting.event_coverage)} events | Cache read ${percent(accounting.cache_read_share_of_all_input)} of all input (${percent(accounting.cache_read_share_of_classified_input)} of classified input)`);
  lines.push(`  Fresh + output exact subtotal ${compact(accounting.fresh_plus_output_subtotal)} | Reference weighted subtotal ${compact(accounting.reference_weighted_subtotal)}${accounting.complete ? " (complete input coverage)" : " (incomplete input coverage)"}`);
  lines.push("  Reference weights: fresh=1, cache write=1.25, cache read=0.1, output=1; comparison index, not model pricing or dollar cost.");
  lines.push("  Both subtotals exclude unclassified input; output is included exactly.");
  if (accounting.by_tool.length > 1) {
    for (const tool of accounting.by_tool) {
      lines.push(`  ${tool.ai_tool}: Fresh ${compact(tool.fresh_tokens)} | Cache write ${compact(tool.cache_write_tokens)} | Cache read ${compact(tool.cache_read_tokens)} | Unclassified ${compact(tool.unclassified_tokens)} | Coverage ${percent(tool.input_coverage)} | Fresh + output ${compact(tool.fresh_plus_output_subtotal)} | Reference weighted ${compact(tool.reference_weighted_subtotal)}`);
    }
  }
  const context = report.context_size;
  lines.push("", "Context Size Proxy (input per event)");
  lines.push(`  Average ${compact(context.avg_input_tokens_per_event)} | Maximum ${compact(context.max_input_tokens_per_event)}`);
  lines.push("  Input per event is a proxy, not an exact context window; an event may combine requests.");
  lines.push("", `Top Sessions (opaque run IDs, up to ${report.sessions.per_tool_limit} per tool)`);
  if (report.sessions.top.length === 0) lines.push("  none");
  for (const session of report.sessions.top) {
    lines.push(`  ${session.ai_tool} ${session.run_id} | Total ${compact(session.total_tokens)} | Input ${compact(session.input_tokens)} | Output ${compact(session.output_tokens)} | ${number(session.events)} events | ${percent(session.token_share_of_tool)} of tool tokens`);
  }
  if (report.sessions.unattributed_events > 0) {
    lines.push(`  ${number(report.sessions.unattributed_events)} events without a safe opaque run ID are not listed.`);
  }
}
