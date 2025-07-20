module HuddlesHelper
  def role_options_for_select(selected_role = nil)
    options = HuddleConstants::ROLES.map do |role|
      [HuddleConstants::ROLE_LABELS[role], role]
    end
    
    if selected_role
      options_for_select(options, selected_role)
    else
      options_for_select(options, prompt: 'Select your role...')
    end
  end
end
