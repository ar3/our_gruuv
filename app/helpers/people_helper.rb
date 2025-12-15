module PeopleHelper
  def identity_provider_icon(identity)
    case identity.provider
    when 'google_oauth2'
      'bi-google'
    when 'email'
      'bi-envelope'
    when 'slack'
      'bi-slack'
    when 'asana'
      'bi-kanban'
    else
      'bi-person'
    end
  end

  def identity_provider_name(identity)
    case identity.provider
    when 'google_oauth2'
      'Google'
    when 'email'
      'Email'
    when 'slack'
      'Slack'
    when 'asana'
      'Asana'
    else
      identity.provider.titleize
    end
  end

  def identity_status_badge(identity)
    case identity
    when PersonIdentity
      if identity.respond_to?(:google?) && identity.google?
        content_tag :span, 'Connected', class: 'badge bg-success'
      else
        content_tag :span, 'Email', class: 'badge bg-secondary'
      end
    when TeammateIdentity
      # Show workspace/organization context for teammate identities
      organization_name = identity.teammate&.organization&.display_name || 'Workspace'
      content_tag :span, organization_name, class: 'badge bg-info'
    else
      content_tag :span, 'Unknown', class: 'badge bg-secondary'
    end
  end

  def can_disconnect_identity?(identity)
    current_person.can_disconnect_identity?(identity)
  end

  def connect_google_button
    button_to connect_google_identity_path, 
              method: :post, 
              class: "btn btn-outline-primary btn-sm", 
              data: { turbo: false } do
      content_tag(:i, '', class: 'bi bi-google me-2') + 'Connect Google Account'
    end
  end

  def disconnect_identity_button(identity)
    # Only show disconnect button for person identities, not teammate identities
    return unless identity.is_a?(PersonIdentity)
    return unless can_disconnect_identity?(identity)
    
    button_to disconnect_identity_path(identity), 
              method: :delete, 
              class: "btn btn-outline-danger btn-sm",
              data: { 
                turbo: false,
                confirm: "Are you sure you want to disconnect this account? You won't be able to sign in with it anymore."
              } do
      content_tag(:i, '', class: 'bi bi-x-circle me-1') + 'Disconnect'
    end
  end

  def identity_profile_image(identity, size: 32)
    if identity.has_profile_image?
      image_tag identity.profile_image_url, 
                class: "rounded-circle", 
                style: "width: #{size}px; height: #{size}px; object-fit: cover;",
                alt: identity.name || identity.email
    else
      content_tag :div, 
                  class: "rounded-circle bg-secondary d-flex align-items-center justify-content-center text-white",
                  style: "width: #{size}px; height: #{size}px; font-size: #{size * 0.4}px;" do
        content_tag(:i, '', class: "bi #{identity_provider_icon(identity)}")
      end
    end
  end

  def identity_raw_data_display(identity)
    return unless identity.raw_data.present?
    
    content_tag :details, class: "mt-2" do
      content_tag(:summary, "View Raw Data", class: "btn btn-sm btn-outline-info") +
      content_tag(:pre, JSON.pretty_generate(identity.raw_data), class: "mt-2 p-2 bg-light rounded small")
    end
  end

  def identity_raw_data_button(identity)
    return unless identity.raw_data.present?
    
    content_tag :details, class: "d-inline-block" do
      content_tag(:summary, "View Raw Data", class: "btn btn-sm btn-outline-info") +
      content_tag(:pre, JSON.pretty_generate(identity.raw_data), class: "mt-2 p-2 bg-light rounded small")
    end
  end
  
  def slack_connection_status(person, organization)
    teammate = person.teammates.find_by(organization: organization)
    slack_identity = teammate&.slack_identity
    
    if slack_identity
      content_tag :div, class: "d-flex align-items-center" do
        content_tag(:i, '', class: "bi bi-check-circle text-success me-2") +
        content_tag(:span, "Connected to #{organization.name} Slack workspace")
      end
    else
      content_tag :div, class: "text-muted" do
        content_tag(:small, "Not connected to #{organization.name} Slack workspace")
      end
    end
  end

  def people_current_view_name
    return 'Manage Profile Mode' unless action_name
    
    # Check for check_ins controller
    if controller_name == 'check_ins' && action_name == 'show'
      return 'Check-In'
    end
    
    # Check for finalizations controller
    if controller_name == 'finalizations' && action_name == 'show'
      return 'Check-In Review'
    end
    
    # Check for position controller
    if controller_name == 'position' && action_name == 'show'
      return 'Seat History Mode'
    end
    
    case action_name.downcase
    when 'show'
      'Manage Profile Mode'
    when 'teammate'
      'Teammate View'
    when 'internal'
      'Teammate View'
    when 'public'
      'Public View'
    when 'complete_picture'
      'Active Job View'
    when 'audit'
      'Acknowledgement'
    when 'check_in'
      'Check-In'
    else
      "#{action_name.titleize} - Unknown"
    end
  end

  def check_in_status_text(check_in, person_type)
    return 'Not Started' unless check_in
    
    case person_type
    when :employee
      if check_in.employee_completed?
        "Marked Ready #{distance_of_time_in_words(check_in.employee_completed_at, Time.current)} ago"
      elsif check_in.employee_started?
        "Started / Incomplete"
      else
        'Not Started'
      end
    when :manager
      if check_in.manager_completed?
        "Marked Ready #{distance_of_time_in_words(check_in.manager_completed_at, Time.current)} ago"
      elsif check_in.manager_started?
        "Started / Incomplete"
      else
        'Not Started'
      end
    end
  end

  def last_completed_check_in(assignment_data, person)
    # Find the most recent completed check-in for this assignment
    teammate = person.teammates.find_by(organization: assignment_data[:assignment].company)
    return nil unless teammate
    
    recent_check_ins = AssignmentCheckIn
      .where(teammate: teammate, assignment: assignment_data[:assignment])
      .where.not(official_check_in_completed_at: nil)
      .order(official_check_in_completed_at: :desc)
      .limit(1)
    
    if recent_check_ins.any?
      recent_check_ins.first
    else
      nil
    end
  end

  def last_completed_check_in_date(assignment_data, person)
    # Find the most recent completed check-in for this assignment
    recent_check_in = last_completed_check_in(assignment_data, person)
    
    if recent_check_in.present?
      recent_check_in.official_check_in_completed_at.strftime('%m/%d/%Y')
    else
      'Never'
    end
  end

  def normalize_value(value)
    case value
    when nil, ''
      nil
    when String
      value.strip.empty? ? nil : value.strip
    else
      value
    end
  end

  def changes_breakdown_content
    return "No changes" if @assignment_change_data_objects.blank?
    
    content = "<div class='changes-breakdown'>"
    content += "<h6 class='mb-2'><i class='bi bi-list-ul me-1'></i>Changes Breakdown</h6>"
    
    @assignment_change_data_objects.each do |assignment_id, change_data|
      content += "<div class='mb-2'>"
      content += "<strong>#{change_data.assignment.title}</strong><br>"
      content += "<small class='text-muted'>#{change_data.assignment.company.display_name}</small><br>"
      
      changes_list = []
      
      # Add tenure changes
      change_data.tenure_changes.each do |field, new_value|
        case field
        when :anticipated_energy_percentage
          current_value = change_data.tenure&.anticipated_energy_percentage || 0
          changes_list << "• Energy: #{current_value}% → #{new_value}%"
        end
      end
      
      # Add check-in changes
      change_data.check_in_changes.each do |field, new_value|
        case field
        when :actual_energy_percentage
          current_value = change_data.current_check_in&.actual_energy_percentage || 0
          changes_list << "• Actual Energy: #{current_value}% → #{new_value}%"
        when :employee_rating
          current_value = change_data.current_check_in&.employee_rating || 'Not set'
          changes_list << "• Employee Rating: #{current_value} → #{new_value}"
        when :employee_personal_alignment
          current_value = change_data.current_check_in&.employee_personal_alignment || 'Not set'
          changes_list << "• Personal Alignment: #{current_value} → #{new_value}"
        when :employee_private_notes
          changes_list << "• Employee Notes: Updated"
        when :manager_rating
          current_value = change_data.current_check_in&.manager_rating || 'Not set'
          changes_list << "• Manager Rating: #{current_value} → #{new_value}"
        when :manager_private_notes
          changes_list << "• Manager Notes: Updated"
        end
      end
      
      # Add completion changes
      change_data.completion_changes.each do |field, value|
        case field
        when 'employee_complete'
          current_completed = change_data.current_check_in&.employee_completed? || false
          new_completed = value == 'true' || value == '1'
          changes_list << "• Employee Complete: #{current_completed ? 'Complete' : 'Incomplete'} → #{new_completed ? 'Complete' : 'Incomplete'}"
        when 'manager_complete'
          current_completed = change_data.current_check_in&.manager_completed? || false
          new_completed = value == 'true' || value == '1'
          changes_list << "• Manager Complete: #{current_completed ? 'Complete' : 'Incomplete'} → #{new_completed ? 'Complete' : 'Incomplete'}"
        end
      end
      
      if changes_list.any?
        content += "<ul class='mb-0 small'>"
        changes_list.each { |change| content += "<li>#{change}</li>" }
        content += "</ul>"
      else
        content += "<small class='text-muted'>No changes</small>"
      end
      
      content += "</div>"
    end
    
    content += "</div>"
    content.html_safe
  end
end
