module TitlesHelper
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
