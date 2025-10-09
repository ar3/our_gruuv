# Helper methods for view specs
module ViewHelpers
  def rating_options_for_select(selected_value = nil)
    [
      ['Select rating...', ''],
      ['⭐ Strongly Agree (Exceptional)', 'strongly_agree'],
      ['👍 Agree (Good)', 'agree'],
      ['👁️‍🗨️ N/A', 'na'],
      ['👎 Disagree (Opportunity)', 'disagree'],
      ['⭕ Strongly Disagree (Major Concern)', 'strongly_disagree']
    ]
  end
  
  def current_organization
    @current_organization
  end
  
  def current_person
    @current_person
  end
end

# Include the helper in all view specs
RSpec.configure do |config|
  config.include ViewHelpers, type: :view
end


