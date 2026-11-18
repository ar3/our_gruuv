# frozen_string_literal: true

module Og3Helper
  # Short / medium / clear labels for OG3 Progressive Outcomes.
  # Prefer the clear version when space allows. Internal type remains progressive_outcome.

  def og3_label_short
    "OG3"
  end

  def og3_label_medium
    "OG3 Goals"
  end

  def og3_label_clear
    "OG3 Progressive Outcome"
  end

  def og3_label_clear_goal
    "OG3 Progressive Outcome (Goal)"
  end

  def og3_label(variant = :clear)
    case variant.to_sym
    when :short then og3_label_short
    when :medium then og3_label_medium
    when :clear_goal then og3_label_clear_goal
    else og3_label_clear
    end
  end

  # Hover tooltip. Full theory lives on the marketing page + page help.
  def og3_hover_blurb
    "OG3 Progressive Outcomes name Commit (≈80%+ sure), Stretch (≈50/50), and Transform (near-impossible until someone does it). Weekly confidence tracks the current aim... Learning matters as much as the result."
  end

  def og3_marketing_path
    og3_goals_path
  end

  def og3_format_outcome_value(value, unit)
    return nil if value.nil?

    num = value.to_f
    formatted = num == num.to_i ? num.to_i.to_s : value.to_s("F").sub(/\.?0+$/, "")
    unit_text = unit.to_s.strip
    return formatted if unit_text.blank?

    # Space before word units ("customers"); glue symbols ("%", "$").
    unit_text.match?(/\A[[:alpha:]]/) ? "#{formatted} #{unit_text}" : "#{formatted}#{unit_text}"
  end

  def og3_current_aim_label(goal)
    (goal.progressive_current_aim.presence || "commit").to_s.upcase
  end
end

