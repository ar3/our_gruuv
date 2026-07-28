# frozen_string_literal: true

class AskOgResult < ApplicationRecord
  TURN_WINDOW = 5

  belongs_to :og_consultation
  has_many :ask_og_messages, -> { ordered }, dependent: :destroy, inverse_of: :ask_og_result

  validates :query, presence: true

  def next_message_position
    (ask_og_messages.maximum(:position) || 0) + 1
  end

  def messages_for_prompt(limit: TURN_WINDOW)
    ask_og_messages.ordered.last(limit)
  end

  def user_message_count
    ask_og_messages.user_messages.count
  end

  def turn_count
    ask_og_messages.count
  end

  def latest_assistant_message
    ask_og_messages.assistant_messages.ordered.last
  end

  def append_message!(role:, body:, proposed_actions: [])
    ask_og_messages.create!(
      role: role,
      body: body.to_s,
      position: next_message_position,
      proposed_actions: proposed_actions
    )
  end
end
