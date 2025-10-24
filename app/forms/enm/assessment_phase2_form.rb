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

  def populate_from_existing_data
    return unless model.phase_2_data.present?
    
    existing_data = model.phase_2_data
    
    # Populate distant steps
    if existing_data["distant_steps"].present?
      existing_data["distant_steps"].each do |step_data|
        step = step_data["step"]
        send("distant_step_#{step}_comfort_same_sex=", step_data["comfort"]["same_sex"]) if step_data["comfort"]["same_sex"].present?
        send("distant_step_#{step}_comfort_opposite_sex=", step_data["comfort"]["opposite_sex"]) if step_data["comfort"]["opposite_sex"].present?
        send("distant_step_#{step}_pre_disclosure_same_sex=", step_data["pre_disclosure"]["same_sex"]) if step_data["pre_disclosure"]["same_sex"].present?
        send("distant_step_#{step}_pre_disclosure_opposite_sex=", step_data["pre_disclosure"]["opposite_sex"]) if step_data["pre_disclosure"]["opposite_sex"].present?
        send("distant_step_#{step}_post_disclosure_same_sex=", step_data["post_disclosure"]["same_sex"]) if step_data["post_disclosure"]["same_sex"].present?
        send("distant_step_#{step}_post_disclosure_opposite_sex=", step_data["post_disclosure"]["opposite_sex"]) if step_data["post_disclosure"]["opposite_sex"].present?
      end
    end
    
    # Populate physical escalator
    if existing_data["physical_escalator"].present?
      existing_data["physical_escalator"].each do |step_data|
        step = step_data["step"]
        send("physical_step_#{step}_comfort_same_sex=", step_data["comfort"]["same_sex"]) if step_data["comfort"]["same_sex"].present?
        send("physical_step_#{step}_comfort_opposite_sex=", step_data["comfort"]["opposite_sex"]) if step_data["comfort"]["opposite_sex"].present?
        send("physical_step_#{step}_pre_disclosure_same_sex=", step_data["pre_disclosure"]["same_sex"]) if step_data["pre_disclosure"]["same_sex"].present?
        send("physical_step_#{step}_pre_disclosure_opposite_sex=", step_data["pre_disclosure"]["opposite_sex"]) if step_data["pre_disclosure"]["opposite_sex"].present?
        send("physical_step_#{step}_post_disclosure_same_sex=", step_data["post_disclosure"]["same_sex"]) if step_data["post_disclosure"]["same_sex"].present?
        send("physical_step_#{step}_post_disclosure_opposite_sex=", step_data["post_disclosure"]["opposite_sex"]) if step_data["post_disclosure"]["opposite_sex"].present?
      end
    end
    
    # Populate emotional escalator
    if existing_data["emotional_escalator"].present?
      existing_data["emotional_escalator"].each do |step_data|
        step = step_data["step"]
        send("emotional_step_#{step}_comfort_same_sex=", step_data["comfort"]["same_sex"]) if step_data["comfort"]["same_sex"].present?
        send("emotional_step_#{step}_comfort_opposite_sex=", step_data["comfort"]["opposite_sex"]) if step_data["comfort"]["opposite_sex"].present?
        send("emotional_step_#{step}_pre_disclosure_same_sex=", step_data["pre_disclosure"]["same_sex"]) if step_data["pre_disclosure"]["same_sex"].present?
        send("emotional_step_#{step}_pre_disclosure_opposite_sex=", step_data["pre_disclosure"]["opposite_sex"]) if step_data["pre_disclosure"]["opposite_sex"].present?
        send("emotional_step_#{step}_post_disclosure_same_sex=", step_data["post_disclosure"]["same_sex"]) if step_data["post_disclosure"]["same_sex"].present?
        send("emotional_step_#{step}_post_disclosure_opposite_sex=", step_data["post_disclosure"]["opposite_sex"]) if step_data["post_disclosure"]["opposite_sex"].present?
      end
    end
  end
end