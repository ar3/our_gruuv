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
      'View Mode'
    when 'edit'
      'Edit Mode'
    else
      action_name.titleize
    end
  end
end
