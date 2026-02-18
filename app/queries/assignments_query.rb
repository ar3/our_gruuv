class AssignmentsQuery
  attr_reader :organization, :params, :current_person, :policy_scope

  def initialize(organization, params = {}, current_person: nil, policy_scope: nil)
    @organization = organization
    @params = params
    @current_person = current_person
    @policy_scope = policy_scope
  end

  def call
    assignments = base_scope
    assignments = assignments.unarchived unless show_archived?
    assignments = filter_by_organizations(assignments)
    assignments = filter_by_outcomes(assignments)
    assignments = filter_by_abilities(assignments)
    assignments = filter_by_major_version(assignments)
    assignments = apply_sort(assignments)
    assignments
  end

  def current_filters
    filters = {}
    filters[:show_archived] = true if show_archived?
    if params[:departments].present?
      # Handle comma-separated list of department IDs
      department_ids = params[:departments].to_s.split(',').map(&:strip).reject(&:blank?)
      filters[:departments] = department_ids
    end
    filters[:outcomes_filter] = params[:outcomes_filter] if params[:outcomes_filter].present? && params[:outcomes_filter] != 'all'
    filters[:abilities_filter] = params[:abilities_filter] if params[:abilities_filter].present? && params[:abilities_filter] != 'all'
    filters[:major_version] = params[:major_version] if params[:major_version].present?
    filters
  end

  def show_archived?
    params[:show_archived].present? && params[:show_archived].to_s == '1'
  end

  def current_sort
    params[:sort] || 'department_and_title'
  end

  def current_view
    params[:view] || 'table'
  end

  def current_spotlight
    params[:spotlight] || 'by_department'
  end

  def has_active_filters?
    current_filters.any?
  end

  private

  def base_scope
    @base_scope ||= begin
      scope = policy_scope || Assignment.all
      scope.where(company: organization).includes(
        :assignment_outcomes,
        :published_external_reference,
        :draft_external_reference,
        :abilities,
        assignment_abilities: :ability,
        position_assignments: { position: [:title, :position_level] }
      )
    end
  end

  def filter_by_organizations(assignments)
    return assignments unless params[:departments].present?

    # Handle comma-separated list of department IDs
    department_params = params[:departments].to_s.split(',').map(&:strip).reject(&:blank?)
    return assignments if department_params.empty?

    # Check for "none" or empty string to represent no department
    has_none = department_params.include?('none') || department_params.include?('')
    department_ids = department_params.reject { |p| p == 'none' || p == '' }.map(&:to_i).reject(&:zero?)

    conditions = []

    # If "none" is included, add condition for assignments with nil department
    if has_none
      none_condition = assignments.arel_table[:company_id].eq(organization.id)
        .and(assignments.arel_table[:department_id].eq(nil))
      conditions << none_condition
    end

    # If specific department IDs are provided, filter by department_id
    if department_ids.any?
      conditions << assignments.arel_table[:department_id].in(department_ids)
    end

    # Combine conditions with OR
    if conditions.any?
      combined_condition = conditions.reduce(:or)
      assignments.where(combined_condition)
    else
      assignments
    end
  end

  def filter_by_outcomes(assignments)
    case params[:outcomes_filter]
    when 'with'
      assignments.joins(:assignment_outcomes).distinct
    when 'without'
      assignments.left_joins(:assignment_outcomes)
                 .where(assignment_outcomes: { id: nil })
    else
      assignments
    end
  end

  def filter_by_abilities(assignments)
    case params[:abilities_filter]
    when 'with'
      assignments.joins(:assignment_abilities).distinct
    when 'without'
      assignments.left_joins(:assignment_abilities)
                 .where(assignment_abilities: { id: nil })
    else
      assignments
    end
  end

  def filter_by_major_version(assignments)
    return assignments unless params[:major_version].present?

    major_version = params[:major_version].to_i
    assignments.where("semantic_version LIKE ?", "#{major_version}.%")
  end

  def apply_sort(assignments)
    # Check if we're using distinct (from joins)
    using_distinct = assignments.to_sql.include?('DISTINCT')

    case current_sort
    when 'department_and_title'
      if using_distinct
        assignments.reorder('assignments.title')
      else
        assignments.left_joins(:department).order(Arel.sql('COALESCE(departments.name, \'\')'), 'assignments.title')
      end
    when 'title'
      assignments.order('assignments.title')
    when 'title_desc'
      assignments.order('assignments.title DESC')
    when 'company'
      if using_distinct
        assignments.reorder('assignments.title')
      else
        assignments.joins(:company).order('organizations.display_name')
      end
    when 'company_desc'
      if using_distinct
        assignments.reorder('assignments.title DESC')
      else
        assignments.joins(:company).order('organizations.display_name DESC')
      end
    when 'outcomes'
      assignments.left_joins(:assignment_outcomes).group('assignments.id').order('COUNT(assignment_outcomes.id) DESC')
    when 'outcomes_desc'
      assignments.left_joins(:assignment_outcomes).group('assignments.id').order('COUNT(assignment_outcomes.id) ASC')
    when 'abilities'
      assignments.left_joins(:assignment_abilities).group('assignments.id').order('COUNT(assignment_abilities.id) DESC')
    when 'abilities_desc'
      assignments.left_joins(:assignment_abilities).group('assignments.id').order('COUNT(assignment_abilities.id) ASC')
    else
      assignments
    end
  end
end
