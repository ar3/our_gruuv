# frozen_string_literal: true

module Goals
  # Best-effort parse/rewrite of Progressive Outcome titles.
  # Supported shapes (examples):
  # - "… from 50% to [60|70|80]%" (baseline optional)
  # - "… [60|70|80]%" or "… [1|2|3] requests" (Commit|Stretch|Transform, no baseline)
  # - "… from 50% to 60% (Stretch = 70% & Transform = 80%)"
  # - "… Commit:60%, Stretch:70%, Transform:80%" (baseline optional)
  class ProgressiveOutcomeProse
    AIM_ORDER = %w[commit stretch transform].freeze
    # Escape % so Ruby does not treat %| as a percent literal inside /.../.
    UNIT = '(?:\%|pp|pts?|points)'

    Result = Struct.new(
      :baseline, :commit, :stretch, :transform, :unit,
      keyword_init: true
    )

    def self.parse(title)
      new(title).parse
    end

    def self.rewrite_after_hit(title, hit_aim:)
      new(title).rewrite_after_hit(hit_aim: hit_aim)
    end

    def initialize(title)
      @title = title.to_s.strip
    end

    def parse
      return empty_result if @title.blank?

      bracket = parse_bracket_form
      return bracket if bracket

      paren = parse_paren_stretch_transform_form
      return paren if paren

      labeled = parse_labeled_form
      return labeled if labeled

      empty_result
    end

    def rewrite_after_hit(hit_aim:)
      aim = hit_aim.to_s
      return @title if @title.blank? || AIM_ORDER.exclude?(aim)

      parsed = parse
      remaining = remaining_aims_after(aim)
      return fallback_title_without_hit(aim, parsed) if remaining.empty?

      if bracket_form?
        rewrite_bracket(parsed, remaining)
      elsif labeled_form?
        rewrite_labeled(parsed, remaining)
      elsif paren_form?
        rewrite_paren(parsed, remaining, hit_aim: aim)
      else
        fallback_title_without_hit(aim, parsed)
      end
    end

    private

    def empty_result
      Result.new(baseline: nil, commit: nil, stretch: nil, transform: nil, unit: nil)
    end

    def bracket_form?
      @title.match?(/\[\s*[-+]?\d+(?:\.\d+)?\s*(?:\|\s*[-+]?\d+(?:\.\d+)?\s*){1,2}\]\s*#{UNIT}?/i)
    end

    def labeled_form?
      @title.match?(/\bCommit\s*[:=]/i) && @title.match?(/\bStretch\s*[:=]/i)
    end

    def paren_form?
      @title.match?(/\(\s*Stretch\s*=/i)
    end

    def parse_bracket_form
      # Prefer "from baseline to [C|S|T]" when present; otherwise bare "[C|S|T]".
      match = @title.match(
        /(?:from\s+(?<baseline>[-+]?\d+(?:\.\d+)?)\s*(?<unit>#{UNIT})?\s+to\s+)?\[\s*(?<a>[-+]?\d+(?:\.\d+)?)\s*\|\s*(?<b>[-+]?\d+(?:\.\d+)?)(?:\s*\|\s*(?<c>[-+]?\d+(?:\.\d+)?))?\s*\]\s*(?<unit2>#{UNIT})?/i
      )
      return nil unless match

      values = [match[:a], match[:b], match[:c]].compact.map { |v| BigDecimal(v) }
      return nil if values.size < 2

      unit = normalize_unit(match[:unit2].presence || match[:unit])
      Result.new(
        baseline: match[:baseline] && decimal(match[:baseline]),
        commit: values[0],
        stretch: values[1],
        transform: values[2],
        unit: unit
      )
    end

    def parse_labeled_form
      baseline_match = @title.match(/from\s+(?<baseline>[-+]?\d+(?:\.\d+)?)\s*(?<unit>#{UNIT})?/i)
      return nil unless labeled_form?

      commit = capture_labeled("Commit")
      stretch = capture_labeled("Stretch")
      transform = capture_labeled("Transform")
      return nil if commit.nil? && stretch.nil? && transform.nil?

      unit = normalize_unit(
        baseline_match && baseline_match[:unit]
      ) || unit_near_labeled || "%"

      Result.new(
        baseline: baseline_match && decimal(baseline_match[:baseline]),
        commit: commit,
        stretch: stretch,
        transform: transform,
        unit: unit
      )
    end

    def parse_paren_stretch_transform_form
      match = @title.match(
        /from\s+(?<baseline>[-+]?\d+(?:\.\d+)?)\s*(?<unit>#{UNIT})?\s+to\s+(?<commit>[-+]?\d+(?:\.\d+)?)\s*(?<unit2>#{UNIT})?\s*\(\s*Stretch\s*=\s*(?<stretch>[-+]?\d+(?:\.\d+)?)\s*(?<unit3>#{UNIT})?(?:\s*[&,]\s*Transform\s*=\s*(?<transform>[-+]?\d+(?:\.\d+)?)\s*(?<unit4>#{UNIT})?)?\s*\)/i
      )
      return nil unless match

      unit = normalize_unit(match[:unit4] || match[:unit3] || match[:unit2] || match[:unit])
      Result.new(
        baseline: decimal(match[:baseline]),
        commit: decimal(match[:commit]),
        stretch: decimal(match[:stretch]),
        transform: match[:transform] && decimal(match[:transform]),
        unit: unit
      )
    end

    def capture_labeled(label)
      match = @title.match(/\b#{label}\s*[:=]\s*(?<n>[-+]?\d+(?:\.\d+)?)\s*(?<unit>#{UNIT})?/i)
      match && decimal(match[:n])
    end

    def unit_near_labeled
      match = @title.match(/\b(?:Commit|Stretch|Transform)\s*[:=]\s*[-+]?\d+(?:\.\d+)?\s*(?<unit>#{UNIT})/i)
      normalize_unit(match && match[:unit])
    end

    def remaining_aims_after(hit_aim)
      idx = AIM_ORDER.index(hit_aim.to_s)
      return [] if idx.nil?

      AIM_ORDER[(idx + 1)..]
    end

    def rewrite_bracket(parsed, remaining)
      values = remaining.filter_map { |aim| value_for(parsed, aim) }
      return @title if values.empty?

      unit = parsed.unit.presence || "%"
      baseline = format_num(parsed.baseline)
      inner = values.map { |v| format_num(v) }.join("|")
      if baseline
        @title.sub(
          /from\s+[-+]?\d+(?:\.\d+)?\s*#{UNIT}?\s+to\s+\[[^\]]+\]\s*#{UNIT}?/i,
          "from #{baseline}#{unit} to [#{inner}]#{unit}"
        )
      else
        @title.sub(/\[[^\]]+\]/, "[#{inner}]")
      end
    end

    def rewrite_labeled(parsed, remaining)
      parts = remaining.filter_map do |aim|
        value = value_for(parsed, aim)
        next unless value

        "#{aim.capitalize}:#{format_num(value)}#{parsed.unit.presence || '%'}"
      end
      return @title if parts.empty?

      replacement = parts.join(", ")
      if @title.match?(/to\s+Commit\s*[:=]/i)
        @title.sub(/to\s+Commit\s*[:=].+$/i, "to #{replacement}")
      else
        "#{base_clause(parsed)} to #{replacement}"
      end
    end

    def rewrite_paren(parsed, remaining, hit_aim:)
      unit = parsed.unit.presence || "%"

      if hit_aim == "commit" && parsed.stretch
        baseline = format_num(parsed.baseline)
        stretch_target = format_num(parsed.stretch)
        return @title unless baseline

        prefix = @title.sub(/\s*\(.*\)\s*\z/, "").sub(
          /from\s+[-+]?\d+(?:\.\d+)?\s*#{UNIT}?\s+to\s+[-+]?\d+(?:\.\d+)?\s*#{UNIT}?/i,
          "from #{baseline}#{unit} to #{stretch_target}#{unit}"
        )
        if remaining.include?("transform") && parsed.transform
          "#{prefix.sub(/\s*\(.*\)\s*\z/, '')} (Transform = #{format_num(parsed.transform)}#{unit})"
        else
          prefix.sub(/\s*\(.*\)\s*\z/, "")
        end
      elsif hit_aim == "stretch" && parsed.transform
        baseline = format_num(parsed.baseline)
        transform_target = format_num(parsed.transform)
        return @title unless baseline

        @title.sub(/\s*\(.*\)\s*\z/, "").sub(
          /from\s+[-+]?\d+(?:\.\d+)?\s*#{UNIT}?\s+to\s+[-+]?\d+(?:\.\d+)?\s*#{UNIT}?/i,
          "from #{baseline}#{unit} to #{transform_target}#{unit}"
        ).sub(/\s*\(.*\)\s*\z/, "")
      else
        fallback_title_without_hit(hit_aim, parsed)
      end
    end

    def fallback_title_without_hit(hit_aim, parsed)
      next_aim = remaining_aims_after(hit_aim).first
      next_value = next_aim && value_for(parsed, next_aim)
      unit = parsed.unit.presence || "%"
      baseline = format_num(parsed.baseline)
      return @title unless next_value && baseline

      "Move from #{baseline}#{unit} to #{format_num(next_value)}#{unit}"
    end

    def base_clause(parsed)
      unit = parsed.unit.presence || "%"
      baseline = format_num(parsed.baseline)
      return @title.split(/\s+to\s+/i).first if baseline.nil?

      if @title.match?(/from\s+/i)
        @title.sub(/\s+to\s+.+\z/i, "").presence || "from #{baseline}#{unit}"
      else
        "from #{baseline}#{unit}"
      end
    end

    def value_for(parsed, aim)
      case aim.to_s
      when "commit" then parsed.commit
      when "stretch" then parsed.stretch
      when "transform" then parsed.transform
      end
    end

    def decimal(value)
      return nil if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def format_num(value)
      return nil if value.nil?

      f = value.to_f
      f == f.to_i ? f.to_i.to_s : value.to_s("F")
    end

    def normalize_unit(unit)
      return nil if unit.blank?

      case unit.to_s.downcase
      when "point", "points", "pts", "pt" then "pts"
      else unit.to_s
      end
    end
  end
end
