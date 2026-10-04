// Read-only comparison projections from Spill's existing local accounting columns.
// Weights are a fixed reference index, not model prices or estimated token counts.
const columnsByKind = {
  fresh: "accounting_uncached_input_tokens",
  cache_write: "accounting_cache_creation_input_tokens",
  cache_read: "accounting_cache_read_input_tokens",
};
const referenceWeights = { fresh: 1, cache_write: 1.25, cache_read: 0.1, output: 1 };
const inputSQL = "CAST(json_extract(CAST(payload_json AS TEXT), '$.input_tokens') AS INTEGER)";
const outputSQL = "CAST(json_extract(CAST(payload_json AS TEXT), '$.output_tokens') AS INTEGER)";
// Match the adapter's opaque-ID allowlist; exclude unsafe values inside SQL.
const opaqueRunSQL = "length(run_id) BETWEEN 6 AND 64 AND run_id NOT GLOB '*[^A-Za-z0-9_-]*'";
const safeToolSQL = "length(ai_tool) BETWEEN 2 AND 41 AND substr(ai_tool, 1, 1) GLOB '[a-z]' AND ai_tool NOT GLOB '*[^a-z0-9_]*'";

export function readComparisonReport({ query, columns, where, events, limit }) {
  const availableFields = Object.keys(columnsByKind).filter((kind) => columns.has(columnsByKind[kind]));
  const projectAccounting = (row = {}) => {
    const value = (name) => Number(row[name] ?? 0);
    const input = value("input_tokens");
    const classified = value("fresh_tokens") + value("cache_write_tokens") + value("cache_read_tokens");
    return {
      ...(row.ai_tool ? { ai_tool: row.ai_tool } : {}),
      input_tokens: input,
      output_tokens: value("output_tokens"),
      fresh_tokens: value("fresh_tokens"),
      cache_write_tokens: value("cache_write_tokens"),
      cache_read_tokens: value("cache_read_tokens"),
      unclassified_tokens: input - classified,
      classified_tokens: classified,
      events: value("events"),
      events_with_accounting: value("events_with_accounting"),
      complete_events: value("complete_events"),
      input_coverage: input > 0 ? classified / input : 0,
      event_coverage: value("events") > 0 ? value("events_with_accounting") / value("events") : 0,
      cache_read_share_of_all_input: input > 0 ? value("cache_read_tokens") / input : 0,
      cache_read_share_of_classified_input: classified > 0 ? value("cache_read_tokens") / classified : 0,
      fresh_plus_output_subtotal: value("fresh_tokens") + value("output_tokens"),
      reference_weighted_subtotal: value("fresh_tokens") + value("cache_write_tokens") * referenceWeights.cache_write
        + value("cache_read_tokens") * referenceWeights.cache_read + value("output_tokens"),
      complete: value("events") > 0 && value("complete_events") === value("events"),
    };
  };
  const totals = projectAccounting(query(accountingSQL(columns, where))[0]);
  const byTool = query(accountingSQL(columns, where, true)).map(projectAccounting);
  const sessionAvailable = columns.has("run_id");
  const safeSessions = sessionAvailable ? query(sessionSQL(where, limit)) : [];
  const opaqueEvents = sessionAvailable ? Number(query(`
    SELECT COUNT(*) AS events FROM token_usage_events
    ${where ? `${where} AND` : "WHERE"} ${opaqueRunSQL} AND ${safeToolSQL};
  `)[0]?.events ?? 0) : 0;
  return {
    input_accounting: {
      available_fields: availableFields,
      schema_available: availableFields.length === 3,
      ...totals,
      by_tool: byTool,
      reference_weights: referenceWeights,
      reference_note: "Fixed reference comparison index; not model pricing or a dollar cost estimate. Unclassified input is excluded from both comparison subtotals; output is included exactly.",
    },
    sessions: {
      available: sessionAvailable,
      grouping: "ai_tool/run_id",
      per_tool_limit: limit,
      opaque_id_events: opaqueEvents,
      unattributed_events: events - opaqueEvents,
      top: safeSessions,
    },
  };
}

function accountingSQL(columns, where, byTool = false) {
  const fields = Object.entries(columnsByKind)
    .map(([kind, column]) => `${columns.has(column) ? column : "NULL"} AS ${kind}`).join(", ");
  const validParts = Object.keys(columnsByKind).map((kind) =>
    `typeof(${kind}) = 'integer' AND ${kind} BETWEEN 0 AND ${Number.MAX_SAFE_INTEGER}`);
  const valid = `${validParts.join(" AND ")} AND fresh + cache_write + cache_read <= input_tokens`;
  return `
    WITH inputs AS (
      SELECT ai_tool, ${inputSQL} AS input_tokens, ${outputSQL} AS output_tokens, ${fields}
      FROM token_usage_events ${where}
    ), checked AS (
      SELECT *, CASE WHEN ${valid} THEN 1 ELSE 0 END AS valid FROM inputs
    )
    SELECT ${byTool ? "ai_tool," : ""}
      COUNT(*) AS events,
      COALESCE(SUM(input_tokens), 0) AS input_tokens,
      COALESCE(SUM(output_tokens), 0) AS output_tokens,
      COALESCE(SUM(CASE WHEN valid THEN fresh ELSE 0 END), 0) AS fresh_tokens,
      COALESCE(SUM(CASE WHEN valid THEN cache_write ELSE 0 END), 0) AS cache_write_tokens,
      COALESCE(SUM(CASE WHEN valid THEN cache_read ELSE 0 END), 0) AS cache_read_tokens,
      COALESCE(SUM(valid), 0) AS events_with_accounting,
      COALESCE(SUM(CASE WHEN valid AND fresh + cache_write + cache_read = input_tokens THEN 1 ELSE 0 END), 0) AS complete_events
    FROM checked ${byTool ? "GROUP BY ai_tool ORDER BY input_tokens DESC, ai_tool ASC" : ""};
  `;
}

function sessionSQL(where, limit) {
  return `
    WITH scoped AS (
      SELECT ai_tool, run_id, total_tokens, ${inputSQL} AS input_tokens, ${outputSQL} AS output_tokens
      FROM token_usage_events ${where}
    ), tool_totals AS (
      SELECT ai_tool, SUM(total_tokens) AS tool_tokens FROM scoped GROUP BY ai_tool
    ), grouped AS (
      SELECT ai_tool, run_id, COUNT(*) AS events, SUM(total_tokens) AS total_tokens,
        SUM(input_tokens) AS input_tokens, SUM(output_tokens) AS output_tokens
      FROM scoped WHERE ${opaqueRunSQL} AND ${safeToolSQL} GROUP BY ai_tool, run_id
    ), ranked AS (
      SELECT grouped.*, CASE WHEN tool_tokens > 0 THEN 1.0 * total_tokens / tool_tokens ELSE 0 END AS token_share_of_tool,
        ROW_NUMBER() OVER (PARTITION BY grouped.ai_tool ORDER BY total_tokens DESC, events DESC, run_id ASC) AS position
      FROM grouped JOIN tool_totals USING (ai_tool)
    )
    SELECT ai_tool, run_id, events, total_tokens, input_tokens, output_tokens, token_share_of_tool
    FROM ranked WHERE position <= ${limit} ORDER BY ai_tool ASC, position ASC;
  `;
}
