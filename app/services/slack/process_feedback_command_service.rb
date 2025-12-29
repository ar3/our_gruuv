module Slack
  class ProcessFeedbackCommandService
    def self.call(organization:, user_id:, channel_id:, text:)
      new(organization: organization, user_id: user_id, channel_id: channel_id, text: text).call
    end
    
    def initialize(organization:, user_id:, channel_id:, text:)
      @organization = organization
      @user_id = user_id
      @channel_id = channel_id
      @text = text || ''
      @slack_service = SlackService.new(@organization)
    end
    
    def call
      # 1. Resolve observer (the person who ran the command)
      observer_teammate = TeammateIdentity.find_teammate_by_slack_id(@user_id, @organization)
      unless observer_teammate
        return Result.err("You are not found in OurGruuv. Please ensure your Slack account is linked to your OurGruuv profile.")
      end
      
      # 2. Parse text to extract story and @mentions
      story_text, mentioned_user_ids = parse_text_and_mentions(@text)
      
      # 3. Validate story text is present
      if story_text.blank?
        return Result.err("Please provide a message for your observation. Example: `/og feedback Great work @user1 on the project!`")
      end
      
      # 4. Resolve observees from @mentions
      observee_teammates = resolve_observees(mentioned_user_ids)
      
      # 5. Create draft observation
      observation = @organization.observations.build(
        observer: observer_teammate.person,
        story: story_text,
        privacy_level: :observed_and_managers, # Default to a safe internal level
        observed_at: Time.current,
        published_at: nil # Ensure it's a draft
      )
      
      unless observation.save
        error_message = "Failed to create observation: #{observation.errors.full_messages.join(', ')}"
        return Result.err(error_message)
      end
      
      # 6. Add observees from @mentions
      observee_teammates.each do |observee_teammate|
        Observations::AddObserveeService.new(observation: observation, teammate_id: observee_teammate.id).call
      end
      
      Result.ok(observation)
    rescue => e
      error_message = "Unexpected error creating observation: #{e.message}"
      Rails.logger.error "Slack::ProcessFeedbackCommandService: #{error_message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      Result.err(error_message)
    end
    
    private
    
    def parse_text_and_mentions(text)
      # Extract Slack user IDs from mentions (format: <@U123456>)
      mentioned_user_ids = text.scan(/<@(U[A-Z0-9]+)>/).flatten
      
      # Remove mention tags from text, but keep the @username readable
      # Slack mentions come as <@U123456>, we'll replace them with @username if we can resolve them
      story_text = text.dup
      
      # Replace mentions with readable format
      mentioned_user_ids.each do |slack_user_id|
        teammate = TeammateIdentity.find_teammate_by_slack_id(slack_user_id, @organization)
        if teammate
          # Replace <@U123456> with @PersonName
          story_text.gsub!(/<@#{slack_user_id}>/, "@#{teammate.person.display_name}")
        else
          # If we can't resolve, just remove the mention tag
          story_text.gsub!(/<@#{slack_user_id}>/, '')
        end
      end
      
      # Clean up extra whitespace
      story_text = story_text.strip
      
      [story_text, mentioned_user_ids]
    end
    
    def resolve_observees(user_ids)
      user_ids.map do |slack_user_id|
        TeammateIdentity.find_teammate_by_slack_id(slack_user_id, @organization)
      end.compact
    end
  end
end

