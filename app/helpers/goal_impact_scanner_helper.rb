# frozen_string_literal: true

module GoalImpactScannerHelper
  # Initial-confidence designation colors (not traffic-light status).
  # Commit = most sure → Transform = most wishful.
  INITIAL_CONFIDENCE_STYLES = {
    commit: {
      label: "Commit",
      background: "#1e3a5f",
      color: "#f5f8fc"
    },
    stretch: {
      label: "Stretch",
      background: "#9ec9e6",
      color: "#12324a"
    },
    transform: {
      label: "Transform",
      background: "#8b6bb5",
      color: "#f7f4fb"
    }
  }.freeze

  def goal_impact_initial_confidence_key(goal)
    (goal.initial_confidence.presence || "stretch").to_sym
  end

  def goal_impact_initial_confidence_label(goal)
    INITIAL_CONFIDENCE_STYLES.fetch(goal_impact_initial_confidence_key(goal))[:label]
  end

  def goal_impact_goal_type_label(goal)
    goal.goal_type.to_s.humanize
  end

  def goal_impact_designation_pill_text(goal)
    "#{goal_impact_initial_confidence_label(goal)} – #{goal_impact_goal_type_label(goal)}"
  end

  def goal_impact_designation_pill_style(goal)
    style = INITIAL_CONFIDENCE_STYLES.fetch(goal_impact_initial_confidence_key(goal))
    "background-color: #{style[:background]}; color: #{style[:color]}; font-weight: 500; font-size: 0.7rem; opacity: 0.92;"
  end

  def goal_impact_designation_popover_title
    "Commit, Stretch, and Transform"
  end

  def goal_impact_designation_popover_content(goal)
    band = goal_impact_initial_confidence_key(goal)
    band_label = goal_impact_initial_confidence_label(goal)
    this_meaning = case band
    when :commit
      "we treat it as something we must hit, and we should be at least 80% sure we can"
    when :stretch
      "it will stretch us, and we are only about 50% sure we will hit it"
    else
      "hitting it would change everything, and we are less than 50% sure we can"
    end

    <<~HTML.strip
      <p class="mb-2">Not all goals are created equal. Sometimes we have goals we must hit—we call those <strong>Commit</strong> goals. We should be at least 80% sure we can hit them.</p>
      <p class="mb-2">Then we have goals that will stretch us, where we are only about 50% sure we will hit—we call those <strong>Stretch</strong> goals.</p>
      <p class="mb-2">Finally there are goals that, if we hit them, would change everything—and we are less than 50% sure we can. We call those <strong>Transform</strong> goals. It is important to set goals that push us to think creatively; even when we miss, we are better for striving and learning.</p>
      <p class="mb-0"><strong>This goal is a #{ERB::Util.html_escape(band_label)} goal</strong>, meaning #{ERB::Util.html_escape(this_meaning)}.</p>
    HTML
  end

  def goal_impact_rollup_summary(rollup)
    return nil if rollup.blank? || rollup.descendant_count.zero?

    count = rollup.descendant_count
    goals_phrase = "#{count} #{'descendant goal'.pluralize(count)}"

    if rollup.average_confidence.present?
      possessive = count == 1 ? "its" : "their"
      "#{goals_phrase}, and #{possessive} latest confidence, averages #{rollup.average_confidence}%"
    else
      "#{goals_phrase}; none have a latest confidence check yet"
    end
  end

  def goal_impact_confidence_display(check_in)
    return "No confidence check yet" if check_in.blank? || check_in.confidence_percentage.nil?

    "#{check_in.confidence_percentage}% latest"
  end
end
