module CheckIns
  class RedirectUrlService
    def self.call(button_name:, organization:, teammate:, params: {})
      new(organization: organization, teammate: teammate, params: params).redirect_url_for(button_name)
    end

    def initialize(organization:, teammate:, params: {})
      @organization = organization
      @teammate = teammate
      @params = params
    end

    def redirect_url_for(button_name)
      # Strip 'save_and_' prefix if present for backward compatibility
      action_name = button_name.to_s.sub(/^save_and_/, '')
      
      case action_name
      when /^view_position$/
        organization_teammate_position_path(
          @organization,
          @teammate,
          return_text: @params[:return_text],
          return_url: @params[:return_url]
        )
      when /^view_assignment_(\d+)$/
        assignment_id = $1.to_i
        organization_teammate_assignment_path(
          @organization,
          @teammate,
          assignment_id
        )
      when /^view_aspiration_(\d+)$/
        aspiration_id = $1.to_i
        organization_teammate_aspiration_path(
          @organization,
          @teammate,
          aspiration_id
        )
      when /^view_observations_assignment_(\d+)$/
        assignment_id = $1.to_i
        since_date = parse_since_date(@params[:since_date])
        teammate = @params[:teammate] || @teammate
        filtered_observations_organization_observations_path(
          @organization,
          rateable_type: 'Assignment',
          rateable_id: assignment_id,
          observee_ids: [teammate.id],
          start_date: since_date,
          return_text: @params[:return_text],
          return_url: @params[:return_url]
        )
      when /^view_observations_aspiration_(\d+)$/
        aspiration_id = $1.to_i
        since_date = parse_since_date(@params[:since_date])
        teammate = @params[:teammate] || @teammate
        filtered_observations_organization_observations_path(
          @organization,
          rateable_type: 'Aspiration',
          rateable_id: aspiration_id,
          observee_ids: [teammate.id],
          start_date: since_date,
          return_text: @params[:return_text],
          return_url: @params[:return_url]
        )
      when /^view_observations_ability_(\d+)$/
        ability_id = $1.to_i
        since_date = parse_since_date(@params[:since_date])
        teammate = @params[:teammate] || @teammate
        filtered_observations_organization_observations_path(
          @organization,
          rateable_type: 'Ability',
          rateable_id: ability_id,
          observee_ids: [teammate.id],
          start_date: since_date,
          return_text: @params[:return_text],
          return_url: @params[:return_url]
        )
      when /^view_observations_position$/
        since_date = parse_since_date(@params[:since_date])
        teammate = @params[:teammate] || @teammate
        filtered_observations_organization_observations_path(
          @organization,
          observee_ids: [teammate.id],
          start_date: since_date,
          return_text: @params[:return_text],
          return_url: @params[:return_url]
        )
      when /^add_quick_note_assignment_(\d+)$/
        assignment_id = $1.to_i
        teammate = @params[:teammate] || @teammate
        new_quick_note_organization_observations_path(
          @organization,
          return_url: organization_company_teammate_check_ins_path(@organization, @teammate),
          return_text: "Check-ins",
          observee_ids: [teammate.id],
          rateable_type: 'Assignment',
          rateable_id: assignment_id
        )
      when /^add_quick_note_aspiration_(\d+)$/
        aspiration_id = $1.to_i
        teammate = @params[:teammate] || @teammate
        new_quick_note_organization_observations_path(
          @organization,
          return_url: organization_company_teammate_check_ins_path(@organization, @teammate),
          return_text: "Check-ins",
          observee_ids: [teammate.id],
          rateable_type: 'Aspiration',
          rateable_id: aspiration_id
        )
      when /^add_quick_note_ability_(\d+)$/
        ability_id = $1.to_i
        teammate = @params[:teammate] || @teammate
        new_quick_note_organization_observations_path(
          @organization,
          return_url: organization_company_teammate_check_ins_path(@organization, @teammate),
          return_text: "Check-ins",
          observee_ids: [teammate.id],
          rateable_type: 'Ability',
          rateable_id: ability_id
        )
      when /^add_quick_note_position$/
        teammate = @params[:teammate] || @teammate
        new_quick_note_organization_observations_path(
          @organization,
          return_url: organization_company_teammate_check_ins_path(@organization, @teammate),
          return_text: "Check-ins",
          observee_ids: [teammate.id]
        )
      else
        # Default to finalization page
        organization_company_teammate_finalization_path(@organization, @teammate)
      end
    end

    private

    def organization_teammate_position_path(*args)
      Rails.application.routes.url_helpers.organization_teammate_position_path(*args)
    end

    def organization_teammate_assignment_path(*args)
      Rails.application.routes.url_helpers.organization_teammate_assignment_path(*args)
    end

    def organization_teammate_aspiration_path(*args)
      Rails.application.routes.url_helpers.organization_teammate_aspiration_path(*args)
    end

    def filtered_observations_organization_observations_path(*args)
      Rails.application.routes.url_helpers.filtered_observations_organization_observations_path(*args)
    end

    def new_quick_note_organization_observations_path(*args)
      Rails.application.routes.url_helpers.new_quick_note_organization_observations_path(*args)
    end

    def organization_company_teammate_check_ins_path(*args)
      Rails.application.routes.url_helpers.organization_company_teammate_check_ins_path(*args)
    end

    def organization_company_teammate_finalization_path(*args)
      Rails.application.routes.url_helpers.organization_company_teammate_finalization_path(*args)
    end

    def parse_since_date(since_date_param)
      return 1.year.ago unless since_date_param.present?
      
      if since_date_param.is_a?(String)
        # Try to parse as date
        Date.parse(since_date_param) rescue 1.year.ago
      elsif since_date_param.respond_to?(:to_date)
        since_date_param.to_date
      else
        1.year.ago
      end
    end
  end
end
