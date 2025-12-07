class RefreshNamesSyncProcessor
  attr_reader :bulk_sync_event, :organization, :results

  def initialize(bulk_sync_event, organization)
    @bulk_sync_event = bulk_sync_event
    @organization = organization
    @results = {
      successes: [],
      failures: [],
      summary: {
        total_processed: 0,
        successful_updates: 0,
        failed_operations: 0
      }
    }
  end

  def process
    preview_actions = bulk_sync_event.preview_actions || {}
    updates_to_process = Array(preview_actions['preferred_name_updates'] || [])

    if updates_to_process.empty?
      results[:failures] << {
        type: 'system_error',
        error: 'No updates selected for processing'
      }
      return false
    end

    ActiveRecord::Base.transaction do
      updates_to_process.each do |update_data|
        process_preferred_name_update(update_data)
      end

      # Update summary
      update_summary

      true
    end
  rescue => e
    results[:failures] << {
      type: 'system_error',
      error: e.message,
      backtrace: e.backtrace.first(5)
    }
    false
  end

  private

  def process_preferred_name_update(update_data)
    person_id = update_data['person_id']
    new_preferred_name = update_data['new_preferred_name']

    person = Person.find_by(id: person_id)
    unless person
      results[:failures] << {
        type: 'preferred_name_update',
        person_id: person_id,
        error: "Person not found"
      }
      return
    end

    if person.update(preferred_name: new_preferred_name)
      results[:successes] << {
        type: 'preferred_name_update',
        person_id: person.id,
        person_name: person.display_name,
        old_preferred_name: update_data['current_preferred_name'],
        new_preferred_name: new_preferred_name
      }
    else
      results[:failures] << {
        type: 'preferred_name_update',
        person_id: person.id,
        person_name: person.display_name,
        error: person.errors.full_messages.join(', ')
      }
    end
  end

  def update_summary
    results[:summary][:total_processed] = results[:successes].count + results[:failures].count
    results[:summary][:successful_updates] = results[:successes].count
    results[:summary][:failed_operations] = results[:failures].count
  end
end

