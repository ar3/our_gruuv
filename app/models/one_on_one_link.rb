class OneOnOneLink < ApplicationRecord
  belongs_to :company_teammate, class_name: 'CompanyTeammate', foreign_key: 'teammate_id'
  alias_method :teammate, :company_teammate
  alias_method :teammate=, :company_teammate=
  has_one :external_project_cache, as: :cacheable, dependent: :destroy

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

  def external_project_cache_for(source)
    external_project_cache&.source == source ? external_project_cache : nil
  end

  def has_external_project?(source)
    external_project_cache_for(source).present?
  end

  def external_project_source
    return nil unless url.present?
    ExternalProjectUrlParser.detect_source(url)
  end
end

