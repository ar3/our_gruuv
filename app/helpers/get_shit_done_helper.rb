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

  def check_in_warning_event_path(organization, event)
    subject = event.subject_teammate
    case event.entity_type
    when 'Assignment'
      organization_teammate_assignment_path(organization, subject, event.entity)
    when 'Position'
      position_check_in_organization_teammate_path(organization, subject)
    when 'Aspiration'
      organization_teammate_aspiration_path(organization, subject, event.entity)
    else
      hub_organization_company_teammate_check_ins_path(organization, subject)
    end
  end
end
