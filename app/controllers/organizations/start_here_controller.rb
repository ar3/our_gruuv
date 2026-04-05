# frozen_string_literal: true

class Organizations::StartHereController < Organizations::OrganizationNamespaceBaseController
  def show
    authorize current_organization, :show?
    ensure_start_here_when_no_nav_layout!
    @start_here_dashboard = start_here_dashboard
    @start_here_dashboard.ensure_manager_default_if_blank!
  end

  def add_widget
    authorize current_organization, :show?
    id = params.require(:widget_id).to_s
    unless StartHere::Widget::Registry.widget_ids.include?(id)
      redirect_to organization_start_here_path(current_organization), alert: "Unknown widget."
      return
    end

    start_here_dashboard.add!(id)
    redirect_to organization_start_here_path(current_organization), notice: "Widget added."
  end

  def remove_widget
    authorize current_organization, :show?
    id = params.require(:widget_id).to_s
    start_here_dashboard.remove!(id)
    redirect_to organization_start_here_path(current_organization), notice: "Widget removed."
  end

  def reorder_widget
    authorize current_organization, :show?
    id = params.require(:widget_id).to_s
    pos = params.require(:position)
    start_here_dashboard.reorder!(id, pos)
    redirect_to organization_start_here_path(current_organization), notice: "Order updated."
  end

  def apply_preset
    authorize current_organization, :show?
    preset = params.require(:preset).to_sym
    unless StartHere::Widget::Presets.valid?(preset)
      redirect_to organization_start_here_path(current_organization), alert: "Unknown layout preset."
      return
    end

    start_here_dashboard.apply_preset!(preset)
    redirect_to organization_start_here_path(current_organization), notice: "Start Here layout updated."
  end

  # JSON: { "widget_ids": ["about_me", ...] } — only ids on this user’s Start Here layout are returned.
  # Rich bodies: add `app/views/organizations/start_here/widget_dashboards/_<widget_id>.html.haml` (locals: widget, context).
  def widget_dashboards
    authorize current_organization, :show?

    ids = Array(params[:widget_ids]).flatten.map(&:to_s).uniq
    allowed = start_here_dashboard.active_widget_ids.to_set
    registry = StartHere::Widget::Registry.widget_ids.to_set
    ordered = ids.select { |id| allowed.include?(id) && registry.include?(id) }

    widgets = {}
    ordered.each do |wid|
      widgets[wid] = render_widget_dashboard_json_payload(wid)
    end

    render json: { widgets: widgets }
  end

  def update_start_page
    authorize current_organization, :show?
    allowed = helpers.start_page_options_for_select(current_organization, current_company_teammate).map { |pair| pair.last.to_s }
    value = params.require(:start_page).to_s
    unless allowed.include?(value)
      redirect_to organization_start_here_path(current_organization), alert: "Invalid start page."
      return
    end

    key = helpers.start_page_preference_key(current_organization)
    UserPreference.for_person(current_person).update_preference(key, value)
    redirect_to organization_start_here_path(current_organization), notice: "Start page updated."
  end

  private

  DASHBOARD_PARTIAL_PREFIX = "organizations/start_here/widget_dashboards"

  def render_widget_dashboard_json_payload(widget_id)
    context = StartHere::Widget::Context.new(
      view: view_context,
      organization: current_organization,
      company_teammate: current_company_teammate,
      person: current_person
    )
    w = StartHere::Widget::Registry.instance(widget_id, context)
    return { ok: false, error: "This widget is not available." } unless w.active?

    partial_used = lookup_context.template_exists?(widget_id, [ DASHBOARD_PARTIAL_PREFIX ], true, [], formats: [ :html ])
    html =
      if partial_used
        render_to_string(partial: "#{DASHBOARD_PARTIAL_PREFIX}/#{widget_id}", locals: { widget: w, context: context }, formats: [ :html ])
      else
        w.dashboard_content.to_s
      end

    { ok: true, html: html }
  rescue StandardError => e
    Rails.logger.error("[StartHere#widget_dashboards] widget_id=#{widget_id.inspect} #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}")
    { ok: false, error: "Could not load this widget’s description." }
  end

  def ensure_start_here_when_no_nav_layout!
    return unless current_company_teammate
    return unless current_user_preferences.layout.to_s == "no_nav"

    key = helpers.start_page_preference_key(current_organization)
    return if current_user_preferences.preference(key).to_s == "start_here"

    current_user_preferences.update_preference(key, "start_here")
  end

  def start_here_dashboard
    @start_here_dashboard ||= StartHereDashboardService.new(
      view: view_context,
      organization: current_organization,
      company_teammate: current_company_teammate,
      person: current_person
    )
  end
end
