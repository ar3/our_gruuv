class Organizations::PaperTrailController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_auditable_record

  after_action :verify_authorized

  def show
    # PaperTrail's `item.versions` association orders by `created_at ASC, id ASC`. Chaining
    # `.order(created_at: :desc)` appends, so SQL becomes `... ASC, id ASC, created_at DESC` and
    # rows stay oldest-first; the Fields column then looks "all blank" (empty `object_changes` on
    # the first row, etc.). `reorder` replaces the default order.
    @versions = @auditable.versions.reorder(created_at: :desc, id: :desc).load
    render layout: determine_layout
  end

  private

  ALLOWED_ITEM_TYPES = {
    'Assignment' => Assignment,
    'Ability' => Ability,
    'Aspiration' => Aspiration,
    'Department' => Department,
    'Goal' => Goal,
    'GoalCheckIn' => GoalCheckIn,
    'Observation' => Observation,
    'Organization' => Organization,
    'Position' => Position,
    'Title' => Title
  }.freeze

  def set_auditable_record
    item_type = params[:item_type].to_s
    item_id = params[:item_id]

    klass = ALLOWED_ITEM_TYPES[item_type]
    raise ActiveRecord::RecordNotFound if klass.blank? || item_id.blank?

    @auditable = find_auditable_in_organization(klass, item_id)
    authorize @auditable, :show?
  end

  def find_auditable_in_organization(klass, id)
    org = organization

    scope = case klass.name
            when 'Organization'
              klass.where(id: org.id)
            when 'Assignment', 'Ability', 'Aspiration', 'Department', 'Goal', 'Title'
              klass.where(company_id: org.id)
            when 'Observation'
              klass.where(company_id: org.id)
            when 'Position'
              klass.for_company(org)
            when 'GoalCheckIn'
              klass.joins(:goal).where(goals: { company_id: org.id })
            else
              klass.none
            end

    scope.find(id)
  end
end
