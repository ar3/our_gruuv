class Enm::AssessmentPhase3Form < Reform::Form
  include Reform::Form::ActiveModel::Validations
  
  # Phase 3 is just confirmation - no additional input required
  def phase_3_data
    {
      confirmed: true
    }
  end
end




