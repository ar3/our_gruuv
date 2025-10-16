class CheckInFinalizationService
  
  def initialize(teammate:, finalization_params:, finalized_by:, request_info: {})
    @teammate = teammate
    @params = finalization_params
    @finalized_by = finalized_by
    @request_info = request_info
  end
  
  def call
    ActiveRecord::Base.transaction do
      results = {}
      
      # Finalize position if selected
      if @params[:finalize_position]
        position_result = finalize_position
        return position_result unless position_result.ok?
        results[:position] = position_result.value
      end
      
      # Finalize assignments if selected
      if @params[:finalize_assignments]
        assignment_results = finalize_assignments
        return assignment_results unless assignment_results.ok?
        results[:assignments] = assignment_results.value
      end
      
      # Finalize aspirations if selected (Phase 3)
      if @params[:finalize_aspirations]
        # Implementation in Phase 3
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
      assignment_id = assignment_params[:assignment_id]
      next unless assignment_id
      
      check_in = AssignmentCheckIn.find(check_in_id)
      next unless check_in.ready_for_finalization?
      
      result = Finalizers::AssignmentCheckInFinalizer.new(
        check_in: check_in,
        official_rating: assignment_params[:official_rating],
        shared_notes: assignment_params[:shared_notes],
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
      official_rating: @params[:position_official_rating].to_i,
      shared_notes: @params[:position_shared_notes],
      finalized_by: @finalized_by
    ).finalize
  end
  
  def create_snapshot(results)
    MaapSnapshot.create!(
      employee: @teammate.person,
      created_by: @finalized_by,
      company: @teammate.organization,
      change_type: determine_change_type(results),
      reason: "Check-in finalization for #{@teammate.person.display_name}",
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
      position: results.dig(:position, :rating_data),
      assignments: build_assignment_ratings,
      milestones: build_milestone_attainments,
      aspirations: build_aspiration_ratings
    }
  end
  
  def build_assignment_ratings
    @teammate.assignment_tenures.active.map do |tenure|
      {
        assignment_id: tenure.assignment_id,
        anticipated_energy: tenure.anticipated_energy_percentage,
        official_rating: tenure.official_rating,
        rated_at: tenure.updated_at.to_date.to_s
      }
    end
  end
  
  def build_milestone_attainments
    @teammate.teammate_milestones.map do |milestone|
      {
        ability_id: milestone.ability_id,
        milestone_level: milestone.milestone_level,
        attained_at: milestone.attained_at.to_s,
        certified_by_id: milestone.certified_by_id
      }
    end
  end
  
  def build_aspiration_ratings
    # Implemented in Phase 3
    []
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
