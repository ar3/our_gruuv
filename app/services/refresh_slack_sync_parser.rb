class RefreshSlackSyncParser
  attr_reader :organization, :errors, :parsed_data, :raw_slack_response, :workspace_id, :workspace_name, :total_users_fetched

  def initialize(organization)
    @organization = organization
    @errors = []
    @parsed_data = {}
    @raw_slack_response = []
    @workspace_id = nil
    @workspace_name = nil
    @total_users_fetched = 0
  end

  def parse
    @errors = []
    @parsed_data = {}

    slack_config = organization.calculated_slack_config
    unless slack_config&.configured?
      @errors << "Slack not configured for this organization"
      return false
    end

    @workspace_id = slack_config.workspace_id
    @workspace_name = slack_config.workspace_name

    begin
      slack_service = SlackService.new(organization)
      slack_users = slack_service.list_users
      
      if slack_users.empty?
        @errors << "Failed to fetch Slack users"
        return false
      end

      @raw_slack_response = slack_users
      @total_users_fetched = slack_users.length

      # Type 1: Update Existing Slack Identities
      update_actions = find_slack_identity_updates(slack_users)

      # Type 2: Associate Unassociated Teammates
      association_actions = find_unassociated_teammate_matches(slack_users)

      # Type 3: Suggest Terminations
      termination_actions = find_termination_suggestions(slack_users)

      @parsed_data = {
        update_slack_identities: update_actions,
        create_slack_associations: association_actions,
        suggest_terminations: termination_actions
      }

      true
    rescue => e
      @errors << "Error parsing Slack data: #{e.message}"
      Rails.logger.error "RefreshSlackSyncParser error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  def enhanced_preview_actions
    {
      'update_slack_identities' => parsed_data[:update_slack_identities] || [],
      'create_slack_associations' => parsed_data[:create_slack_associations] || [],
      'suggest_terminations' => parsed_data[:suggest_terminations] || []
    }
  end

  private

  def find_slack_identity_updates(slack_users)
    # Find all existing Slack identities for organization teammates
    existing_identities = TeammateIdentity.slack
                                         .joins(:company_teammate)
                                         .where(teammates: { organization: organization })
                                         .includes(:teammate, :teammate => :person)

    updates = []
    slack_users_by_id = slack_users.index_by { |u| u['id'] }

    existing_identities.each.with_index(1) do |identity, index|
      slack_user = slack_users_by_id[identity.uid]
      
      if slack_user
        # Check if any data needs updating
        slack_name = slack_user.dig('profile', 'real_name') || slack_user.dig('profile', 'display_name') || slack_user['name']
        slack_email = slack_user.dig('profile', 'email')
        slack_image_url = slack_user.dig('profile', 'image_512') || 
                         slack_user.dig('profile', 'image_192') || 
                         slack_user.dig('profile', 'image_72') ||
                         slack_user.dig('profile', 'image_48') ||
                         slack_user.dig('profile', 'image_32') ||
                         slack_user.dig('profile', 'image_24')

        needs_update = false
        changes = []

        if identity.name != slack_name
          needs_update = true
          changes << "name: '#{identity.name}' → '#{slack_name}'"
        end

        if identity.email != slack_email
          needs_update = true
          changes << "email: '#{identity.email}' → '#{slack_email}'"
        end

        if identity.profile_image_url != slack_image_url
          needs_update = true
          changes << "profile_image_url: updated"
        end

        updates << {
          row: index,
          action_type: 'update_slack_identity',
          teammate_identity_id: identity.id,
          teammate_id: identity.teammate_id,
          person_id: identity.teammate.person_id,
          person_name: identity.teammate.person.display_name,
          slack_user_id: identity.uid,
          slack_user_name: slack_name,
          current_name: identity.name,
          new_name: slack_name,
          current_email: identity.email,
          new_email: slack_email,
          changes: needs_update ? changes.join(', ') : 'Already synced - no changes needed',
          will_update: needs_update,
          status: needs_update ? 'needs_update' : 'already_synced'
        }
      else
        # Slack user not found in current Slack workspace (might be deleted)
        updates << {
          row: index,
          action_type: 'update_slack_identity',
          teammate_identity_id: identity.id,
          teammate_id: identity.teammate_id,
          person_id: identity.teammate.person_id,
          person_name: identity.teammate.person.display_name,
          slack_user_id: identity.uid,
          slack_user_name: identity.name || 'Unknown',
          current_name: identity.name,
          new_name: nil,
          current_email: identity.email,
          new_email: nil,
          changes: 'Slack user not found in workspace',
          will_update: false,
          status: 'not_found'
        }
      end
    end

    updates
  end

  def find_unassociated_teammate_matches(slack_users)
    # Find company teammates without Slack identities
    unassociated_teammates = organization.teammates
                                         .where(last_terminated_at: nil)
                                         .joins(:person)
                                         .includes(:person, :teammate_identities)
                                         .where.not(id: TeammateIdentity.slack.select(:teammate_id))

    matches = []
    slack_users_by_email = slack_users.select { |u| u.dig('profile', 'email').present? }
                                     .index_by { |u| u.dig('profile', 'email')&.downcase }

    unassociated_teammates.each.with_index(1) do |teammate, index|
      person = teammate.person
      next unless person.email.present?

      slack_user = slack_users_by_email[person.email.downcase]
      next unless slack_user

      # Check if this Slack user is already associated with another teammate
      slack_user_id = slack_user['id']
      existing_association = TeammateIdentity.slack.where(uid: slack_user_id).exists?
      next if existing_association

      slack_name = slack_user.dig('profile', 'real_name') || slack_user.dig('profile', 'display_name') || slack_user['name']
      slack_email = slack_user.dig('profile', 'email')
      slack_image_url = slack_user.dig('profile', 'image_512') || 
                       slack_user.dig('profile', 'image_192') || 
                       slack_user.dig('profile', 'image_72') ||
                       slack_user.dig('profile', 'image_48') ||
                       slack_user.dig('profile', 'image_32') ||
                       slack_user.dig('profile', 'image_24')

      matches << {
        row: index,
        action_type: 'create_slack_association',
        teammate_id: teammate.id,
        person_id: person.id,
        person_name: person.display_name,
        person_email: person.email,
        slack_user_id: slack_user_id,
        slack_user_name: slack_name,
        slack_user_email: slack_email,
        slack_image_url: slack_image_url,
        will_create: true
      }
    end

    matches
  end

  def find_termination_suggestions(slack_users)
    # Find Slack identities that are deleted, bots, or disabled
    # and check if associated teammate is active
    existing_identities = TeammateIdentity.slack
                                         .joins(:company_teammate)
                                         .where(teammates: { organization: organization })
                                         .includes(:teammate, :teammate => :person)

    suggestions = []
    slack_users_by_id = slack_users.index_by { |u| u['id'] }

    existing_identities.each.with_index(1) do |identity, index|
      slack_user = slack_users_by_id[identity.uid]
      next unless slack_user

      # Check if Slack user is deleted, bot, or disabled
      is_deleted = slack_user['deleted'] == true
      is_bot = slack_user['is_bot'] == true
      is_restricted = slack_user['is_restricted'] == true
      is_ultra_restricted = slack_user['is_ultra_restricted'] == true

      should_suggest_termination = is_deleted || is_bot || is_restricted || is_ultra_restricted

      next unless should_suggest_termination

      teammate = identity.teammate
      person = teammate.person

      # Check if teammate is active (employed, not terminated)
      is_active = teammate.first_employed_at.present? && teammate.last_terminated_at.nil?

      if is_active
        reason = []
        reason << "deleted" if is_deleted
        reason << "bot" if is_bot
        reason << "restricted" if is_restricted
        reason << "ultra_restricted" if is_ultra_restricted

        suggestions << {
          row: index,
          action_type: 'suggest_termination',
          teammate_id: teammate.id,
          person_id: person.id,
          person_name: person.display_name,
          slack_user_id: identity.uid,
          slack_user_name: slack_user.dig('profile', 'real_name') || slack_user['name'],
          termination_reason: reason.join(', '),
          current_employment_status: 'active',
          suggested_termination_date: Date.current,
          will_suggest: true
        }
      end
    end

    suggestions
  end
end

