# frozen_string_literal: true

module MyGrowthAbilitiesHelper
  MILEAGE_POPOVER_NOTE =
    'Miles are a way to allow people to go after expertise in the things that they find great interest in. ' \
    "Some positions don't dictate the specific milestones, but instead/also dictate a certain amount of mileage. " \
    'This is powerful because it allows every person to be unique in their growth.'.freeze

  # Comma-separated caption: "Direct requires M2", assignment title links + " requires M3"
  def my_growth_ability_requirement_caption_html(organization, teammate, sources)
    return ''.html_safe if sources.blank?

    fragments = sources.filter_map do |src|
      case src[:kind]
      when :direct
        "Direct requires M#{src[:level].to_i}".html_safe
      when :assignment
        assignment = src[:assignment]
        next if assignment.blank?

        safe_join(
          [
            link_to(assignment.title, organization_teammate_assignment_path(organization, teammate, assignment),
                    class: 'text-decoration-none'),
            " requires M#{src[:level].to_i}".html_safe
          ],
          ''
        )
      end
    end

    safe_join(fragments, ', ')
  end

  def my_growth_milestone_miles_label(points)
    pts = points.to_i
    "#{pts} #{pts == 1 ? 'Mile' : 'Miles'}"
  end

  def my_growth_ability_earned_miles_total(earned_levels)
    ms = MilestoneMileageService.new
    Array(earned_levels).map(&:to_i).uniq.sum { |lvl| ms.milestone_points(lvl) }
  end

  def my_growth_ability_required_miles_total(minimum_milestone_level)
    MilestoneMileageService.new.points_through_milestone(minimum_milestone_level.to_i)
  end

  def my_growth_milestone_mileage_earned_breakdown_sentence(earned_levels)
    ms = MilestoneMileageService.new
    levels = Array(earned_levels).map(&:to_i).sort.uniq
    return 'No milestone miles earned for this ability yet.' if levels.empty?

    segments = levels.map do |lvl|
      pts = ms.milestone_points(lvl)
      "#{my_growth_milestone_miles_label(pts)} from Milestone #{lvl}"
    end
    total = levels.sum { |lvl| ms.milestone_points(lvl) }
    "#{segments.join(' + ')} = #{total} miles"
  end

  def my_growth_milestone_mileage_required_breakdown_sentence(minimum_milestone_level)
    ms = MilestoneMileageService.new
    n = minimum_milestone_level.to_i
    return nil if n < 1

    segments = (1..n).map do |lvl|
      pts = ms.milestone_points(lvl)
      "#{my_growth_milestone_miles_label(pts)} from Milestone #{lvl}"
    end
    total = ms.points_through_milestone(n)
    "#{segments.join(' + ')} = #{total} miles"
  end

  def my_growth_milestone_mileage_popover_inner_html(breakdown_sentence)
    sentence = breakdown_sentence.presence || '0 miles'
    content_tag(:div, class: 'small text-start') do
      safe_join(
        [
          content_tag(:div, sentence),
          content_tag(:p, MILEAGE_POPOVER_NOTE, class: 'small text-muted mb-0 mt-2')
        ],
        ''
      )
    end
  end

  # First-column totals card: border from aggregate earned miles vs position mileage thresholds.
  def my_growth_aggregate_mileage_earned_border_classes(earned_miles:, current_minimum_miles:, target_minimum_miles:, target_position_defined:)
    earned = earned_miles.to_i
    curr = current_minimum_miles&.to_i
    targ = target_minimum_miles&.to_i

    current_met = current_minimum_miles.nil? || earned >= curr

    if current_minimum_miles.present? && earned < curr
      'border border-2 border-warning'
    elsif target_position_defined && target_minimum_miles.present? && current_met && earned < targ
      'border border-2 border-info'
    else
      'border border-2 border-success'
    end
  end

  # Border color for the first-column (earned) card only — vs current + optional target milestone requirements.
  # warning: below current blueprint requirement; info: meets current but below target (when target is set);
  # success: meets all applicable requirements.
  def my_growth_ability_row_card_border_classes(earned_levels:, target_position:, cur:, tar:)
    highest = earned_levels.present? ? earned_levels.map(&:to_i).max : 0

    current_req = cur.present? ? cur[:minimum_milestone_level].to_i : nil
    target_req =
      if target_position.present? && tar.present?
        tar[:minimum_milestone_level].to_i
      end

    current_met = current_req.nil? || highest >= current_req

    if current_req.present? && highest < current_req
      'border border-2 border-warning'
    elsif target_position.present? && target_req.present? && current_met && highest < target_req
      'border border-2 border-info'
    else
      'border border-2 border-success'
    end
  end

  def my_growth_certifier_awards_popover_inner_html(certifier_rows)
    return nil if certifier_rows.blank?

    list_items = certifier_rows.map do |r|
      n = r[:count].to_i
      miles_word = n == 1 ? 'milestone' : 'milestones'
      content_tag(:li, "#{ERB::Util.html_escape(r[:display_name])} — #{n} #{miles_word}".html_safe)
    end
    content_tag(:ul, safe_join(list_items, ''), class: 'mb-0 ps-3 small text-start')
  end

  def my_growth_recognizers_summary_html(certifier_rows, milestone_record_count:)
    if milestone_record_count.to_i <= 0
      return content_tag(:p, 'No milestones earned in this organization yet.', class: 'small text-muted mb-0')
    end

    if certifier_rows.blank?
      return content_tag(:p, 'Milestone recognizer details are not available.', class: 'small text-muted mb-0')
    end

    n = certifier_rows.size
    people_phrase = "#{n} #{'person'.pluralize(n)}"
    pop_html = my_growth_certifier_awards_popover_inner_html(certifier_rows)
    trigger = my_growth_text_popover_trigger_html(
      text: people_phrase,
      title: 'Who awarded milestones',
      content_html: pop_html
    )

    content_tag(:p, class: 'small text-muted mb-0') do
      safe_join(['Recognized by '.html_safe, trigger, '.'.html_safe], '')
    end
  end

  def my_growth_text_popover_trigger_html(text:, title:, content_html:)
    return ''.html_safe if content_html.blank?

    content_tag(
      :span,
      text,
      class: 'my-growth-ability-miles text-decoration-underline',
      role: 'button',
      tabindex: 0,
      aria: { label: title },
      data: {
        bs_toggle: 'popover',
        bs_trigger: 'hover focus',
        bs_placement: 'auto',
        bs_html: true,
        bs_title: title,
        bs_content: content_html
      }
    )
  end

  # Right column: "+N" with hover/focus popover, or em dash when not applicable.
  def my_growth_ability_miles_trigger_html(total_points:, popover_inner_html:, title: 'Milestone miles')
    if popover_inner_html.blank?
      return content_tag(:span, '—', class: 'text-muted small')
    end

    content_tag(
      :span,
      "+#{total_points.to_i}",
      class: 'my-growth-ability-miles text-nowrap small fw-semibold text-body-secondary',
      role: 'button',
      tabindex: 0,
      aria: { label: title },
      data: {
        bs_toggle: 'popover',
        bs_trigger: 'hover focus',
        bs_placement: 'auto',
        bs_html: true,
        bs_title: title,
        bs_content: popover_inner_html
      }
    )
  end
end
