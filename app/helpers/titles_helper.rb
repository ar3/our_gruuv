module TitlesHelper
  # PaperTrail actor + timestamps for title Actions card footer (same pattern as assignments / abilities).
  def title_audit_created_meta(title)
    first_version = title.versions.reorder(created_at: :asc, id: :asc).first
    [
      paper_trail_whodunnit_casual_name(first_version),
      title.created_at
    ]
  end

  def title_audit_last_updated_meta(title)
    last_update = title.versions.where(event: 'update').reorder(created_at: :desc, id: :desc).first
    if last_update
      [paper_trail_whodunnit_casual_name(last_update), last_update.created_at]
    else
      first_version = title.versions.reorder(created_at: :asc, id: :asc).first
      [paper_trail_whodunnit_casual_name(first_version), title.updated_at]
    end
  end

  def title_current_view_name
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
