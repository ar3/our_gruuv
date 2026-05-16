# frozen_string_literal: true

class OgScorecardMetricThreshold < ApplicationRecord
  belongs_to :company, class_name: 'Organization'

  enum :threshold_mode, { absolute: 'absolute', percent: 'percent' }, validate: true

  validates :metric_key, presence: true, uniqueness: { scope: :company_id }
  validates :yellow_threshold, :green_threshold, numericality: { allow_nil: true }
  validate :metric_key_in_registry

  scope :for_company, ->(company) { where(company: company) }

  def configured?
    yellow_threshold.present? && green_threshold.present?
  end

  private

  def metric_key_in_registry
    return if metric_key.blank?
    return if Insights::OgScorecard::MetricRegistry.key?(metric_key)

    errors.add(:metric_key, 'is not a valid scorecard metric')
  end
end
