# frozen_string_literal: true

# Global (per person) Start Here dashboard: active widget ids, positions, add/remove/reorder, presets.
class StartHereDashboardService
  PREFERENCE_KEY = "start_here_dashboard_widgets_v1"

  attr_reader :view, :organization, :company_teammate, :person

  def initialize(view:, organization:, company_teammate:, person:)
    @view = view
    @organization = organization
    @company_teammate = company_teammate
    @person = person
  end

  def context
    @context ||= StartHere::Widget::Context.new(
      view: view,
      organization: organization,
      company_teammate: company_teammate,
      person: person
    )
  end

  def user_preference
    @user_preference ||= UserPreference.for_person(person)
  end

  def ensure_manager_default_if_blank!
    return unless storage_blank?

    apply_preset!(:manager)
  end

  def storage_blank?
    raw = user_preference.preferences[PREFERENCE_KEY]
    raw.blank? || raw == {}
  end

  def active_widget_ids
    raw_slots.sort_by { |_id, slot| slot["position"].to_i }.map(&:first)
  end

  def active_rows
    ids = active_widget_ids
    n = ids.size
    ids.each_with_index.filter_map do |id, idx|
      w = StartHere::Widget::Registry.instance(id, context)
      next unless w.active?

      { widget: w, position: idx + 1, total: n, id: id }
    end
  end

  def inactive_widgets_by_group
    active = active_widget_ids.to_set
    by = Hash.new { |h, k| h[k] = [] }

    StartHere::Widget::Registry.widget_ids.each do |id|
      next if active.include?(id)

      w = StartHere::Widget::Registry.instance(id, context)
      next unless w.active?

      by[w.selection_group] << w
    end

    names = StartHere::Widget::GroupOrder.names
    ordered = []
    names.each do |gname|
      list = by.fetch(gname) { [] }
      ordered << [ gname, list.sort_by { |w| w.selection_title } ]
    end

    (by.keys - names).sort.each do |gname|
      ordered << [ gname, by[gname].sort_by { |w| w.selection_title } ]
    end

    ordered
  end

  def reorder!(widget_id, new_position)
    widget_id = widget_id.to_s
    order = active_widget_ids
    return unless order.include?(widget_id)

    n = order.size
    new_position = new_position.to_i.clamp(1, n)
    order.delete(widget_id)
    order.insert(new_position - 1, widget_id)
    save_order!(order)
  end

  def remove!(widget_id)
    widget_id = widget_id.to_s
    order = active_widget_ids
    order.delete(widget_id)
    save_order!(order)
  end

  def add!(widget_id)
    widget_id = widget_id.to_s
    return unless StartHere::Widget::Registry.widget_ids.include?(widget_id)

    order = active_widget_ids
    return if order.include?(widget_id)

    order << widget_id
    save_order!(order)
  end

  def apply_preset!(preset)
    ids = StartHere::Widget::Presets.widget_ids_for(preset) & StartHere::Widget::Registry.widget_ids
    save_order!(ids)
  end

  private

  def raw_slots
    h = user_preference.preferences[PREFERENCE_KEY]
    return {} unless h.is_a?(Hash)

    h.stringify_keys.transform_values do |v|
      v.is_a?(Hash) ? v.stringify_keys : v
    end
  end

  def save_order!(ordered_ids)
    slots = {}
    ordered_ids.each_with_index do |id, i|
      slots[id.to_s] = { "position" => i + 1 }
    end
    user_preference.update_preference(PREFERENCE_KEY, slots)
  end
end
