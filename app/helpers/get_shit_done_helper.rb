module GetShitDoneHelper
  OPEN_SECTIONS = %w[
    observableMomentsSection
    checkInAcknowledgementsSection
    checkInsAwaitingInputSection
    goalCheckInsSection
    observationDraftsSection
    silentObservationsSection
    feedbackExpectationMismatchesSection
    feedbackRequestsSection
  ].freeze

  def self.sanitize_open_section(value)
    id = value.to_s
    OPEN_SECTIONS.include?(id) ? id : nil
  end

  def gsd_open_section?(section_id)
    @open_gsd_section.present? && @open_gsd_section == section_id.to_s
  end

  def gsd_collapse_class(section_id)
    gsd_open_section?(section_id) ? 'collapse show' : 'collapse'
  end

  def gsd_section_aria_expanded(section_id)
    gsd_open_section?(section_id) ? 'true' : 'false'
  end

  def organization_gsd_path(organization, open: nil)
    opts = {}
    section = GetShitDoneHelper.sanitize_open_section(open)
    opts[:open] = section if section
    organization_get_shit_done_path(organization, opts)
  end
end
