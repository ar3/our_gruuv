class MissingResourcesController < ApplicationController
  def index
    @pagy, @missing_resources = pagy(MissingResource.most_requested, items: 50)
  end

  def requests_index
    @pagy, @missing_resource_requests = pagy(
      MissingResourceRequest.includes(:missing_resource, :person).recent,
      items: 50
    )
  end

  def show
    @path = params[:path] || request.path
    @suggestions = generate_suggestions(@path)

    # Track the missing resource request
    track_missing_resource

    respond_to do |format|
      format.html { render status: :not_found }
      format.json { render json: { error: 'Not found', path: @path, suggestions: @suggestions }, status: :not_found }
    end
  end

  private

  def track_missing_resource
    person_id = current_person&.id
    ip_address = request.remote_ip
    user_agent = request.user_agent
    referrer = request.referer
    request_method = request.method
    query_string = request.query_string.presence

    # Call job synchronously with perform_and_get_result
    TrackMissingResourceJob.perform_and_get_result(
      @path,
      person_id,
      ip_address,
      user_agent,
      referrer,
      request_method,
      query_string
    )
  rescue => e
    # Don't let tracking errors break the 404 page
    Rails.logger.error "Failed to track missing resource: #{e.message}"
  end

  def generate_suggestions(path)
    suggestions = []

    # Parse path segments
    segments = path.split('/').reject(&:blank?)

    # Common pattern matching
    if path.include?('/our/explore/choose_roles') || path.include?('choose_roles')
      if current_organization
        suggestions << {
          title: 'Employees',
          path: organization_employees_path(current_organization),
          description: 'View and manage employees in your organization'
        }
      end
    end

    # Match against common route patterns
    if segments.include?('employees') || segments.include?('people')
      if current_organization
        suggestions << {
          title: 'Employees',
          path: organization_employees_path(current_organization),
          description: 'View and manage employees'
        }
      end
    end

    if segments.include?('huddles') || segments.include?('huddle')
      suggestions << {
        title: 'Huddles',
        path: huddles_path,
        description: 'View and manage huddles'
      }
      if current_organization
        suggestions << {
          title: 'Huddles Overview',
          path: huddles_overview_path,
          description: 'Overview of huddles'
        }
      end
    end

    if segments.include?('assignments')
      if current_organization
        suggestions << {
          title: 'Assignments',
          path: organization_assignments_path(current_organization),
          description: 'View and manage assignments'
        }
      end
    end

    if segments.include?('goals')
      if current_organization
        suggestions << {
          title: 'Goals',
          path: organization_goals_path(current_organization),
          description: 'View and manage goals'
        }
      end
    end

    if segments.include?('observations')
      if current_organization
        suggestions << {
          title: 'Observations',
          path: organization_observations_path(current_organization),
          description: 'View and manage observations'
        }
      end
    end

    # If user is logged in, suggest their organization dashboard
    if current_organization
      suggestions << {
        title: 'Dashboard',
        path: dashboard_organization_path(current_organization),
        description: 'Go to your organization dashboard'
      }
    end

    # Always suggest home page
    suggestions << {
      title: 'Home',
      path: root_path,
      description: 'Return to the home page'
    }

    # Remove duplicates based on path
    suggestions.uniq { |s| s[:path] }
  end
end

