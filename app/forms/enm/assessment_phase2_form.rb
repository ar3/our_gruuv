class Enm::AssessmentPhase2Form < Reform::Form
  include Reform::Form::ActiveModel::Validations
  
  # Distant Steps (1-3) - Used for both Physical and Emotional
  # Each step has: comfort_same_sex, comfort_opposite_sex, pre_disclosure_same_sex, pre_disclosure_opposite_sex, post_disclosure_same_sex, post_disclosure_opposite_sex
  (1..3).each do |step|
    property "distant_step_#{step}_comfort_same_sex".to_sym, virtual: true
    property "distant_step_#{step}_comfort_opposite_sex".to_sym, virtual: true
    property "distant_step_#{step}_pre_disclosure_same_sex".to_sym, virtual: true
    property "distant_step_#{step}_pre_disclosure_opposite_sex".to_sym, virtual: true
    property "distant_step_#{step}_post_disclosure_same_sex".to_sym, virtual: true
    property "distant_step_#{step}_post_disclosure_opposite_sex".to_sym, virtual: true
  end
  
  # Physical Escalator Steps (4-9)
  (4..9).each do |step|
    property "physical_step_#{step}_comfort_same_sex".to_sym, virtual: true
    property "physical_step_#{step}_comfort_opposite_sex".to_sym, virtual: true
    property "physical_step_#{step}_pre_disclosure_same_sex".to_sym, virtual: true
    property "physical_step_#{step}_pre_disclosure_opposite_sex".to_sym, virtual: true
    property "physical_step_#{step}_post_disclosure_same_sex".to_sym, virtual: true
    property "physical_step_#{step}_post_disclosure_opposite_sex".to_sym, virtual: true
  end
  
  # Emotional Escalator Steps (4-9)
  (4..9).each do |step|
    property "emotional_step_#{step}_comfort_same_sex".to_sym, virtual: true
    property "emotional_step_#{step}_comfort_opposite_sex".to_sym, virtual: true
    property "emotional_step_#{step}_pre_disclosure_same_sex".to_sym, virtual: true
    property "emotional_step_#{step}_pre_disclosure_opposite_sex".to_sym, virtual: true
    property "emotional_step_#{step}_post_disclosure_same_sex".to_sym, virtual: true
    property "emotional_step_#{step}_post_disclosure_opposite_sex".to_sym, virtual: true
  end
  
  # Validations for all fields
  (1..3).each do |step|
    validates "distant_step_#{step}_comfort_same_sex".to_sym, presence: true
    validates "distant_step_#{step}_comfort_opposite_sex".to_sym, presence: true
    validates "distant_step_#{step}_pre_disclosure_same_sex".to_sym, presence: true
    validates "distant_step_#{step}_pre_disclosure_opposite_sex".to_sym, presence: true
    validates "distant_step_#{step}_post_disclosure_same_sex".to_sym, presence: true
    validates "distant_step_#{step}_post_disclosure_opposite_sex".to_sym, presence: true
  end
  
  (4..9).each do |step|
    validates "physical_step_#{step}_comfort_same_sex".to_sym, presence: true
    validates "physical_step_#{step}_comfort_opposite_sex".to_sym, presence: true
    validates "physical_step_#{step}_pre_disclosure_same_sex".to_sym, presence: true
    validates "physical_step_#{step}_pre_disclosure_opposite_sex".to_sym, presence: true
    validates "physical_step_#{step}_post_disclosure_same_sex".to_sym, presence: true
    validates "physical_step_#{step}_post_disclosure_opposite_sex".to_sym, presence: true
    
    validates "emotional_step_#{step}_comfort_same_sex".to_sym, presence: true
    validates "emotional_step_#{step}_comfort_opposite_sex".to_sym, presence: true
    validates "emotional_step_#{step}_pre_disclosure_same_sex".to_sym, presence: true
    validates "emotional_step_#{step}_pre_disclosure_opposite_sex".to_sym, presence: true
    validates "emotional_step_#{step}_post_disclosure_same_sex".to_sym, presence: true
    validates "emotional_step_#{step}_post_disclosure_opposite_sex".to_sym, presence: true
  end
  
  def phase_2_data
    {
      distant_steps: (1..3).map do |step|
        {
          step: step,
          comfort: {
            same_sex: send("distant_step_#{step}_comfort_same_sex").to_i,
            opposite_sex: send("distant_step_#{step}_comfort_opposite_sex").to_i
          },
          pre_disclosure: {
            same_sex: send("distant_step_#{step}_pre_disclosure_same_sex"),
            opposite_sex: send("distant_step_#{step}_pre_disclosure_opposite_sex")
          },
          post_disclosure: {
            same_sex: send("distant_step_#{step}_post_disclosure_same_sex"),
            opposite_sex: send("distant_step_#{step}_post_disclosure_opposite_sex")
          }
        }
      end,
      physical_escalator: (4..9).map do |step|
        {
          step: step,
          comfort: {
            same_sex: send("physical_step_#{step}_comfort_same_sex").to_i,
            opposite_sex: send("physical_step_#{step}_comfort_opposite_sex").to_i
          },
          pre_disclosure: {
            same_sex: send("physical_step_#{step}_pre_disclosure_same_sex"),
            opposite_sex: send("physical_step_#{step}_pre_disclosure_opposite_sex")
          },
          post_disclosure: {
            same_sex: send("physical_step_#{step}_post_disclosure_same_sex"),
            opposite_sex: send("physical_step_#{step}_post_disclosure_opposite_sex")
          }
        }
      end,
      emotional_escalator: (4..9).map do |step|
        {
          step: step,
          comfort: {
            same_sex: send("emotional_step_#{step}_comfort_same_sex").to_i,
            opposite_sex: send("emotional_step_#{step}_comfort_opposite_sex").to_i
          },
          pre_disclosure: {
            same_sex: send("emotional_step_#{step}_pre_disclosure_same_sex"),
            opposite_sex: send("emotional_step_#{step}_pre_disclosure_opposite_sex")
          },
          post_disclosure: {
            same_sex: send("emotional_step_#{step}_post_disclosure_same_sex"),
            opposite_sex: send("emotional_step_#{step}_post_disclosure_opposite_sex")
          }
        }
      end
    }
  end
end