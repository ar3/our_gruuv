class Enm::AssessmentPhase1Form < Reform::Form
  include Reform::Form::ActiveModel::Validations
  
  # Individual fields for the form
  property :core_openness_same_sex, virtual: true
  property :core_openness_opposite_sex, virtual: true
  property :passive_openness_emotional, virtual: true
  property :passive_openness_physical, virtual: true
  property :active_readiness_emotional, virtual: true
  property :active_readiness_physical, virtual: true
  
  validates :core_openness_same_sex, presence: true
  validates :core_openness_opposite_sex, presence: true
  validates :passive_openness_emotional, presence: true
  validates :passive_openness_physical, presence: true
  validates :active_readiness_emotional, presence: true
  validates :active_readiness_physical, presence: true
  
  def phase_1_data
    {
      core_openness: {
        same_sex: core_openness_same_sex.to_i,
        opposite_sex: core_openness_opposite_sex.to_i
      },
      passive_openness: {
        emotional: passive_openness_emotional.to_i,
        physical: passive_openness_physical.to_i
      },
      active_readiness: {
        emotional: active_readiness_emotional.to_i,
        physical: active_readiness_physical.to_i
      }
    }
  end
end
