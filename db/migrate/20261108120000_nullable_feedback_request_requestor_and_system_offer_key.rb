# frozen_string_literal: true

class NullableFeedbackRequestRequestorAndSystemOfferKey < ActiveRecord::Migration[8.0]
  def change
    change_column_null :feedback_requests, :requestor_teammate_id, true

    add_column :feedback_requests, :system_offer_key, :string

    add_index :feedback_requests,
              [:company_id, :subject_of_feedback_teammate_id, :system_offer_key],
              unique: true,
              where: "system_offer_key IS NOT NULL AND deleted_at IS NULL",
              name: "index_feedback_requests_on_system_offer_key_unique"
  end
end
