# frozen_string_literal: true

class CheckInPeriodBriefResult < ApplicationRecord
  belongs_to :og_consultation

  def summary_body
    (payload || {}).stringify_keys["summary_body"].to_s
  end

  def period_start_on
    (payload || {}).stringify_keys["period_start_on"]
  end

  def period_end_on
    (payload || {}).stringify_keys["period_end_on"]
  end

  def object_label
    (payload || {}).stringify_keys["object_label"].to_s
  end

  def copy_text
    output_text.to_s
  end
end
