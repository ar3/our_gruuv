class OneOnOneLink < ApplicationRecord
  belongs_to :teammate

  # Validations
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :teammate_id, uniqueness: { message: "already has a one-on-one link" }

  # Instance methods
  def has_deep_integration?
    deep_integration_config.present? && deep_integration_config.any?
  end

  def asana_project_id
    deep_integration_config&.dig('asana_project_id')
  end

  def is_asana_link?
    return false unless url.present?
    url.include?('app.asana.com') || url.include?('asana.com')
  end
end

