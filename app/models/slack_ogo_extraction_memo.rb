# frozen_string_literal: true

# Memo of Slack-message OGO extraction for a subject + context + prompt + model.
# raw_items empty => negative cache (processed, no candidate).
class SlackOgoExtractionMemo < ApplicationRecord
  belongs_to :subject_company_teammate, class_name: "CompanyTeammate"

  validates :context_fingerprint, :prompt_version, :model_id, :channel_id, :message_ts, presence: true

  def self.message_key(channel_id:, message_ts:)
    "#{channel_id}|#{message_ts}"
  end

  def message_key
    self.class.message_key(channel_id: channel_id, message_ts: message_ts)
  end

  def raw_item_list
    Array(raw_items).map { |item| item.is_a?(Hash) ? item.stringify_keys : item }
  end
end
