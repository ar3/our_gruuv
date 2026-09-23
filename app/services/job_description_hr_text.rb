# frozen_string_literal: true

# Resolves job-description HR fields with cascade:
# Seat (if present) → Title (if present) → Organization → OG defaults.
class JobDescriptionHrText
  GROUP_NAME = "Job Description HR fields"

  DEFAULT_DISCLAIMER =
    "This job description is not designed to cover or contain a comprehensive list of duties " \
    "or responsibilities. Duties may change or new ones may be assigned at any time."

  DEFAULT_WORK_ENVIRONMENT =
    "Prolonged periods of sitting at a desk and working on a computer."

  DEFAULT_PHYSICAL_REQUIREMENTS =
    "While performing the duties of this job, the employee may be regularly required to stand, sit, talk, " \
    "hear, and use hands and fingers to operate a computer and keyboard. Specific vision abilities " \
    "required by this job include close vision requirements due to computer work."

  DEFAULT_TRAVEL = "Travel is on a voluntary basis."

  DEFAULTS = {
    job_description_disclaimer: DEFAULT_DISCLAIMER,
    work_environment: DEFAULT_WORK_ENVIRONMENT,
    physical_requirements: DEFAULT_PHYSICAL_REQUIREMENTS,
    travel: DEFAULT_TRAVEL
  }.freeze

  FIELDS = [
    {
      key: :disclaimer,
      label: "Disclaimer",
      seat_attribute: :seat_disclaimer,
      title_attribute: :job_description_disclaimer,
      organization_attribute: :job_description_disclaimer,
      default_key: :job_description_disclaimer
    },
    {
      key: :work_environment,
      label: "Work environment",
      seat_attribute: :work_environment,
      title_attribute: :work_environment,
      organization_attribute: :work_environment,
      default_key: :work_environment
    },
    {
      key: :physical_requirements,
      label: "Physical requirements",
      seat_attribute: :physical_requirements,
      title_attribute: :physical_requirements,
      organization_attribute: :physical_requirements,
      default_key: :physical_requirements
    },
    {
      key: :travel,
      label: "Travel",
      seat_attribute: :travel,
      title_attribute: :travel,
      organization_attribute: :travel,
      default_key: :travel
    }
  ].freeze

  Node = Struct.new(:key, :label, :state, :edit_path, :note, :fields_using, keyword_init: true)
  FieldResolution = Struct.new(:key, :label, :value, :source_key, :nodes, keyword_init: true)

  attr_reader :organization, :title, :seat

  def self.for(organization:, title: nil, seat: nil)
    new(organization: organization, title: title, seat: seat)
  end

  def initialize(organization:, title: nil, seat: nil)
    @organization = organization
    @title = title || seat&.title
    @seat = seat
  end

  def disclaimer
    field_value(:disclaimer)
  end

  def work_environment
    field_value(:work_environment)
  end

  def physical_requirements
    field_value(:physical_requirements)
  end

  def travel
    field_value(:travel)
  end

  def field_resolutions
    FIELDS.map { |field| resolve_field(field) }
  end

  # One cascade for the whole HR field group (Seat → Title → Organization → OG defaults).
  def source_cascade
    resolutions = field_resolutions
    using_by_layer = resolutions.group_by(&:source_key)

    [
      seat_cascade_node(using_by_layer),
      title_cascade_node(using_by_layer),
      organization_cascade_node(using_by_layer),
      og_defaults_cascade_node(using_by_layer)
    ]
  end

  private

  def field_value(key)
    resolve_field(FIELDS.find { |field| field[:key] == key }).value
  end

  def resolve_field(field)
    seat_value = seat_layer_value(field)
    title_value = title_layer_value(field)
    organization_value = organization_layer_value(field)
    default_value = DEFAULTS.fetch(field[:default_key])

    source_key =
      if seat_value.present?
        :seat
      elsif title_value.present?
        :title
      elsif organization_value.present?
        :organization
      else
        :og_defaults
      end

    value =
      case source_key
      when :seat then seat_value
      when :title then title_value
      when :organization then organization_value
      else default_value
      end

    FieldResolution.new(
      key: field[:key],
      label: field[:label],
      value: value,
      source_key: source_key,
      nodes: [
        seat_node(source_key, seat_value),
        title_node(source_key, title_value),
        organization_node(source_key, organization_value),
        og_defaults_node(source_key)
      ]
    )
  end

  def seat_layer_value(field)
    return if seat.blank?

    seat.public_send(field[:seat_attribute]).presence
  end

  def title_layer_value(field)
    return if title.blank?

    title.public_send(field[:title_attribute]).presence
  end

  def organization_layer_value(field)
    organization.public_send(field[:organization_attribute]).presence
  end

  def layer_has_any_value?(layer_key)
    FIELDS.any? do |field|
      case layer_key
      when :seat then seat_layer_value(field).present?
      when :title then title_layer_value(field).present?
      when :organization then organization_layer_value(field).present?
      else false
      end
    end
  end

  def using_labels(using_by_layer, layer_key)
    Array(using_by_layer[layer_key]).map(&:label)
  end

  def seat_cascade_node(using_by_layer)
    if seat.blank?
      return Node.new(
        key: :seat,
        label: "Seat",
        state: :na,
        edit_path: nil,
        note: "Seat can be configured for a teammate; teammate job description pages will use that seat when set.",
        fields_using: []
      )
    end

    fields_using = using_labels(using_by_layer, :seat)
    if fields_using.any?
      Node.new(key: :seat, label: "Seat", state: :using, edit_path: nil, note: nil, fields_using: fields_using)
    else
      Node.new(key: :seat, label: "Seat", state: :does_not_exist, edit_path: :seat, note: nil, fields_using: [])
    end
  end

  def title_cascade_node(using_by_layer)
    if title.blank?
      return Node.new(
        key: :title,
        label: "Title",
        state: :na,
        edit_path: nil,
        note: "No title is available for this job description.",
        fields_using: []
      )
    end

    fields_using = using_labels(using_by_layer, :title)
    if fields_using.any?
      Node.new(key: :title, label: "Title", state: :using, edit_path: nil, note: nil, fields_using: fields_using)
    elsif layer_has_any_value?(:title)
      Node.new(key: :title, label: "Title", state: :not_used, edit_path: nil, note: nil, fields_using: [])
    else
      Node.new(key: :title, label: "Title", state: :does_not_exist, edit_path: :title, note: nil, fields_using: [])
    end
  end

  def organization_cascade_node(using_by_layer)
    fields_using = using_labels(using_by_layer, :organization)
    if fields_using.any?
      Node.new(key: :organization, label: "Organization", state: :using, edit_path: nil, note: nil, fields_using: fields_using)
    elsif layer_has_any_value?(:organization)
      Node.new(key: :organization, label: "Organization", state: :not_used, edit_path: nil, note: nil, fields_using: [])
    else
      Node.new(key: :organization, label: "Organization", state: :does_not_exist, edit_path: :organization, note: nil, fields_using: [])
    end
  end

  def og_defaults_cascade_node(using_by_layer)
    fields_using = using_labels(using_by_layer, :og_defaults)
    if fields_using.any?
      Node.new(key: :og_defaults, label: "OG defaults", state: :using, edit_path: nil, note: nil, fields_using: fields_using)
    else
      Node.new(key: :og_defaults, label: "OG defaults", state: :not_used, edit_path: nil, note: nil, fields_using: [])
    end
  end

  # Per-field node helpers (kept for field_resolutions consumers / specs).
  def seat_node(chosen_key, _seat_value)
    if seat.blank?
      return Node.new(
        key: :seat,
        label: "Seat",
        state: :na,
        edit_path: nil,
        note: "Seat can be configured for a teammate; teammate job description pages will use that seat when set.",
        fields_using: []
      )
    end

    if chosen_key == :seat
      Node.new(key: :seat, label: "Seat", state: :chosen, edit_path: nil, note: nil, fields_using: [])
    else
      Node.new(key: :seat, label: "Seat", state: :undefined, edit_path: :seat, note: nil, fields_using: [])
    end
  end

  def title_node(chosen_key, _title_value)
    if title.blank?
      return Node.new(
        key: :title,
        label: "Title",
        state: :na,
        edit_path: nil,
        note: "No title is available for this job description.",
        fields_using: []
      )
    end

    case chosen_key
    when :title
      Node.new(key: :title, label: "Title", state: :chosen, edit_path: nil, note: nil, fields_using: [])
    when :seat
      Node.new(key: :title, label: "Title", state: :skipped, edit_path: nil, note: nil, fields_using: [])
    else
      Node.new(key: :title, label: "Title", state: :undefined, edit_path: :title, note: nil, fields_using: [])
    end
  end

  def organization_node(chosen_key, _organization_value)
    case chosen_key
    when :organization
      Node.new(key: :organization, label: "Organization", state: :chosen, edit_path: nil, note: nil, fields_using: [])
    when :seat, :title
      Node.new(key: :organization, label: "Organization", state: :skipped, edit_path: nil, note: nil, fields_using: [])
    else
      Node.new(key: :organization, label: "Organization", state: :undefined, edit_path: :organization, note: nil, fields_using: [])
    end
  end

  def og_defaults_node(chosen_key)
    if chosen_key == :og_defaults
      Node.new(key: :og_defaults, label: "OG defaults", state: :chosen, edit_path: nil, note: nil, fields_using: [])
    else
      Node.new(key: :og_defaults, label: "OG defaults", state: :skipped, edit_path: nil, note: nil, fields_using: [])
    end
  end
end
