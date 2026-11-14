# frozen_string_literal: true

class ProtectFlowNudgeResult < ApplicationRecord
  belongs_to :og_consultation

  def draft_body
    output_text.to_s.presence || (payload || {}).stringify_keys["draft_body"].to_s
  end
end
