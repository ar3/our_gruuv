module AbilitiesHelper
  # PaperTrail actor + timestamps for the spotlight footer (same pattern as assignment audit footer).
  def ability_audit_created_meta(ability)
    first_version = ability.versions.reorder(created_at: :asc, id: :asc).first
    [
      paper_trail_whodunnit_casual_name(first_version),
      ability.created_at
    ]
  end

  def ability_audit_last_updated_meta(ability)
    last_update = ability.versions.where(event: 'update').reorder(created_at: :desc, id: :desc).first
    if last_update
      [paper_trail_whodunnit_casual_name(last_update), last_update.created_at]
    else
      first_version = ability.versions.reorder(created_at: :asc, id: :asc).first
      [paper_trail_whodunnit_casual_name(first_version), ability.updated_at]
    end
  end

  def abilities_current_view_name
    return 'View Mode' unless action_name
    
    case action_name
    when 'show'
      if controller_path == 'organizations/abilities/maap_clarity'
        'Consult OG'
      else
        'View Mode'
      end
    when 'edit'
      'Edit Mode'
    when 'index'
      if controller_path == 'organizations/abilities/maap_proposals'
        all_proposed_ability_edits_label(@ability)
      else
        action_name.titleize
      end
    else
      action_name.titleize
    end
  end

  def open_ability_maap_proposals_count(ability)
    ability.maap_proposals.open_proposals.count
  end

  def all_proposed_ability_edits_label(ability)
    "All proposed edits (#{open_ability_maap_proposals_count(ability)})"
  end

  def ability_first_rating_alignment_marker_tone(agreement)
    case agreement
    when :all_same, :emp_mgr_same_no_final then "success"
    when :all_differed, :emp_mgr_differed_no_final then "danger"
    when :emp_mgr_same_final_differed then "warning"
    when :emp_final_same_mgr_differed then "info"
    when :mgr_final_same_emp_differed then "primary"
    else "secondary"
    end
  end

  def ability_first_rating_alignment_arrow_label(point)
    return "No final yet" unless point.has_final
    return "No direction" if point.arrow.blank?

    compared = case point.agreement
    when :mgr_final_same_emp_differed
      "employee"
    when :all_differed, :emp_mgr_same_final_differed, :emp_final_same_mgr_differed
      "manager"
    end
    return "No direction" if compared.blank?

    case point.arrow
    when :better
      "Final rated higher than #{compared}"
    when :worse
      "Final rated lower than #{compared}"
    else
      "No direction"
    end
  end

  def ability_first_rating_alignment_arrow_icon(point)
    return "".html_safe unless point.has_final

    label = ability_first_rating_alignment_arrow_label(point)
    case point.arrow
    when :better
      content_tag(:i, "", class: "bi bi-arrow-up-short text-success", title: label, "aria-label": label)
    when :worse
      content_tag(:i, "", class: "bi bi-arrow-down-short text-danger", title: label, "aria-label": label)
    else
      "".html_safe
    end
  end

  # Confidential: ratings + pattern only — never teammate or manager identity.
  def ability_first_rating_alignment_marker_popover(point)
    emp = ERB::Util.html_escape("M#{point.employee_first}")
    mgr = ERB::Util.html_escape("M#{point.manager_first}")
    final = if point.has_final
      point.official.to_i >= 1 ? ERB::Util.html_escape("M#{point.official}") : "None (0)"
    else
      "Not awarded yet"
    end
    column = ERB::Util.html_escape(
      Abilities::FirstRatingAlignmentQuery::COLUMN_LABELS[point.agreement] || "Incomplete"
    )
    arrow = ERB::Util.html_escape(ability_first_rating_alignment_arrow_label(point))

    <<~HTML.squish
      <div class="text-start">
        Employee first: #{emp}<br>
        Manager first: #{mgr}<br>
        Final: #{final}<br>
        Pattern: #{column}<br>
        Arrow: #{arrow}
      </div>
    HTML
  end
end
