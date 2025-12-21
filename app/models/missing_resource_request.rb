class MissingResourceRequest < ApplicationRecord
  belongs_to :missing_resource
  belongs_to :person, optional: true

  validates :missing_resource, presence: true
  validates :ip_address, presence: true
  validates :request_count, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validate :person_or_ip_present

  scope :for_person, ->(person) { where(person: person) }
  scope :for_ip, ->(ip) { where(ip_address: ip) }
  scope :anonymous, -> { where(person_id: nil) }
  scope :authenticated, -> { where.not(person_id: nil) }
  scope :recent, -> { order(last_seen_at: :desc) }

  def increment_request_count!
    increment!(:request_count)
    touch(:last_seen_at)
  end

  def update_metadata!(user_agent:, referrer:, request_method:, query_string:)
    update!(
      user_agent: user_agent,
      referrer: referrer,
      request_method: request_method,
      query_string: query_string,
      last_seen_at: Time.current
    )
  end

  private

  def person_or_ip_present
    return if person_id.present? || ip_address.present?
    errors.add(:base, 'Either person_id or ip_address must be present')
  end
end

