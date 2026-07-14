# frozen_string_literal: true

module OgTipsHelper
  # Colors aligned with assignment energy pies (MyGrowth::ExperiencesSummary::RATING_BUCKETS)
  # and position rating emoji semantics on the check-in form.
  ASSIGNMENT_RATING_DOT_COLORS = {
    'working_to_meet' => '#ffc107',
    'meeting' => '#0d6efd',
    'exceeding' => '#198754'
  }.freeze

  POSITION_RATING_DOT_COLORS = {
    -3 => '#dc3545', # Performance Improvement Plan 🔴
    -2 => '#e35d6a', # Written Warning ⭕️
    -1 => '#fd7e14', # Verbal Warning 🟠
     1 => '#ffc107', # Developing 🟡
     2 => '#0d6efd', # Accomplished 🔵
     3 => '#198754'  # Exceptional 🟢
  }.freeze

  # Position 1-by-1 research tip: map assignment energy mix → likely position rating.
  def og_tip_position_assignment_energy_rating_body(summary:)
    chart_phrase = if summary&.show_inflight_viewer_rating_chart
                     'your in-flight check-in ratings chart'
                   else
                     'the latest finalized check-in ratings chart'
                   end

    safe_join(
      [
        tag.p(class: 'mb-2') do
          "Looking at #{chart_phrase}:"
        end,
        tag.p(class: 'mb-2') do
          safe_join(
            [
              "If more than 20% of a teammate's energy is ",
              og_tip_assignment_rating_with_dot('working_to_meet'),
              ', their overall rating is likely ',
              og_tip_position_rating_with_dot(1),
              ', ',
              og_tip_position_rating_with_dot(-1),
              ', ',
              og_tip_position_rating_with_dot(-2),
              ', or ',
              og_tip_position_rating_with_dot(-3),
              '.'
            ]
          )
        end,
        tag.p(class: 'mb-2') do
          safe_join(
            [
              'If more than 50% of a teammate\'s energy is ',
              og_tip_assignment_rating_with_dot('exceeding'),
              ' and none are ',
              og_tip_assignment_rating_with_dot('working_to_meet'),
              ', they are usually rated ',
              og_tip_position_rating_with_dot(3),
              '.'
            ]
          )
        end,
        tag.p(class: 'mb-2') do
          safe_join(
            [
              'Anything in between is usually rated ',
              og_tip_position_rating_with_dot(2),
              '.'
            ]
          )
        end,
        tag.p(class: 'mb-0') do
          "This isn't an exact science, but is a good rule of thumb if you aren't sure."
        end
      ]
    )
  end

  def og_tip_rating_dot(color)
    tag.span(
      '',
      class: 'og-tip-rating-dot',
      style: "background-color: #{color};",
      'aria-hidden': 'true'
    )
  end

  def og_tip_assignment_rating_with_dot(key)
    meta = MyGrowth::ExperiencesSummary::RATING_BUCKETS[key]
    label = meta&.dig(:label) || key.to_s.humanize
    color = meta&.dig(:color) || ASSIGNMENT_RATING_DOT_COLORS[key] || '#6c757d'

    tag.span(class: 'og-tip-rating-label text-nowrap') do
      safe_join([og_tip_rating_dot(color), ' ', tag.strong(label)])
    end
  end

  def og_tip_position_rating_with_dot(value)
    label = EmploymentTenure::POSITION_RATINGS.dig(value, :label) || value.to_s
    color = POSITION_RATING_DOT_COLORS[value] || '#6c757d'

    tag.span(class: 'og-tip-rating-label text-nowrap') do
      safe_join([og_tip_rating_dot(color), ' ', tag.strong(label)])
    end
  end
end
