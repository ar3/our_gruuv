class EnsureAssignmentTenuresSyncProcessor
  attr_reader :bulk_sync_event, :organization, :results

  def initialize(bulk_sync_event, organization)
    @bulk_sync_event = bulk_sync_event
    @organization = organization
    @results = {
      successes: [],
      failures: [],
      summary: {
        total_processed: 0,
        successful_creations: 0,
        skipped_existing: 0,
        failed_operations: 0
      }
    }
  end

  def process
    preview_actions = bulk_sync_event.preview_actions || {}
    tenures_to_create = Array(preview_actions['assignment_tenures'] || [])

    if tenures_to_create.empty?
      results[:failures] << {
        'type' => 'system_error',
        'error' => 'No assignment tenures to create'
      }
      return false
    end

    ActiveRecord::Base.transaction do
      tenures_to_create.each do |tenure_data|
        process_assignment_tenure_creation(tenure_data)
      end

      # Update summary
      update_summary

      true
    end
  rescue => e
    results[:failures] << {
      'type' => 'system_error',
      'error' => e.message,
      'backtrace' => e.backtrace.first(5)
    }
    false
  end

  private

  def process_assignment_tenure_creation(tenure_data)
    teammate_id = tenure_data['teammate_id']
    assignment_id = tenure_data['assignment_id']
    anticipated_energy_percentage = tenure_data['anticipated_energy_percentage']

    teammate = CompanyTeammate.find_by(id: teammate_id)
    unless teammate
      results[:failures] << {
        'type' => 'assignment_tenure_creation',
        'teammate_id' => teammate_id,
        'assignment_id' => assignment_id,
        'error' => "Teammate not found"
      }
      return
    end

    assignment = Assignment.find_by(id: assignment_id)
    unless assignment
      results[:failures] << {
        'type' => 'assignment_tenure_creation',
        'teammate_id' => teammate_id,
        'assignment_id' => assignment_id,
        'error' => "Assignment not found"
      }
      return
    end

    # Double-check if assignment tenure already exists (in case it was created between preview and processing)
    existing_tenure = AssignmentTenure.active
      .find_by(company_teammate: teammate, assignment: assignment)

    if existing_tenure
      results[:summary][:skipped_existing] += 1
      results[:successes] << {
        'type' => 'assignment_tenure_creation',
        'teammate_id' => teammate.id,
        'teammate_name' => teammate.person.display_name,
        'assignment_id' => assignment.id,
        'assignment_title' => assignment.title,
        'action' => 'skipped',
        'reason' => 'Assignment tenure already exists'
      }
      return
    end

    # Create new assignment tenure
    assignment_tenure = AssignmentTenure.new(
      teammate: teammate,
      assignment: assignment,
      started_at: Date.current,
      ended_at: nil,
      anticipated_energy_percentage: anticipated_energy_percentage
    )

    if assignment_tenure.save
      results[:summary][:successful_creations] += 1
      results[:successes] << {
        'type' => 'assignment_tenure_creation',
        'teammate_id' => teammate.id,
        'teammate_name' => teammate.person.display_name,
        'assignment_id' => assignment.id,
        'assignment_title' => assignment.title,
        'assignment_tenure_id' => assignment_tenure.id,
        'anticipated_energy_percentage' => anticipated_energy_percentage,
        'action' => 'created'
      }
    else
      results[:failures] << {
        'type' => 'assignment_tenure_creation',
        'teammate_id' => teammate.id,
        'teammate_name' => teammate.person.display_name,
        'assignment_id' => assignment.id,
        'assignment_title' => assignment.title,
        'error' => assignment_tenure.errors.full_messages.join(', ')
      }
    end
  end

  def update_summary
    results[:summary][:total_processed] = results[:successes].count + results[:failures].count
    results[:summary][:failed_operations] = results[:failures].count
  end
end
