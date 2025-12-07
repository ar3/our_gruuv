class RefreshSlackSyncProcessor
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
        successful_creates: 0,
        successful_terminations: 0,
        failed_operations: 0
      }
    }
  end

  def process
    preview_actions = bulk_sync_event.preview_actions || {}
    
    updates_to_process = Array(preview_actions['update_slack_identities'] || [])
    associations_to_process = Array(preview_actions['create_slack_associations'] || [])
    terminations_to_process = Array(preview_actions['suggest_terminations'] || [])

    if updates_to_process.empty? && associations_to_process.empty? && terminations_to_process.empty?
      results[:failures] << {
        type: 'system_error',
        error: 'No actions selected for processing'
      }
      return false
    end

    # Get raw Slack data from source_contents
    raw_slack_data = bulk_sync_event.raw_slack_data || []
    slack_users_by_id = raw_slack_data.index_by { |u| u['id'] }

    ActiveRecord::Base.transaction do
      # Process updates (only those that need updating)
      updates_to_process.select { |u| u['will_update'] == true }.each do |update_data|
        process_slack_identity_update(update_data, slack_users_by_id)
      end

      # Process associations
      associations_to_process.each do |association_data|
        process_slack_association(association_data, slack_users_by_id)
      end

      # Process terminations
      terminations_to_process.each do |termination_data|
        process_termination_suggestion(termination_data)
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

  def process_slack_identity_update(update_data, slack_users_by_id)
    identity_id = update_data['teammate_identity_id']
    slack_user_id = update_data['slack_user_id']

    identity = TeammateIdentity.find_by(id: identity_id)
    unless identity
      results[:failures] << {
        type: 'update_slack_identity',
        teammate_identity_id: identity_id,
        error: "TeammateIdentity not found"
      }
      return
    end

    slack_user = slack_users_by_id[slack_user_id]
    unless slack_user
      results[:failures] << {
        type: 'update_slack_identity',
        teammate_identity_id: identity_id,
        error: "Slack user not found in response"
      }
      return
    end

    slack_name = slack_user.dig('profile', 'real_name') || slack_user.dig('profile', 'display_name') || slack_user['name']
    slack_email = slack_user.dig('profile', 'email')
    slack_image_url = slack_user.dig('profile', 'image_512') || 
                     slack_user.dig('profile', 'image_192') || 
                     slack_user.dig('profile', 'image_72') ||
                     slack_user.dig('profile', 'image_48') ||
                     slack_user.dig('profile', 'image_32') ||
                     slack_user.dig('profile', 'image_24')

    if identity.update(
      name: slack_name,
      email: slack_email,
      profile_image_url: slack_image_url,
      raw_data: slack_user
    )
      results[:successes] << {
        type: 'update_slack_identity',
        teammate_identity_id: identity.id,
        person_name: identity.teammate.person.display_name,
        slack_user_id: slack_user_id,
        changes: update_data['changes']
      }
    else
      results[:failures] << {
        type: 'update_slack_identity',
        teammate_identity_id: identity.id,
        person_name: identity.teammate.person.display_name,
        error: identity.errors.full_messages.join(', ')
      }
    end
  end

  def process_slack_association(association_data, slack_users_by_id)
    teammate_id = association_data['teammate_id']
    slack_user_id = association_data['slack_user_id']

    teammate = Teammate.find_by(id: teammate_id)
    unless teammate
      results[:failures] << {
        type: 'create_slack_association',
        teammate_id: teammate_id,
        error: "Teammate not found"
      }
      return
    end

    # Check if already associated
    if teammate.teammate_identities.slack.exists?
      results[:failures] << {
        type: 'create_slack_association',
        teammate_id: teammate_id,
        person_name: teammate.person.display_name,
        error: "Teammate already has a Slack identity"
      }
      return
    end

    slack_user = slack_users_by_id[slack_user_id]
    unless slack_user
      results[:failures] << {
        type: 'create_slack_association',
        teammate_id: teammate_id,
        error: "Slack user not found in response"
      }
      return
    end

    slack_name = slack_user.dig('profile', 'real_name') || slack_user.dig('profile', 'display_name') || slack_user['name']
    slack_email = slack_user.dig('profile', 'email')
    slack_image_url = slack_user.dig('profile', 'image_512') || 
                     slack_user.dig('profile', 'image_192') || 
                     slack_user.dig('profile', 'image_72') ||
                     slack_user.dig('profile', 'image_48') ||
                     slack_user.dig('profile', 'image_32') ||
                     slack_user.dig('profile', 'image_24')

    identity = teammate.teammate_identities.build(
      provider: 'slack',
      uid: slack_user_id,
      email: slack_email,
      name: slack_name,
      profile_image_url: slack_image_url,
      raw_data: slack_user
    )

    if identity.save
      results[:successes] << {
        type: 'create_slack_association',
        teammate_id: teammate.id,
        person_name: teammate.person.display_name,
        slack_user_id: slack_user_id,
        slack_user_name: slack_name
      }
    else
      results[:failures] << {
        type: 'create_slack_association',
        teammate_id: teammate.id,
        person_name: teammate.person.display_name,
        error: identity.errors.full_messages.join(', ')
      }
    end
  end

  def process_termination_suggestion(termination_data)
    teammate_id = termination_data['teammate_id']
    suggested_date = termination_data['suggested_termination_date'] || Date.current

    teammate = Teammate.find_by(id: teammate_id)
    unless teammate
      results[:failures] << {
        type: 'suggest_termination',
        teammate_id: teammate_id,
        error: "Teammate not found"
      }
      return
    end

    if teammate.update(last_terminated_at: suggested_date)
      results[:successes] << {
        type: 'suggest_termination',
        teammate_id: teammate.id,
        person_name: teammate.person.display_name,
        termination_date: suggested_date,
        reason: termination_data['termination_reason']
      }
    else
      results[:failures] << {
        type: 'suggest_termination',
        teammate_id: teammate.id,
        person_name: teammate.person.display_name,
        error: teammate.errors.full_messages.join(', ')
      }
    end
  end

  def update_summary
    results[:summary][:total_processed] = results[:successes].count + results[:failures].count
    results[:summary][:successful_updates] = results[:successes].count { |s| s[:type] == 'update_slack_identity' }
    results[:summary][:successful_creates] = results[:successes].count { |s| s[:type] == 'create_slack_association' }
    results[:summary][:successful_terminations] = results[:successes].count { |s| s[:type] == 'suggest_termination' }
    results[:summary][:failed_operations] = results[:failures].count
  end
end

