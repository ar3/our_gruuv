class Enm::AssessmentPhase2Form < Reform::Form
  include Reform::Form::ActiveModel::Validations
  
  # Individual fields for emotional escalator (9 steps)
  (1..9).each do |step|
    property "emotional_escalator_#{step}_comfort".to_sym, virtual: true
    validates "emotional_escalator_#{step}_comfort".to_sym, presence: true
  end
  
  def phase_2_data
    {
      emotional_escalator: (1..9).map do |step|
        {
          step: step,
          comfort: send("emotional_escalator_#{step}_comfort").to_i
        }
      end,
      physical_escalator: [],
      style_axes: {}
    }
  end
end
