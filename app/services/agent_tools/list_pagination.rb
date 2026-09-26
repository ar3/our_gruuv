# frozen_string_literal: true

module AgentTools
  # Offset/limit pagination for list_* tools. Prefer this over silent 50-caps.
  module ListPagination
    MAX_LIMIT = 50
    DEFAULT_LIMIT = 25
    # Safety bound when materializing rows for in-memory visibility / text filters.
    SCAN_CAP = 5_000

    DETAIL_TOKEN_HINT =
      "Default detail=expensive includes body fields. Pass detail=minimal (name/title+path only) to save tokens.".freeze

    module_function

    def normalize(limit:, offset: 0)
      lim = limit.nil? || limit.to_s.strip.empty? ? DEFAULT_LIMIT : limit.to_i
      lim = DEFAULT_LIMIT if lim <= 0
      lim = lim.clamp(1, MAX_LIMIT)
      off = offset.to_i
      off = 0 if off.negative?
      { limit: lim, offset: off }
    end

    # @param records [Array]
    # @return [Hash] { items:, meta: { count, limit, offset, total_count, has_more, next_offset } }
    def slice(records, limit:, offset: 0)
      page = normalize(limit: limit, offset: offset)
      total = records.size
      items = Array(records)[page[:offset], page[:limit]] || []
      consumed = page[:offset] + items.size
      has_more = consumed < total

      {
        items: items,
        meta: {
          count: items.size,
          limit: page[:limit],
          offset: page[:offset],
          total_count: total,
          has_more: has_more,
          next_offset: has_more ? consumed : nil
        }
      }
    end

    def scan_relation(relation, scan_cap: SCAN_CAP)
      rows = relation.limit(scan_cap + 1).to_a
      truncated = rows.size > scan_cap
      [rows.first(scan_cap), truncated]
    end
  end
end
