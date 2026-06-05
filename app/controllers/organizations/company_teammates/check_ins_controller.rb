class Organizations::CompanyTeammates::CheckInsController < Organizations::OrganizationNamespaceBaseController
  # Non-active, non-required assignments added within this many days show outside "Unique-to-You"
  RECENTLY_ADDED_DAYS = 7

  include Organizations::AssignsViewableTeammates

  helper EmployeesHelper
  helper AssignmentEnergyAllocationHelper

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :determine_view_mode

  def show
    # Initialize assigns before authorization to prevent nil errors on redirect
    @relevant_abilities = []
    
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    assign_viewable_teammates_context!(selected_teammate: @teammate)

    # Create debug data if debug parameter is present
    if params[:debug] == 'true'
      debug_service = Debug::CheckInsDebugService.new(
        pundit_user: pundit_user,
        person: @teammate.person
      )
      @debug_data = debug_service.call
    end
    
    # Load or build all check-in types (spreadsheet-style)
    @position_check_in = load_or_build_position_check_in
    preload_position_check_in_associations! if @position_check_in
    assignment_check_ins_data = load_or_build_assignment_check_ins
    @active_assignment_check_ins = assignment_check_ins_data[:active_tenure_check_ins]
    @recently_added_assignment_check_ins = assignment_check_ins_data[:recently_added_tenure_check_ins]
    @non_active_assignment_check_ins = assignment_check_ins_data[:non_active_tenure_check_ins]
    # Keep @assignment_check_ins for backward compatibility (combined list)
    @assignment_check_ins = @active_assignment_check_ins + @recently_added_assignment_check_ins + @non_active_assignment_check_ins
    preload_assignment_check_in_associations!
    @aspiration_check_ins = load_or_build_aspiration_check_ins
    preload_aspiration_check_in_associations!
    @relevant_abilities = load_relevant_abilities || []
    @ability_goal_counts_by_id = ability_goal_counts_by_id_for(@relevant_abilities)
    @active_required_assignment_check_ins = filter_active_required_assignment_check_ins
    @check_ins_fresh_banner = CheckIns::AllFreshBannerService.call(
      teammate: @teammate,
      organization: organization,
      view_mode: @view_mode,
      position_check_in: @position_check_in,
      aspiration_check_ins: @aspiration_check_ins,
      assignment_check_ins: @active_required_assignment_check_ins
    )

    if @view_mode == :employee
      @assignment_energy_allocation = CheckIns::AssignmentEnergyAllocationSummary.for_bulk_check_in(
        teammate: @teammate,
        reflection_check_ins: @assignment_check_ins,
        organization: organization
      )
    end
  end

  def review_most_recent
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy

    @person = @teammate.person
    @_review_most_recent_history_loads = []
    timings = {}
    total_ms = Benchmark.ms do
      timings[:viewable_teammates_ms] = Benchmark.ms do
        assign_viewable_teammates_context!(selected_teammate: @teammate)
      end

      timings[:position_check_in_ms] = Benchmark.ms do
        @position_check_in = PositionCheckIn
          .where(company_teammate: @teammate)
          .includes({ manager_completed_by_teammate: :person }, employment_tenure: :position)
          .order(check_in_started_on: :desc, created_at: :desc)
          .first
      end

      timings[:assignment_rows_ms] = Benchmark.ms { @assignment_rows = build_assignment_rows }
      timings[:aspiration_rows_ms] = Benchmark.ms { @aspiration_rows = build_aspiration_rows }

      timings[:position_history_ms] = Benchmark.ms { @position_history = build_position_history }
      timings[:assignment_histories_ms] = Benchmark.ms do
        @assignment_histories = build_assignment_histories(@assignment_rows.map { |row| row[:assignment_id] })
      end
      timings[:aspiration_histories_ms] = Benchmark.ms do
        @aspiration_histories = build_aspiration_histories(@aspiration_rows.map { |row| row[:aspiration_id] })
      end
    end

    log_review_most_recent_profile(
      total_ms: total_ms,
      timings: timings,
      assignment_row_count: @assignment_rows.size,
      aspiration_row_count: @aspiration_rows.size,
      assignment_history_bucket_count: @assignment_histories.size,
      aspiration_history_bucket_count: @aspiration_histories.size,
      history_loads: @_review_most_recent_history_loads
    )
  end

  def hub
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy

    @person = @teammate.person
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @employee_name = @teammate.person.casual_name.presence || "Employee"
    @manager_name = @teammate.current_manager&.casual_name.presence || "Manager"

    @ready_for_review_count =
      PositionCheckIn.where(company_teammate: @teammate).ready_for_finalization.count +
      AssignmentCheckIn.where(company_teammate: @teammate).ready_for_finalization.count +
      AspirationCheckIn.where(company_teammate: @teammate).ready_for_finalization.count

    snapshots_scope = MaapSnapshot.for_employee_teammate(@teammate)
      .for_company(organization)
      .where.not(effective_date: nil)
    @snapshot_total_count = snapshots_scope.count
    @snapshot_unacknowledged_count = snapshots_scope.where(employee_acknowledged_at: nil).count
    @check_in_health_cache = CheckInHealthCache.find_by(teammate: @teammate, organization: organization)

    next_result = CheckIns::SingleItemCheckInNextItemService.call(
      teammate: @teammate,
      organization: organization,
      current_person: current_person,
      current_type: :position,
      current_id: nil
    )
    @next_item_candidate = next_result[:ordered_items]&.first

    if next_result[:next_requires_check_in]
      @next_up_requires_check_in = true
      @next_up_label = next_result.dig(:next_item, :name).presence || @next_item_candidate&.dig(:name).presence || 'your top check-in'
      @next_up_url = next_result[:next_url].presence || organization_company_teammate_check_ins_path(organization, @teammate)
    elsif @next_item_candidate.present?
      @next_up_requires_check_in = false
      @next_up_label = @next_item_candidate[:name]
      @next_up_url = check_in_hub_item_url(@next_item_candidate)
    else
      @next_up_requires_check_in = false
      @next_up_label = 'your top check-in'
      @next_up_url = organization_company_teammate_check_ins_path(organization, @teammate)
    end
  end

  def up_next
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy

    @person = @teammate.person
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @up_next_page_title = "Clarity Check-ins... Up Next"

    @employee_perspective_person = @teammate.person
    @manager_perspective_person = @teammate.current_manager || current_person
    @employee_name = @teammate.person.casual_name.presence || "Employee"
    @manager_name = @teammate.current_manager&.casual_name.presence || "Manager"
    @up_next_required_assignment_ids = required_assignment_ids_for_teammate.to_set
    @up_next_active_tenure_assignment_ids = active_assignment_ids_for_teammate.to_set

    @employee_up_next_items = build_up_next_explainer_items_for(@employee_perspective_person)
    @manager_up_next_items = build_up_next_explainer_items_for(@manager_perspective_person)
    assign_up_next_actions_spotlight!
  end
  
  def update
    perform_check_in_update
    respond_to_check_in_update
  end

  def save_and_redirect
    perform_check_in_update
    respond_to_check_in_update
  end
  
  private

  def perform_check_in_update
    @check_in_errors = []
    check_ins_params = params[:check_ins] || params
    apply_single_item_status_override!

    update_position_check_in(check_ins_params) if check_ins_params[:position_check_in] || check_ins_params["[position_check_in]"]
    update_assignment_check_ins(check_ins_params) if check_ins_params[:assignment_check_ins] || check_ins_params["[assignment_check_ins]"]
    update_aspiration_check_ins(check_ins_params) if check_ins_params[:aspiration_check_ins] || check_ins_params["[aspiration_check_ins]"]
  end

  def respond_to_check_in_update
    respond_to do |format|
      format.html do
        redirect_url = determine_redirect_url
        if @check_in_errors.any?
          redirect_to redirect_url, alert: check_in_errors_flash_message
        else
          CheckInHealthCacheRefreshSchedule.schedule_refresh_for(@teammate.id)
          redirect_to redirect_url, notice: 'Check-ins saved successfully.'
        end
      end
      format.json do
        if @check_in_errors.any?
          render json: { ok: false, errors: @check_in_errors }, status: :unprocessable_entity
        else
          CheckInHealthCacheRefreshSchedule.schedule_refresh_for(@teammate.id)
          render json: { ok: true, saved_at: Time.current.iso8601 }
        end
      end
    end
  end
  
  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id], scope: organization.teammates.includes(:person))
  end
  
  def determine_view_mode
    Rails.logger.debug "=== VIEW MODE DETERMINATION ==="
    Rails.logger.debug "current_person: #{current_person&.display_name} (#{current_person&.id})"
    Rails.logger.debug "@teammate.person: #{@teammate.person&.display_name} (#{@teammate.person&.id})"
    Rails.logger.debug "current_person == @teammate.person: #{current_person == @teammate.person}"
    current_manager = @teammate.current_manager
    Rails.logger.debug "current_manager: #{current_manager&.display_name} (#{current_manager&.id})"
    Rails.logger.debug "current_manager == current_person: #{current_manager == current_person}"
    
    if current_person == @teammate.person
      @view_mode = :employee
      Rails.logger.debug "Setting view_mode to :employee"
    else
      # All non-employee viewers (including non-direct-managers) behave as managers
      @view_mode = :manager
      Rails.logger.debug "Setting view_mode to :manager"
    end
    Rails.logger.debug "Final view_mode: #{@view_mode}"
    Rails.logger.debug "=== END DEBUG ===\n"
  end

  def build_position_history
    includes_hash = [ :manager_completed_by_teammate, { employment_tenure: :position } ]
    scope = PositionCheckIn.where(company_teammate: @teammate)

    latest_finalized = scope
      .where.not(official_check_in_completed_at: nil)
      .includes(*includes_hash)
      .order(official_check_in_completed_at: :desc, created_at: :desc)
      .first

    open_check_in = scope
      .where(official_check_in_completed_at: nil)
      .includes(*includes_hash)
      .order(check_in_started_on: :desc, created_at: :desc)
      .first

    {
      sentence_type: :position,
      latest_finalized: latest_finalized,
      open_check_in: open_check_in
    }
  end

  def build_assignment_rows
    active_tenures = AssignmentTenure
      .joins(:assignment)
      .where(company_teammate: @teammate, ended_at: nil)
      .where(assignments: { company: organization.self_and_descendants })
      .includes(:assignment)

    assignment_ids = active_tenures.map(&:assignment_id).uniq
    assignment_tenure_by_id = active_tenures.index_by(&:assignment_id)

    active_employment = @teammate.employment_tenures.active.where(company: organization).first
    if active_employment&.position
      assignment_ids |= active_employment.position.required_assignments.pluck(:assignment_id)
      assignment_ids |= active_employment.position.suggested_assignments.pluck(:assignment_id)
    end

    assignment_ids |= AssignmentCheckIn
      .joins(:assignment)
      .where(company_teammate: @teammate, assignments: { company: organization.self_and_descendants })
      .distinct
      .pluck(:assignment_id)

    assignments_by_id = Assignment.where(id: assignment_ids).index_by(&:id)

    assignment_ids.filter_map do |assignment_id|
      assignment = assignments_by_id[assignment_id]
      next unless assignment

      {
        assignment_id: assignment_id,
        assignment: assignment,
        assignment_tenure: assignment_tenure_by_id[assignment_id]
      }
    end
  end

  def build_aspiration_rows
    Aspiration.within_hierarchy(organization).ordered.map do |aspiration|
      { aspiration_id: aspiration.id, aspiration: aspiration }
    end
  end

  def build_assignment_histories(assignment_ids)
    assignment_ids = assignment_ids.compact.uniq
    return {} if assignment_ids.empty?

    includes_hash = [ :assignment, { manager_completed_by_teammate: :person }, { company_teammate: :person } ]
    base_scope = AssignmentCheckIn.where(company_teammate: @teammate, assignment_id: assignment_ids)

    latest_finalized_rows = base_scope
      .where.not(official_check_in_completed_at: nil)
      .includes(*includes_hash)
      .order(official_check_in_completed_at: :desc, created_at: :desc)
      .to_a

    latest_open_rows = base_scope
      .where(official_check_in_completed_at: nil)
      .includes(*includes_hash)
      .order(check_in_started_on: :desc, created_at: :desc)
      .to_a

    finalized_by_assignment = latest_finalized_rows.uniq { |row| row.assignment_id }.index_by(&:assignment_id)
    open_by_assignment = latest_open_rows.uniq { |row| row.assignment_id }.index_by(&:assignment_id)

    assignment_ids.each_with_object({}) do |assignment_id, memo|
      memo[assignment_id] = {
        sentence_type: :assignment,
        latest_finalized: finalized_by_assignment[assignment_id],
        open_check_in: open_by_assignment[assignment_id]
      }
    end
  end

  def build_aspiration_histories(aspiration_ids)
    aspiration_ids = aspiration_ids.compact.uniq
    return {} if aspiration_ids.empty?

    includes_hash = [ :aspiration, { manager_completed_by_teammate: :person }, { company_teammate: :person } ]
    base_scope = AspirationCheckIn.where(company_teammate: @teammate, aspiration_id: aspiration_ids)

    latest_finalized_rows = base_scope
      .where.not(official_check_in_completed_at: nil)
      .includes(*includes_hash)
      .order(official_check_in_completed_at: :desc, created_at: :desc)
      .to_a

    latest_open_rows = base_scope
      .where(official_check_in_completed_at: nil)
      .includes(*includes_hash)
      .order(check_in_started_on: :desc, created_at: :desc)
      .to_a

    finalized_by_aspiration = latest_finalized_rows.uniq { |row| row.aspiration_id }.index_by(&:aspiration_id)
    open_by_aspiration = latest_open_rows.uniq { |row| row.aspiration_id }.index_by(&:aspiration_id)

    aspiration_ids.each_with_object({}) do |aspiration_id, memo|
      memo[aspiration_id] = {
        sentence_type: :aspiration,
        latest_finalized: finalized_by_aspiration[aspiration_id],
        open_check_in: open_by_aspiration[aspiration_id]
      }
    end
  end

  def build_history_summary(scope:, sentence_type:, latest_finalized:)
    latest_employee = scope.where.not(employee_completed_at: nil).order(employee_completed_at: :desc).first
    latest_employee_with_manager = scope.where.not(employee_completed_at: nil).where.not(manager_completed_at: nil).order(employee_completed_at: :desc).first

    latest_manager = scope.where.not(manager_completed_at: nil).order(manager_completed_at: :desc).first
    latest_manager_with_employee = scope.where.not(manager_completed_at: nil).where.not(employee_completed_at: nil).order(manager_completed_at: :desc).first

    {
      sentence_type: sentence_type,
      latest_finalized: latest_finalized,
      latest_employee_with_manager: latest_employee_with_manager,
      latest_manager_with_employee: latest_manager_with_employee,
      employee_waiting_on_manager: waiting_message_for_employee_side(latest_employee),
      manager_waiting_on_employee: waiting_message_for_manager_side(latest_manager)
    }
  end

  def load_recent_then_fallback_history(model:, foreign_key:, ids:, includes_hash:)
    recent_cutoff = 1.year.ago
    completion_condition = "employee_completed_at IS NOT NULL OR manager_completed_at IS NOT NULL OR official_check_in_completed_at IS NOT NULL"
    recent_window_condition = "(employee_completed_at >= :cutoff OR manager_completed_at >= :cutoff OR official_check_in_completed_at >= :cutoff)"

    recent_rows = []
    recent_ms = Benchmark.ms do
      recent_rows = model
        .where(company_teammate: @teammate, foreign_key => ids)
        .where(completion_condition)
        .where(recent_window_condition, cutoff: recent_cutoff)
        .includes(*includes_hash)
        .to_a
    end

    recent_by_id = recent_rows.group_by { |row| row.public_send(foreign_key) }
    missing_ids = ids - recent_by_id.keys

    fallback_ms = 0.0
    fallback_rows = []
    if missing_ids.any?
      fallback_ms = Benchmark.ms do
        fallback_rows = model
          .where(company_teammate: @teammate, foreign_key => missing_ids)
          .where(completion_condition)
          .includes(*includes_hash)
          .to_a
      end
    end

    if @_review_most_recent_history_loads
      @_review_most_recent_history_loads << {
        model: model.name,
        foreign_key: foreign_key,
        ids_requested: ids.size,
        recent_ms: recent_ms.round(2),
        recent_rows: recent_rows.size,
        missing_ids_for_fallback: missing_ids.size,
        fallback_ms: fallback_ms.round(2),
        fallback_rows: fallback_rows.size,
        combined_rows: recent_rows.size + fallback_rows.size
      }
    end

    recent_rows + fallback_rows
  end

  def log_review_most_recent_profile(total_ms:, timings:, assignment_row_count:, aspiration_row_count:,
    assignment_history_bucket_count:, aspiration_history_bucket_count:, history_loads:)
    payload = {
      event: "review_most_recent",
      organization_id: organization.id,
      teammate_id: @teammate.id,
      viewable_teammate_count: @viewable_teammates.size,
      total_ms: total_ms.round(2),
      timings_ms: timings.transform_values { |v| v.round(2) },
      assignment_row_count: assignment_row_count,
      aspiration_row_count: aspiration_row_count,
      assignment_history_bucket_count: assignment_history_bucket_count,
      aspiration_history_bucket_count: aspiration_history_bucket_count,
      history_loads: history_loads
    }
    Rails.logger.info(payload.to_json)
  rescue StandardError => e
    Rails.logger.warn("[review_most_recent] failed to log profile: #{e.class}: #{e.message}")
  end

  def waiting_message_for_employee_side(latest_employee)
    return nil if latest_employee.blank? || latest_employee.manager_completed_at.present?

    {
      actor_name: @teammate.person.casual_name,
      waiting_for_name: @teammate.current_manager&.casual_name.presence || 'their manager',
      completed_at: latest_employee.employee_completed_at
    }
  end

  def waiting_message_for_manager_side(latest_manager)
    return nil if latest_manager.blank? || latest_manager.employee_completed_at.present?

    {
      actor_name: @teammate.current_manager&.casual_name.presence || 'Manager',
      waiting_for_name: @teammate.person.casual_name,
      completed_at: latest_manager.manager_completed_at
    }
  end

  def load_or_build_position_check_in
    check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    check_in&.reload  # Ensure we have fresh data from the database
    check_in
  end

  def load_or_build_assignment_check_ins
    check_ins = []
    
    # Get all active assignment tenures for this teammate
    active_tenures = AssignmentTenure.joins(:assignment)
                                    .where(company_teammate: @teammate)
                                    .where(ended_at: nil)
                                    .includes(:assignment)
    
    # Find or create check-ins for each active assignment tenure
    active_tenures.each do |tenure|
      check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, tenure.assignment)
      check_ins << check_in if check_in
    end
    
    # Get required and suggested assignments from the teammate's current position
    active_employment = @teammate.employment_tenures.active.where(company: organization).first
    if active_employment&.position
      position = active_employment.position
      required_assignments = position.required_assignments.map(&:assignment)
      suggested_assignments = position.suggested_assignments.map(&:assignment)
      position_assignments = required_assignments + suggested_assignments
      
      # Batch load open check-ins for position assignments we don't have yet (avoid N+1)
      position_assignment_ids = position_assignments.map(&:id).uniq
      existing_from_tenures = check_ins.map(&:assignment_id).to_set
      position_ids_needing_check_in = position_assignment_ids.reject { |aid| existing_from_tenures.include?(aid) }
      open_for_position = if position_ids_needing_check_in.any?
        AssignmentCheckIn
          .where(company_teammate: @teammate, assignment_id: position_ids_needing_check_in)
          .open
          .index_by(&:assignment_id)
      else
        {}
      end

      # For each position assignment (required or suggested), ensure we have a check-in
      position_assignments.each do |assignment|
        existing_check_in = check_ins.find { |ci| ci.assignment_id == assignment.id }
        next if existing_check_in

        active_tenure = active_tenures.find { |t| t.assignment_id == assignment.id }

        if active_tenure
          check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
          check_ins << check_in if check_in
        else
          open_check_in = open_for_position[assignment.id]
          if open_check_in.nil?
            check_in = AssignmentCheckIn.create!(
              teammate: @teammate,
              assignment: assignment,
              check_in_started_on: Date.current,
              actual_energy_percentage: nil
            )
            check_ins << check_in
          else
            check_ins << open_check_in
          end
        end
      end
    end
    
    check_ins = check_ins.compact
    
    # Also include assignments that have ever had a check-in (even if no active tenure or position assignment)
    # This ensures we show all assignments with check-in history
    assignments_with_check_in_history = AssignmentCheckIn
      .where(company_teammate: @teammate)
      .joins(:assignment)
      .where(assignments: { company: organization.self_and_descendants })
      .select(:assignment_id)
      .distinct
      .pluck(:assignment_id)

    # Batch load open check-ins for missing assignments to avoid N+1
    existing_assignment_ids = check_ins.map(&:assignment_id).to_set
    missing_history_ids = assignments_with_check_in_history.reject { |id| existing_assignment_ids.include?(id) }
    open_check_ins_by_assignment = if missing_history_ids.any?
      AssignmentCheckIn
        .where(company_teammate: @teammate, assignment_id: missing_history_ids)
        .open
        .index_by(&:assignment_id)
    else
      {}
    end

    missing_history_ids.each do |assignment_id|
      open_check_in = open_check_ins_by_assignment[assignment_id]
      if open_check_in.nil?
        assignment = Assignment.find(assignment_id)
        check_in = AssignmentCheckIn.create!(
          teammate: @teammate,
          assignment: assignment,
          check_in_started_on: Date.current,
          actual_energy_percentage: nil
        )
        check_ins << check_in
      else
        check_ins << open_check_in
      end
    end

    check_ins = check_ins.compact

    # Separate check-ins into active tenure and non-active tenure groups (use active_tenures to avoid N+1 assignment_tenure calls)
    active_tenure_assignment_ids = active_tenures.map(&:assignment_id).to_set
    active_tenure_check_ins = []
    non_active_tenure_check_ins = []

    check_ins.each do |check_in|
      if active_tenure_assignment_ids.include?(check_in.assignment_id)
        active_tenure_check_ins << check_in
      else
        non_active_tenure_check_ins << check_in
      end
    end

    # Set @assignment_tenure on each check_in so partition (assignment_added_on) and sort don't N+1
    all_assignment_ids = check_ins.map(&:assignment_id).uniq.compact
    if all_assignment_ids.any?
      tenures = AssignmentTenure
        .where(company_teammate: @teammate, assignment_id: all_assignment_ids)
        .order(Arel.sql("CASE WHEN ended_at IS NULL THEN 0 ELSE 1 END"), started_at: :desc)
      tenures_by_assignment = tenures.group_by(&:assignment_id).transform_values(&:first)
      check_ins.each { |ci| ci.instance_variable_set(:@assignment_tenure, tenures_by_assignment[ci.assignment_id]) }
    end

    required_assignment_ids = required_assignment_ids_for_teammate

    # Promote to Group 1 (active list): required for position, or has meaningful input on the open check-in
    to_promote, non_active_tenure_check_ins = non_active_tenure_check_ins.partition do |check_in|
      required_assignment_ids.include?(check_in.assignment_id) || check_in.has_meaningful_input?
    end
    active_tenure_check_ins.concat(to_promote)

    # Partition remaining non-active: recently added (outside Unique-to-You) vs older (inside Unique-to-You)
    recently_added_cutoff = RECENTLY_ADDED_DAYS.days.ago.to_date
    recently_added_tenure_check_ins = []
    unique_to_you_tenure_check_ins = []

    non_active_tenure_check_ins.each do |check_in|
      added_on = check_in.assignment_added_on
      is_required = required_assignment_ids.include?(check_in.assignment_id)
      is_recently_added = added_on && added_on >= recently_added_cutoff && !is_required

      if is_recently_added
        recently_added_tenure_check_ins << check_in
      else
        unique_to_you_tenure_check_ins << check_in
      end
    end

    # Sort active tenure check-ins by anticipated_energy_percentage (descending, largest first)
    # Place nil values at the end
    active_tenure_check_ins.sort_by! do |check_in|
      energy = check_in.assignment_tenure&.anticipated_energy_percentage
      # Use -1 * energy for descending order, but handle nil by using a very large number
      # so nil values sort to the end
      energy.nil? ? [1, 0] : [0, -energy]
    end

    # Return active, recently added (outside Unique-to-You), and Unique-to-You only
    {
      active_tenure_check_ins: active_tenure_check_ins,
      recently_added_tenure_check_ins: recently_added_tenure_check_ins,
      non_active_tenure_check_ins: unique_to_you_tenure_check_ins
    }
  end

  def required_assignment_ids_for_teammate
    active_employment = @teammate.employment_tenures.active.where(company: organization).first
    return [] unless active_employment&.position

    active_employment.position.required_assignments.pluck(:assignment_id)
  end

  def filter_active_required_assignment_check_ins
    required_ids = required_assignment_ids_for_teammate.to_set
    return [] if required_ids.empty?

    active_assignment_ids = AssignmentTenure
      .where(company_teammate: @teammate, ended_at: nil)
      .pluck(:assignment_id)
      .to_set

    @active_assignment_check_ins.select do |ci|
      required_ids.include?(ci.assignment_id) && active_assignment_ids.include?(ci.assignment_id)
    end
  end

  def load_or_build_aspiration_check_ins
    aspirations = Aspiration.within_hierarchy(organization).ordered
    return [] if aspirations.blank?

    # Batch load open aspiration check-ins for this teammate to avoid N+1
    aspiration_ids = aspirations.map(&:id)
    open_by_aspiration = AspirationCheckIn
      .where(company_teammate: @teammate, aspiration_id: aspiration_ids)
      .open
      .index_by(&:aspiration_id)

    aspirations.filter_map do |aspiration|
      open_check_in = open_by_aspiration[aspiration.id]
      if open_check_in
        open_check_in
      else
        AspirationCheckIn.create!(
          company_teammate: @teammate,
          aspiration: aspiration,
          check_in_started_on: Date.current
        )
      end
    end
  end

  def load_relevant_abilities
    RelevantAbilitiesQuery.new(teammate: @teammate, organization: organization).call
  end

  def ability_goal_counts_by_id_for(relevant_abilities)
    ability_ids = relevant_abilities.map { |data| data[:ability].id }
    CheckIns::AbilityGoalCountsById.call(teammate: @teammate, ability_ids: ability_ids)
  end

  def preload_position_check_in_associations!
    return unless @position_check_in
    ActiveRecord::Associations::Preloader.new(
      records: [ @position_check_in ],
      associations: [ { company_teammate: :person }, { employment_tenure: [ :position, { company_teammate: :person } ] } ]
    ).call
  end

  def preload_aspiration_check_in_associations!
    return if @aspiration_check_ins.blank?
    ActiveRecord::Associations::Preloader.new(
      records: @aspiration_check_ins,
      associations: [
        { company_teammate: :person },
        :aspiration,
        { manager_completed_by_teammate: :person }
      ]
    ).call
  end

  # Preload teammate, assignment, and assignment_tenure to avoid N+1 in check_ins#show views.
  def preload_assignment_check_in_associations!
    check_ins = @assignment_check_ins
    return if check_ins.blank?

    ActiveRecord::Associations::Preloader.new(
      records: check_ins,
      associations: [ { company_teammate: :person }, :assignment ]
    ).call

    assignment_ids = check_ins.map(&:assignment_id).uniq.compact
    return if assignment_ids.blank?

    # Batch load assignment tenures (active first, else most recent per assignment) and attach to each check_in.
    tenures = AssignmentTenure
      .where(company_teammate: @teammate, assignment_id: assignment_ids)
      .order(Arel.sql("CASE WHEN ended_at IS NULL THEN 0 ELSE 1 END"), started_at: :desc)
    tenures_by_assignment = tenures.group_by(&:assignment_id).transform_values(&:first)
    check_ins.each do |ci|
      ci.instance_variable_set(:@assignment_tenure, tenures_by_assignment[ci.assignment_id])
    end

    # Batch load the latest finalized check-in per assignment so rendering the assignment
    # table does not issue one query per row.
    latest_finalized_by_assignment = AssignmentCheckIn
      .where(company_teammate: @teammate, assignment_id: assignment_ids)
      .closed
      .includes(finalized_by_teammate: :person)
      .order(assignment_id: :asc, official_check_in_completed_at: :desc)
      .group_by(&:assignment_id)
      .transform_values(&:first)
    check_ins.each do |ci|
      ci.instance_variable_set(:@latest_finalized_check_in, latest_finalized_by_assignment[ci.assignment_id])
    end
  end

  # Assignment/aspiration/position updates all use `check_in.update!(update_attrs) if update_attrs.present?`.
  # After blank coercion, +update_attrs+ may contain only +nil+ values for cleared columns; in ActiveSupport,
  # only +{}+ is +blank?+, so the hash stays +present?+ and the UPDATE persists NULL clears.
  def update_assignment_check_ins(check_ins_params = params)
    assignment_params = assignment_check_in_params(check_ins_params)
    return unless assignment_params.present?

    assignment_params.each do |check_in_id, attrs|
      assignment_id = attrs[:assignment_id]
      next unless assignment_id

      assignment = Assignment.find(assignment_id)
      check_in = find_assignment_check_in_for_update(check_in_id, assignment)
      next unless check_in

      close_duplicate_open_assignment_check_ins(check_in)

      begin
        if attrs[:status] == 'complete'
          update_attrs = CheckIns::CoerceBlankCheckInAttrs.for_assignment(
            attrs.except(:status, :assignment_id),
            view_mode: @view_mode
          )
          check_in.update!(update_attrs) if update_attrs.present?

          completion_service = CheckInCompletionService.new(check_in)
          if @view_mode == :employee
            completion_service.complete_employee_side!
          elsif @view_mode == :manager
            completion_service.complete_manager_side!(completed_by: current_company_teammate)
          end

          if completion_service.completion_detected?
            CheckIns::NotifyCompletionJob.perform_later(
              check_in_id: check_in.id,
              check_in_type: 'AssignmentCheckIn',
              completion_state: completion_service.completion_state,
              organization_id: organization.id
            )
          end
        else
          update_attrs = CheckIns::CoerceBlankCheckInAttrs.for_assignment(
            attrs.except(:status, :assignment_id),
            view_mode: @view_mode
          )
          check_in.update!(update_attrs) if update_attrs.present?

          if @view_mode == :employee
            check_in.uncomplete_employee_side!
          elsif @view_mode == :manager
            check_in.uncomplete_manager_side!
          end
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        add_check_in_error(check_in_type: 'Assignment', identifier: assignment.title, message: e.record.errors.full_messages.join(', '))
      end
    end
  end

  def find_assignment_check_in_for_update(check_in_id, assignment)
    if check_in_id.to_s =~ /\A\d+\z/
      found = AssignmentCheckIn.where(company_teammate: @teammate, assignment: assignment).find_by(id: check_in_id)
      return found if found
    end

    check_in = AssignmentCheckIn.where(company_teammate: @teammate, assignment: assignment).open.first
    check_in ||= AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
    if check_in.nil?
      check_in = AssignmentCheckIn.create!(
        teammate: @teammate,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: nil
      )
    end
    check_in
  end

  def update_aspiration_check_ins(check_ins_params = params)
    aspiration_params = aspiration_check_in_params(check_ins_params)
    return unless aspiration_params.present?

    aspiration_params.each do |check_in_id, attrs|
      aspiration_id = attrs[:aspiration_id]
      next unless aspiration_id

      aspiration = Aspiration.find(aspiration_id)
      check_in = find_aspiration_check_in_for_update(check_in_id, aspiration)
      next unless check_in

      close_duplicate_open_aspiration_check_ins(check_in)

      begin
        if attrs[:status] == 'complete'
          update_attrs = CheckIns::CoerceBlankCheckInAttrs.for_aspiration(
            attrs.except(:status, :aspiration_id),
            view_mode: @view_mode
          )
          check_in.update!(update_attrs) if update_attrs.present?

          completion_service = CheckInCompletionService.new(check_in)
          if @view_mode == :employee
            completion_service.complete_employee_side!
          elsif @view_mode == :manager
            completion_service.complete_manager_side!(completed_by: current_company_teammate)
          end

          if completion_service.completion_detected?
            CheckIns::NotifyCompletionJob.perform_later(
              check_in_id: check_in.id,
              check_in_type: 'AspirationCheckIn',
              completion_state: completion_service.completion_state,
              organization_id: organization.id
            )
          end
        else
          update_attrs = CheckIns::CoerceBlankCheckInAttrs.for_aspiration(
            attrs.except(:status, :aspiration_id),
            view_mode: @view_mode
          )
          check_in.update!(update_attrs) if update_attrs.present?

          if @view_mode == :employee
            check_in.uncomplete_employee_side!
          elsif @view_mode == :manager
            check_in.uncomplete_manager_side!
          end
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        add_check_in_error(check_in_type: 'Aspiration', identifier: aspiration.name, message: e.record.errors.full_messages.join(', '))
      end
    end
  end

  def find_aspiration_check_in_for_update(check_in_id, aspiration)
    if check_in_id.to_s =~ /\A\d+\z/
      found = AspirationCheckIn.where(company_teammate: @teammate, aspiration: aspiration).find_by(id: check_in_id)
      return found if found
    end
    AspirationCheckIn.find_or_create_open_for(@teammate, aspiration)
  end
  
  def update_position_check_in(check_ins_params = params)
    check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    return unless check_in

    attrs = position_check_in_params(check_ins_params)

    begin
      if attrs[:status] == 'complete'
        update_attrs = CheckIns::CoerceBlankCheckInAttrs.for_position(
          attrs.except(:status),
          view_mode: @view_mode
        )
        check_in.update!(update_attrs) if update_attrs.present?

        completion_service = CheckInCompletionService.new(check_in)
        if @view_mode == :employee
          completion_service.complete_employee_side!
        elsif @view_mode == :manager
          completion_service.complete_manager_side!(completed_by: current_company_teammate)
        end

        if completion_service.completion_detected?
          CheckIns::NotifyCompletionJob.perform_later(
            check_in_id: check_in.id,
            check_in_type: 'PositionCheckIn',
            completion_state: completion_service.completion_state,
            organization_id: organization.id
          )
        end
      else
        update_attrs = CheckIns::CoerceBlankCheckInAttrs.for_position(
          attrs.except(:status),
          view_mode: @view_mode
        )
        check_in.update!(update_attrs) if update_attrs.present?

        if @view_mode == :employee
          check_in.uncomplete_employee_side!
        elsif @view_mode == :manager
          check_in.uncomplete_manager_side!
        end
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      add_check_in_error(check_in_type: 'Position', identifier: 'check-in', message: e.record.errors.full_messages.join(', '))
    end
  end

  def position_check_in_params(check_ins_params = params)
    # Handle position_check_in parameter format (both :position_check_in and "[position_check_in]")
    check_ins_params = check_ins_params[:check_ins] || check_ins_params
    position_params = check_ins_params[:position_check_in] || check_ins_params["[position_check_in]"]
    return {} unless position_params
    
    if @view_mode == :employee
      position_params.permit(:employee_rating, :employee_private_notes, :status)
    elsif @view_mode == :manager
      position_params.permit(:manager_rating, :manager_private_notes, :status)
    else
      {}
    end
  end
  
  def assignment_check_in_params(check_ins_params = params)
    # Handle assignment_check_ins parameter format (both :assignment_check_ins and "[assignment_check_ins]")
    assignment_params = check_ins_params[:assignment_check_ins] || check_ins_params["[assignment_check_ins]"] || {}
    
    permitted_params = {}
    assignment_params.each do |check_in_id, attrs|
      if @view_mode == :employee
        permitted_params[check_in_id] = attrs.permit(:assignment_id, :employee_rating, :actual_energy_percentage, :employee_personal_alignment, :employee_private_notes, :status)
      elsif @view_mode == :manager
        permitted_params[check_in_id] = attrs.permit(:assignment_id, :manager_rating, :manager_private_notes, :status)
      end
    end
    
    permitted_params
  end
  
  def aspiration_check_in_params(check_ins_params = params)
    # Handle aspiration_check_ins parameter format (both :aspiration_check_ins and "[aspiration_check_ins]")
    aspiration_params = check_ins_params[:aspiration_check_ins] || check_ins_params["[aspiration_check_ins]"] || {}
    
    permitted_params = {}
    aspiration_params.each do |check_in_id, attrs|
      if @view_mode == :employee
        permitted_params[check_in_id] = attrs.permit(:aspiration_id, :employee_rating, :employee_private_notes, :status)
      elsif @view_mode == :manager
        permitted_params[check_in_id] = attrs.permit(:aspiration_id, :manager_rating, :manager_private_notes, :status)
      end
    end
    
    permitted_params
  end

  def add_check_in_error(check_in_type:, identifier:, message:)
    @check_in_errors << { type: check_in_type, identifier: identifier, message: message }
  end

  def check_in_errors_flash_message
    count = @check_in_errors.size
    details = @check_in_errors.first(3).map { |e| "#{e[:type]} #{e[:identifier]}: #{e[:message]}" }.join("; ")
    suffix = count > 3 ? " (and #{count - 3} more)" : ""
    "#{count} check-in(s) could not be saved. #{details}#{suffix}"
  end

  def close_duplicate_open_aspiration_check_ins(keep_check_in)
    return unless keep_check_in && current_company_teammate
    others = AspirationCheckIn
      .where(company_teammate: keep_check_in.company_teammate, aspiration: keep_check_in.aspiration)
      .open
      .where.not(id: keep_check_in.id)
    others.find_each do |dup|
      dup.update!(
        official_check_in_completed_at: Time.current,
        finalized_by_teammate: current_company_teammate,
        official_rating: dup.official_rating.presence || 'meeting'
      )
    end
  end

  def close_duplicate_open_assignment_check_ins(keep_check_in)
    return unless keep_check_in && current_company_teammate
    others = AssignmentCheckIn
      .where(company_teammate: keep_check_in.company_teammate, assignment: keep_check_in.assignment)
      .open
      .where.not(id: keep_check_in.id)
    others.find_each do |dup|
      dup.update!(
        official_check_in_completed_at: Time.current,
        finalized_by_teammate: current_company_teammate,
        official_rating: dup.official_rating.presence || 'meeting'
      )
    end
  end

  def determine_redirect_url
    # Check for button names in params (new architecture)
    # Button names follow pattern: save_and_<action>_<type>_<id>
    button_name = find_button_name_in_params
    
    if button_name
      # Extract parameters needed for the service
      service_params = extract_service_params_for_button(button_name)

      CheckIns::RedirectUrlService.call(
        button_name: normalized_redirect_button_name(button_name),
        organization: organization,
        teammate: @teammate,
        params: service_params
      )
    elsif params[:redirect_to].present?
      # Handle old redirect_to parameter (from button_tag with name="redirect_to")
      params[:redirect_to]
    elsif params[:redirect_url].present?
      # Handle old redirect_url parameter (backward compatibility)
      params[:redirect_url]
    else
      # Default to finalization page
      organization_company_teammate_finalization_path(organization, @teammate)
    end
  end

  def find_button_name_in_params
    # Look for button names that start with "save_and_" (top-level or under :check_ins)
    [params, params[:check_ins].presence].compact.each do |hash|
      hash.each_key do |key|
        if key.to_s.start_with?('save_and_')
          return key.to_s
        end
      end
    end
    nil
  end

  def extract_service_params_for_button(button_name)
    service_params = {}
    # Params may be at top level or under :check_ins when form uses scope: :check_ins
    req = params[:check_ins].presence || params

    # Extract return_text and return_url if present
    service_params[:return_text] = req[:return_text] if req[:return_text].present?
    service_params[:return_url] = req[:return_url] if req[:return_url].present?
    
    # Extract since_date if present (can be a date string or Date object)
    if req[:since_date].present?
      service_params[:since_date] = req[:since_date]
    end
    
    # Extract teammate if present (for observations)
    if req[:teammate_id].present?
      service_params[:teammate] = organization.teammates.find_by(id: req[:teammate_id])
    end

    # Single-item check-in redirect (stay, go_to_next) — check both top-level and nested
    service_params[:current_url] = (req[:current_url] || params[:current_url]).presence
    service_params[:current_type] = (req[:current_type] || params[:current_type]).presence
    service_params[:current_id] = (req[:current_id] || params[:current_id]).presence
    service_params[:current_person] = current_person
    
    service_params
  end

  def normalized_redirect_button_name(button_name)
    case button_name.to_s
    when "save_and_complete_go_to_next"
      "save_and_go_to_next"
    when "save_and_draft_stay"
      "save_and_stay"
    else
      button_name
    end
  end

  def check_in_hub_item_url(item)
    return organization_company_teammate_check_ins_path(organization, @teammate) if item.blank?

    case item[:type]&.to_sym
    when :assignment
      organization_teammate_assignment_path(organization, @teammate, item[:id])
    when :aspiration
      organization_teammate_aspiration_path(organization, @teammate, item[:id])
    when :position
      position_check_in_organization_teammate_path(organization, @teammate)
    else
      organization_company_teammate_check_ins_path(organization, @teammate)
    end
  end

  def build_up_next_explainer_items_for(perspective_person)
    manager_perspective = up_next_manager_perspective?(perspective_person)
    person_name = manager_perspective ? @manager_name : @employee_name
    next_result = CheckIns::SingleItemCheckInNextItemService.call(
      teammate: @teammate,
      organization: organization,
      current_person: perspective_person,
      current_type: :position,
      current_id: nil
    )
    ordered_items = next_result[:ordered_items].to_a
    latest_finalized_by_key = build_latest_finalized_by_item_key(ordered_items)
    latest_open_by_key = build_latest_open_check_in_by_item_key(ordered_items)

    ordered_items.each_with_index.map do |item, index|
      item_key = up_next_item_key(item)
      latest_finalized = latest_finalized_by_key[item_key]
      latest_open = latest_open_by_key[item_key]
      actions_needed_count = up_next_actions_needed_count(
        item: item,
        latest_finalized: latest_finalized,
        manager_perspective: manager_perspective
      )
      actions_total_count = manager_perspective ? 2 : 1
      {
        item: item,
        url: check_in_hub_item_url(item),
        finalized_line: up_next_finalized_line(latest_finalized),
        current_open_line: up_next_current_open_line(latest_open),
        therefore_line: up_next_therefore_line(item, index, ordered_items),
        ready_for_joint_review: up_next_ready_for_joint_review(item, latest_open),
        required_line: up_next_required_line(item),
        actions_needed_count: actions_needed_count,
        actions_total_count: actions_total_count,
        actions_line: up_next_actions_needed_line(actions_needed_count, person_name)
      }
    end
  end

  def assign_up_next_actions_spotlight!
    @employee_up_next_actions_needed = @employee_up_next_items.sum { |row| row[:actions_needed_count] }
    @employee_up_next_actions_total = @employee_up_next_items.sum { |row| row[:actions_total_count] }
    @manager_up_next_actions_needed = @manager_up_next_items.sum { |row| row[:actions_needed_count] }
    @manager_up_next_actions_total = @manager_up_next_items.sum { |row| row[:actions_total_count] }
    @up_next_actions_needed = @employee_up_next_actions_needed + @manager_up_next_actions_needed
    @up_next_actions_total = @employee_up_next_actions_total + @manager_up_next_actions_total
  end

  def up_next_manager_perspective?(perspective_person)
    perspective_person.id != @employee_perspective_person.id
  end

  def up_next_actions_needed_count(item:, latest_finalized:, manager_perspective:)
    count = up_next_check_in_action_needed?(item) ? 1 : 0
    count += 1 if manager_perspective && up_next_finalize_action_needed?(latest_finalized)
    count
  end

  def up_next_check_in_action_needed?(item)
    item[:bucket]&.to_sym == :red && item[:my_side_completed_at].blank?
  end

  def up_next_finalize_action_needed?(latest_finalized)
    level = latest_finalized&.clarity_level || :obscured
    level.in?(%i[blurred obscured])
  end

  def up_next_actions_needed_line(count, person_name)
    action_word = count == 1 ? "action" : "actions"
    "#{count} #{action_word} needed from #{person_name}"
  end

  def build_latest_finalized_by_item_key(items)
    aspiration_ids = items.select { |i| i[:type] == :aspiration }.map { |i| i[:id] }.compact
    assignment_ids = items.select { |i| i[:type] == :assignment }.map { |i| i[:id] }.compact
    by_key = {}

    if aspiration_ids.any?
      AspirationCheckIn.where(company_teammate: @teammate, aspiration_id: aspiration_ids)
        .closed
        .order(official_check_in_completed_at: :desc)
        .group_by(&:aspiration_id)
        .each { |id, rows| by_key[up_next_item_key(type: :aspiration, id: id)] = rows.first }
    end

    if assignment_ids.any?
      AssignmentCheckIn.where(company_teammate: @teammate, assignment_id: assignment_ids)
        .closed
        .order(official_check_in_completed_at: :desc)
        .group_by(&:assignment_id)
        .each { |id, rows| by_key[up_next_item_key(type: :assignment, id: id)] = rows.first }
    end

    position_latest = PositionCheckIn.where(company_teammate: @teammate).closed.order(official_check_in_completed_at: :desc).first
    by_key[up_next_item_key(type: :position, id: nil)] = position_latest if position_latest

    by_key
  end

  def build_latest_open_check_in_by_item_key(items)
    aspiration_ids = items.select { |i| i[:type] == :aspiration }.map { |i| i[:id] }.compact
    assignment_ids = items.select { |i| i[:type] == :assignment }.map { |i| i[:id] }.compact
    by_key = {}

    if aspiration_ids.any?
      AspirationCheckIn.where(company_teammate: @teammate, aspiration_id: aspiration_ids)
        .open
        .order(check_in_started_on: :desc, created_at: :desc)
        .group_by(&:aspiration_id)
        .each { |id, rows| by_key[up_next_item_key(type: :aspiration, id: id)] = rows.first }
    end

    if assignment_ids.any?
      AssignmentCheckIn.where(company_teammate: @teammate, assignment_id: assignment_ids)
        .open
        .order(check_in_started_on: :desc, created_at: :desc)
        .group_by(&:assignment_id)
        .each { |id, rows| by_key[up_next_item_key(type: :assignment, id: id)] = rows.first }
    end

    position_latest_open = PositionCheckIn.where(company_teammate: @teammate).open.order(check_in_started_on: :desc, created_at: :desc).first
    by_key[up_next_item_key(type: :position, id: nil)] = position_latest_open if position_latest_open

    by_key
  end

  def up_next_item_key(item = nil, type: nil, id: nil)
    item_type = item ? item[:type] : type
    item_id = item ? item[:id] : id
    "#{item_type}:#{item_id || 'none'}"
  end

  def up_next_ready_for_joint_review(item, latest_open)
    return nil unless latest_open&.ready_for_finalization?

    {
      label: "#{item[:name]} is ready for #{@employee_name} and #{@manager_name} to review together",
      url: organization_company_teammate_finalization_path(organization, @teammate)
    }
  end

  def up_next_finalized_line(latest_finalized)
    if latest_finalized&.official_check_in_completed_at.present?
      "Last finalized #{view_context.time_ago_in_words(latest_finalized.official_check_in_completed_at)} ago."
    else
      "No finalized check-in yet."
    end
  end

  def up_next_current_open_line(latest_open)
    return "No open check-in yet for this item." if latest_open.blank?

    employee_side = up_next_side_completion_phrase(latest_open.employee_completed_at)
    manager_side = up_next_side_completion_phrase(latest_open.manager_completed_at)
    "#{@employee_name}: #{employee_side} · #{@manager_name}: #{manager_side}"
  end

  def up_next_side_completion_phrase(timestamp)
    timestamp.present? ? "#{view_context.time_ago_in_words(timestamp)} ago" : "not completed yet"
  end

  def up_next_therefore_line(item, index, ordered_items)
    rank_reason = up_next_rank_reason(item, index, ordered_items)
    "Therefore this is #{up_next_clarity_level_label(item[:bucket])}, #{up_next_bucket_label(item[:bucket])}, and #{rank_reason}."
  end

  def up_next_clarity_level_label(bucket)
    case bucket&.to_sym
    when :green
      "crystal clear"
    when :yellow
      "clear"
    else
      "blurred or obscured"
    end
  end

  def up_next_bucket_label(bucket)
    case bucket&.to_sym
    when :green
      "green bucket"
    when :yellow
      "yellow bucket"
    else
      "red bucket"
    end
  end

  def up_next_rank_reason(item, index, ordered_items)
    current_completed_at = item[:my_side_completed_at]
    if index.zero? && current_completed_at.blank?
      return "ranked first because your side has not been completed yet on the open check-in"
    end
    return "ranked first because it has the oldest completed date on your side" if index.zero?

    previous_item = ordered_items[index - 1]
    previous_completed_at = previous_item[:my_side_completed_at]
    if current_completed_at.blank? && previous_completed_at.blank?
      prev_bucket_rank = up_next_bucket_urgency_rank(previous_item[:bucket])
      curr_bucket_rank = up_next_bucket_urgency_rank(item[:bucket])
      if curr_bucket_rank > prev_bucket_rank
        return "ordered after items with a more urgent clarity bucket (red before yellow before green)"
      end
      prev_type_rank = up_next_type_rank(previous_item[:type])
      curr_type_rank = up_next_type_rank(item[:type])
      if curr_bucket_rank == prev_bucket_rank && curr_type_rank > prev_type_rank
        return "ordered after items of an earlier type (aspiration before assignment before position)"
      end
      if curr_bucket_rank == prev_bucket_rank &&
           curr_type_rank == prev_type_rank &&
           item[:bucket_activity_at].present? &&
           previous_item[:bucket_activity_at].present? &&
           item[:bucket_activity_at] > previous_item[:bucket_activity_at]
        return "ordered by oldest clarity activity among items with the same bucket and type where your side has not been completed yet"
      end
      if curr_bucket_rank == prev_bucket_rank && curr_type_rank == prev_type_rank
        return "ordered by name among items with the same clarity urgency and type where your side has not been completed yet"
      end
      return "ordered among items where your side has not been completed yet"
    end
    if current_completed_at.blank?
      "ordered among items where your side has not been completed yet"
    elsif previous_completed_at.blank?
      "ordered after items where your side has not been completed yet"
    elsif previous_completed_at.to_i == current_completed_at.to_i
      "ordered by type then name when completion timing ties"
    else
      "ordered by your side's completion date from oldest to newest"
    end
  end

  def up_next_type_rank(type)
    { aspiration: 0, assignment: 1, position: 2 }[type&.to_sym] || 99
  end

  def up_next_bucket_urgency_rank(bucket)
    case bucket&.to_sym
    when :red then 0
    when :yellow then 1
    when :green then 2
    else 3
    end
  end

  def up_next_required_line(item)
    prefix = up_next_list_reason_prefix(item)
    case item[:type]&.to_sym
    when :position
      "#{prefix} this is the teammate's current position check-in."
    when :assignment
      assignment_id = item[:id].to_i
      on_position = @up_next_required_assignment_ids.include?(assignment_id)
      active_tenure = @up_next_active_tenure_assignment_ids.include?(assignment_id)

      if on_position && active_tenure
        "#{prefix} it is required on the current position and the teammate currently has it as an active assignment tenure."
      elsif on_position
        "#{prefix} it is required on the current position."
      elsif active_tenure
        "#{prefix} the teammate currently has it as an active assignment tenure."
      else
        "#{prefix} this item exists in the 1-by-1 check-in scope."
      end
    else
      "#{prefix} aspirational values are always included for 1-by-1 clarity check-ins."
    end
  end

  def up_next_list_reason_prefix(item)
    case item[:type]&.to_sym
    when :position then "This position check-in is on the list because"
    when :assignment then "This assignment is on the list because"
    else "This aspirational value is on the list because"
    end
  end

  def active_assignment_ids_for_teammate
    AssignmentTenure
      .joins(:assignment)
      .where(company_teammate: @teammate, ended_at: nil)
      .where(assignments: { company: organization.self_and_descendants })
      .distinct
      .pluck(:assignment_id)
  end

  def apply_single_item_status_override!
    status = case find_button_name_in_params
    when "save_and_complete_go_to_next"
      "complete"
    when "save_and_draft_stay"
      "draft"
    end
    return unless status

    req = params[:check_ins].presence || params

    if req[:position_check_in].present?
      req[:position_check_in][:status] = status
      return
    end

    assignment_params = req[:assignment_check_ins]
    if assignment_params.respond_to?(:each_value)
      first_assignment = assignment_params.each_value.first
      first_assignment[:status] = status if first_assignment.present?
      return
    end

    aspiration_params = req[:aspiration_check_ins]
    return unless aspiration_params.respond_to?(:each_value)

    first_aspiration = aspiration_params.each_value.first
    first_aspiration[:status] = status if first_aspiration.present?
  end

end

