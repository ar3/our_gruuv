# frozen_string_literal: true

# Durable shared Slack pOGO candidate keyed by subject + Slack message.
# Public-channel rows are visible to anyone who can view the subject's OGOs page;
# private/DM/MPIM rows are visible only to discoverers (searchers who found them).
class SlackPossibleObservation < ApplicationRecord
  VISIBILITY_PUBLIC = "public_channel"
  VISIBILITY_PRIVATE_OR_DM = "private_or_dm"
  VISIBILITIES = [VISIBILITY_PUBLIC, VISIBILITY_PRIVATE_OR_DM].freeze

  belongs_to :organization
  belongs_to :subject_company_teammate, class_name: "CompanyTeammate",
                                        inverse_of: :slack_possible_observations_as_subject
  belongs_to :possible_observation_slack_search, optional: true
  belongs_to :possible_observation_slack_search_batch, optional: true
  belongs_to :dismissed_by_company_teammate, class_name: "CompanyTeammate", optional: true

  validates :channel_id, :message_ts, presence: true
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :channel_id, uniqueness: { scope: %i[subject_company_teammate_id message_ts] }

  scope :for_subject, ->(teammate) { where(subject_company_teammate_id: teammate.id) }
  scope :not_dismissed, -> { where(dismissed_at: nil) }
  scope :recent_first, -> { order(Arel.sql("COALESCE((payload->>'confidence')::float, 0) DESC"), created_at: :desc) }
  scope :discovered_by_search, lambda { |search_id|
    where("discovery_search_ids @> ?", [search_id.to_i].to_json)
  }

  def discovery_search_id_list
    Array(discovery_search_ids).map(&:to_i).uniq
  end

  def discovered_in_search?(search_id)
    discovery_search_id_list.include?(search_id.to_i)
  end


  def public_channel?
    visibility == VISIBILITY_PUBLIC
  end

  def private_or_dm?
    visibility == VISIBILITY_PRIVATE_OR_DM
  end

  def discoverer_ids
    Array(discoverer_company_teammate_ids).map(&:to_i).uniq
  end

  def discovered_by?(teammate)
    teammate.present? && discoverer_ids.include?(teammate.id)
  end

  def visible_to?(teammate)
    return false if teammate.nil?
    return true if public_channel?

    discovered_by?(teammate)
  end

  def dismissed?
    dismissed_at.present?
  end

  def dismiss!(by:)
    return self if dismissed?

    update!(
      dismissed_at: Time.current,
      dismissed_by_company_teammate: by
    )
  end

  def payload_hash
    (payload.is_a?(Hash) ? payload : {}).with_indifferent_access
  end

  def quote
    payload_hash[:full_quote].presence || payload_hash[:short_quote].presence || payload_hash[:quote].to_s
  end

  def summary
    payload_hash[:summary].to_s
  end

  def permalink
    payload_hash[:permalink].to_s
  end

  def confidence
    payload_hash[:confidence].to_f
  end

  def speaker_label
    payload_hash[:speaker_label].to_s
  end

  def channel_name
    payload_hash[:channel_name].to_s
  end

  def message_key
    "#{channel_id}|#{message_ts}"
  end
end
