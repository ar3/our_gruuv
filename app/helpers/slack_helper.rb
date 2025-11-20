module SlackHelper
  def slack_configuration_status(organization)
    config = organization.calculated_slack_config
    
    if config&.configured?
      content_tag :div, class: 'alert alert-success' do
        content_tag(:strong) do
          content_tag(:i, '', class: 'bi bi-check-circle me-2') + 'Slack Connected'
        end +
        tag.br +
        content_tag(:small, class: 'text-muted') do
          "Workspace: #{config.workspace_name}" +
          (config.workspace_url ? tag.br + link_to('View in Slack', config.workspace_url, target: '_blank', class: 'text-decoration-none') : '') +
          tag.br +
          "Configured: #{config.installed_at.strftime('%B %d, %Y')}" +
          tag.br +
          "By: #{config.configured_by_name}"
        end
      end
    else
      content_tag :div, class: 'alert alert-warning' do
        content_tag(:strong) do
          content_tag(:i, '', class: 'bi bi-exclamation-triangle me-2') + 'Slack Not Connected'
        end +
        content_tag(:p, class: 'mb-0 mt-2') do
          "This organization doesn't have Slack configured yet."
        end
      end
    end
  end
  
  def teammate_association_stats(organization, total_slack_users, total_teammates, linked_teammates)
    content_tag :div, class: 'card mb-4' do
      content_tag(:div, class: 'card-header') do
        content_tag(:h5, class: 'mb-0') do
          content_tag(:i, '', class: 'bi bi-people me-2') + 'Teammate Associations'
        end
      end +
      content_tag(:div, class: 'card-body') do
        content_tag(:p) do
          "#{total_slack_users} Slack users, #{total_teammates} company teammates, #{linked_teammates} linked"
        end +
        link_to('Manage Teammate Associations', teammates_organization_slack_path(organization), class: 'btn btn-outline-primary')
      end
    end
  end
  
  def channel_association_stats(organization, total_channels, total_groups, total_departments, total_teams)
    content_tag :div, class: 'card mb-4' do
      content_tag(:div, class: 'card-header') do
        content_tag(:h5, class: 'mb-0') do
          content_tag(:i, '', class: 'bi bi-hash me-2') + 'Channel & Group Associations'
        end
      end +
      content_tag(:div, class: 'card-body') do
        content_tag(:p) do
          "#{total_channels} Slack channels, #{total_groups} Slack groups available"
        end +
        content_tag(:p, class: 'text-muted small') do
          "Organization: 1 company, #{total_departments} departments, #{total_teams} teams"
        end +
        link_to('Manage Channel & Group Associations', channels_organization_slack_path(organization), class: 'btn btn-outline-primary')
      end
    end
  end
  
  def organization_hierarchy_display(organizations)
    content_tag :table, class: 'table table-hover' do
      content_tag(:thead) do
        content_tag(:tr) do
          content_tag(:th, 'Organization') +
          content_tag(:th, 'Huddle Review Channel') +
          content_tag(:th, 'Slack Group') +
          content_tag(:th, 'Actions')
        end
      end +
      content_tag(:tbody) do
        organizations.map do |org|
          indent_level = org.ancestry_depth
          indent_px = indent_level * 20
          
          content_tag(:tr) do
            content_tag(:td, style: "padding-left: #{indent_px}px;") do
              if indent_level > 0
                content_tag(:i, '', class: 'bi bi-arrow-return-right me-2 text-muted') +
                org.name
              else
                content_tag(:strong, org.name)
              end
            end +
            content_tag(:td) do
              if org.company?
                select_tag "channel_#{org.id}",
                          options_from_collection_for_select(
                            @slack_channels,
                            :third_party_id,
                            :display_name,
                            org.huddle_review_notification_channel_id
                          ),
                          { prompt: 'Select channel', class: 'form-select form-select-sm', 
                            data: { organization_id: org.id } }
              else
                content_tag(:span, class: 'text-muted') { 'N/A' }
              end
            end +
            content_tag(:td) do
              select_tag "group_#{org.id}",
                        options_from_collection_for_select(
                          @slack_groups,
                          :third_party_id,
                          :display_name,
                          org.slack_group_id
                        ),
                        { prompt: 'Select group', class: 'form-select form-select-sm',
                          data: { organization_id: org.id } }
            end +
            content_tag(:td) do
              content_tag(:button, 'Save', class: 'btn btn-sm btn-primary', 
                         data: { organization_id: org.id })
            end
          end
        end.join.html_safe
      end
    end
  end
end

