class Enm::AssessmentPhase1Form < Reform::Form
  include Reform::Form::ActiveModel::Validations
  
  # Q1: Core Openness
  property :core_openness_same_sex, virtual: true
  property :core_openness_opposite_sex, virtual: true
  
  # Q2: Passive Emotional Openness
  property :passive_emotional_same_sex, virtual: true
  property :passive_emotional_opposite_sex, virtual: true
  
  # Q3: Passive Physical Openness
  property :passive_physical_same_sex, virtual: true
  property :passive_physical_opposite_sex, virtual: true
  
  # Q4: Active Emotional Readiness
  property :active_emotional_same_sex, virtual: true
  property :active_emotional_opposite_sex, virtual: true
  
  # Q5: Active Physical Readiness
  property :active_physical_same_sex, virtual: true
  property :active_physical_opposite_sex, virtual: true
  
  # Validations for all fields
  validates :core_openness_same_sex, presence: true
  validates :core_openness_opposite_sex, presence: true
  validates :passive_emotional_same_sex, presence: true
  validates :passive_emotional_opposite_sex, presence: true
  validates :passive_physical_same_sex, presence: true
  validates :passive_physical_opposite_sex, presence: true
  validates :active_emotional_same_sex, presence: true
  validates :active_emotional_opposite_sex, presence: true
  validates :active_physical_same_sex, presence: true
  validates :active_physical_opposite_sex, presence: true
  
  def phase_1_data
    {
      core_openness: {
        same_sex: core_openness_same_sex.to_i,
        opposite_sex: core_openness_opposite_sex.to_i
      },
      passive_emotional: {
        same_sex: passive_emotional_same_sex.to_i,
        opposite_sex: passive_emotional_opposite_sex.to_i
      },
      passive_physical: {
        same_sex: passive_physical_same_sex.to_i,
        opposite_sex: passive_physical_opposite_sex.to_i
      },
      active_emotional: {
        same_sex: active_emotional_same_sex.to_i,
        opposite_sex: active_emotional_opposite_sex.to_i
      },
      active_physical: {
        same_sex: active_physical_same_sex.to_i,
        opposite_sex: active_physical_opposite_sex.to_i
      }
    }
  end

  def populate_from_existing_data
    return unless model.phase_1_data.present?
    
    existing_data = model.phase_1_data
    
    # Populate core openness
    if existing_data["core_openness"].present?
      self.core_openness_same_sex = existing_data["core_openness"]["same_sex"] if existing_data["core_openness"]["same_sex"].present?
      self.core_openness_opposite_sex = existing_data["core_openness"]["opposite_sex"] if existing_data["core_openness"]["opposite_sex"].present?
    end
    
    # Populate passive emotional
    if existing_data["passive_emotional"].present?
      self.passive_emotional_same_sex = existing_data["passive_emotional"]["same_sex"] if existing_data["passive_emotional"]["same_sex"].present?
      self.passive_emotional_opposite_sex = existing_data["passive_emotional"]["opposite_sex"] if existing_data["passive_emotional"]["opposite_sex"].present?
    end
    
    # Populate passive physical
    if existing_data["passive_physical"].present?
      self.passive_physical_same_sex = existing_data["passive_physical"]["same_sex"] if existing_data["passive_physical"]["same_sex"].present?
      self.passive_physical_opposite_sex = existing_data["passive_physical"]["opposite_sex"] if existing_data["passive_physical"]["opposite_sex"].present?
    end
    
    # Populate active emotional
    if existing_data["active_emotional"].present?
      self.active_emotional_same_sex = existing_data["active_emotional"]["same_sex"] if existing_data["active_emotional"]["same_sex"].present?
      self.active_emotional_opposite_sex = existing_data["active_emotional"]["opposite_sex"] if existing_data["active_emotional"]["opposite_sex"].present?
    end
    
    # Populate active physical
    if existing_data["active_physical"].present?
      self.active_physical_same_sex = existing_data["active_physical"]["same_sex"] if existing_data["active_physical"]["same_sex"].present?
      self.active_physical_opposite_sex = existing_data["active_physical"]["opposite_sex"] if existing_data["active_physical"]["opposite_sex"].present?
    end
  end
