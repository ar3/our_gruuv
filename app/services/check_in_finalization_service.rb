class CheckInFinalizationService
  
  def initialize(teammate:, finalization_params:, finalized_by:, request_info: {}, maap_snapshot_reason: nil)
    @teammate = teammate
    @params = finalization_params
    @finalized_by = finalized_by
    @request_info = request_info
    @maap_snapshot_reason = maap_snapshot_reason
  end
  
  def call
    ActiveRecord::Base.transaction do
      results = {}
      
      # Finalize position if finalize flag is set
      if @params[:position_check_in]&.dig(:finalize) == '1'
        position_result = finalize_position
        return position_result unless position_result.ok?
        results[:position] = position_result.value
      end
      
      # Finalize assignments that have finalize flag set
      if @params[:assignment_check_ins]
        assignment_results = finalize_assignments
        return assignment_results unless assignment_results.ok?
        results[:assignments] = assignment_results.value
      end
      
      # Finalize aspirations that have finalize flag set
      if @params[:aspiration_check_ins]
        aspiration_results = finalize_aspirations
        return aspiration_results unless aspiration_results.ok?
        results[:aspirations] = aspiration_results.value
      end
      
      # Create ONE snapshot with complete MAAP state
      snapshot = create_snapshot(results)
      
      # Link snapshot to all finalized check-ins
      link_snapshot_to_check_ins(results, snapshot)
      
      Result.ok(snapshot: snapshot, results: results)
    end
  rescue => e
    Result.err("Failed to finalize check-ins: #{e.message}")
  end
  
  private
  
  def finalize_assignments
    assignment_results = []
    
    return Result.ok([]) unless @params[:assignment_check_ins]
    
    @params[:assignment_check_ins].each do |check_in_id, assignment_params|
      # Only finalize if the finalize flag is set
      next unless assignment_params[:finalize] == '1'
      
      check_in = AssignmentCheckIn.find(check_in_id)
      next unless check_in.ready_for_finalization?
      
      result = Finalizers::AssignmentCheckInFinalizer.new(
        check_in: check_in,
        official_rating: assignment_params[:official_rating],
        shared_notes: assignment_params[:shared_notes],
        anticipated_energy_percentage: assignment_params[:anticipated_energy_percentage],
        finalized_by: @finalized_by
      ).finalize
      
      return result unless result.ok?
      assignment_results << result.value
    end
    
    Result.ok(assignment_results)
  end
  
  def finalize_position
    check_in = PositionCheckIn.where(teammate: @teammate).ready_for_finalization.first
    return Result.err("Position check-in not ready") unless check_in
    
    Finalizers::PositionCheckInFinalizer.new(
      check_in: check_in,
      official_rating: @params[:position_check_in][:official_rating].to_i,
      shared_notes: @params[:position_check_in][:shared_notes],
      finalized_by: @finalized_by
    ).finalize
  end
  
  def finalize_aspirations
    aspiration_results = []
    
    return Result.ok([]) unless @params[:aspiration_check_ins]
    
    @params[:aspiration_check_ins].each do |check_in_id, aspiration_params|
      # Only finalize if the finalize flag is set
      next unless aspiration_params[:finalize] == '1'
      
      check_in = AspirationCheckIn.find(check_in_id)
      next unless check_in.ready_for_finalization?
      
      result = Finalizers::AspirationCheckInFinalizer.new(
        check_in: check_in,
        official_rating: aspiration_params[:official_rating],
        shared_notes: aspiration_params[:shared_notes],
        finalized_by: @finalized_by
      ).finalize
      
      return result unless result.ok?
      aspiration_results << result.value
    end
    
    Result.ok(aspiration_results)
  end
  
  def create_snapshot(results)
    reason = @maap_snapshot_reason.presence || "Check-in finalization for #{@teammate.person.display_name}"
    
    MaapSnapshot.create!(
      employee: @teammate.person,
      created_by: @finalized_by,
      company: @teammate.organization,
      change_type: determine_change_type(results),
      reason: reason,
      effective_date: Time.current,
      manager_request_info: @request_info.merge(
        finalized_by_id: @finalized_by.id,
        timestamp: Time.current.iso8601
      ),
          maap_data: build_ratings_data(results)
    )
  end
  
  def determine_change_type(results)
    types = []
    types << 'position_tenure' if results[:position]
    types << 'assignment_management' if results[:assignments]
    types << 'aspiration_management' if results[:aspirations]
    
    types.length == 1 ? types.first : 'bulk_check_in_finalization'
  end
  
  def build_ratings_data(results)
    {
      position: build_position_data,
      assignments: build_assignment_ratings,
      abilities: build_abilities_data,
      aspirations: build_aspiration_ratings
    }
  end
  
  def build_position_data
    active_employment = @teammate.employment_tenures.active.first
    return nil unless active_employment
    
    # Find most recent closed employment tenure
    previous_closed_tenure = @teammate.employment_tenures
      .for_company(@teammate.organization)
      .inactive
      .order(ended_at: :desc)
      .first
    
    rated_position = if previous_closed_tenure
      {
        seat_id: previous_closed_tenure.seat_id,
        manager_teammate_id: previous_closed_tenure.manager_teammate_id,
        position_id: previous_closed_tenure.position_id,
        employment_type: previous_closed_tenure.employment_type,
        official_position_rating: previous_closed_tenure.official_position_rating,
        started_at: previous_closed_tenure.started_at.to_time.iso8601,
        ended_at: previous_closed_tenure.ended_at.to_time.iso8601
      }
    else
      {}
    end
    
    {
      position_id: active_employment.position_id,
      manager_teammate_id: active_employment.manager_teammate_id,
      seat_id: active_employment.seat_id,
      employment_type: active_employment.employment_type,
      rated_position: rated_position
    }
  end
  
  def build_assignment_ratings
    @teammate.assignment_tenures.active.includes(:assignment).joins(:assignment).where(assignments: { company: @teammate.organization }).map do |active_tenure|
      # Find most recent closed assignment tenure for this assignment
      previous_closed_tenure = @teammate.assignment_tenures
        .where(assignment: active_tenure.assignment)
        .where.not(ended_at: nil)
        .order(ended_at: :desc)
        .first
      
      rated_assignment = if previous_closed_tenure
        {
          assignment_id: previous_closed_tenure.assignment_id,
          anticipated_energy_percentage: previous_closed_tenure.anticipated_energy_percentage,
          official_rating: previous_closed_tenure.official_rating,
          started_at: previous_closed_tenure.started_at.to_time.iso8601,
          ended_at: previous_closed_tenure.ended_at.to_time.iso8601
        }
      else
        {}
      end
      
      {
        assignment_id: active_tenure.assignment_id,
        anticipated_energy_percentage: active_tenure.anticipated_energy_percentage,
        rated_assignment: rated_assignment
      }
    end
  end
  
  def build_abilities_data
    @teammate.teammate_milestones.joins(:ability).where(abilities: { organization: @teammate.organization }).map do |milestone|
      {
        ability_id: milestone.ability_id,
        milestone_level: milestone.milestone_level,
        certified_by_id: milestone.certified_by_id,
        attained_at: milestone.attained_at
      }
    end
  end
  
  def build_aspiration_ratings
    aspirations = @teammate.organization.aspirations
    
    aspirations.map do |aspiration|
      # Get the last finalized aspiration_check_in for this teammate and aspiration
      finalized_check_in = AspirationCheckIn.latest_finalized_for(@teammate, aspiration)
      
      {
        aspiration_id: aspiration.id,
        official_rating: finalized_check_in&.official_rating
      }
    end
  end
  
  def link_snapshot_to_check_ins(results, snapshot)
    results[:position][:check_in].update!(maap_snapshot: snapshot) if results[:position]
    
    # Link assignment check-ins
    if results[:assignments]
      results[:assignments].each do |assignment_result|
        assignment_result[:check_in].update!(maap_snapshot: snapshot)
      end
    end
  end
end
