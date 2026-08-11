# frozen_string_literal: true

# Resolves job-description HR fields with cascade:
# Seat (if present) → Title (if present) → Organization (required, never blank).
class JobDescriptionHrText
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
    resolve_seat(:seat_disclaimer) ||
      resolve_title(:job_description_disclaimer) ||
      organization.job_description_disclaimer
  end

  def work_environment
    resolve_seat(:work_environment) ||
      resolve_title(:work_environment) ||
      organization.work_environment
  end

  def physical_requirements
    resolve_seat(:physical_requirements) ||
      resolve_title(:physical_requirements) ||
      organization.physical_requirements
  end

  def travel
    resolve_seat(:travel) ||
      resolve_title(:travel) ||
      organization.travel
  end

  private

  def resolve_seat(attribute)
    return if seat.blank?

    seat.public_send(attribute).presence
  end

  def resolve_title(attribute)
    return if title.blank?

    title.public_send(attribute).presence
  end
end
