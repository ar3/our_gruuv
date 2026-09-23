# frozen_string_literal: true

class TalentDensityStance < ApplicationRecord
  has_paper_trail

  belongs_to :company_teammate, class_name: "CompanyTeammate"
  belongs_to :company, class_name: "Organization"
  belongs_to :stance_set_by, class_name: "Person", optional: true

  has_many :comments, as: :commentable, dependent: :destroy

  enum :stance, {
    take_the_swap: "take_the_swap",
    fine_either_way: "fine_either_way",
    try_to_avoid_the_swap: "try_to_avoid_the_swap"
  }, prefix: true

  before_validation :set_company_from_teammate
  before_validation :normalize_period_month

  validates :company_teammate_id, uniqueness: { scope: :period_month }
  validates :period_month, presence: true
  validates :stance, inclusion: { in: stances.keys }, allow_nil: true
  validate :immutable_when_locked, on: :update

  scope :for_period, ->(period_month) { where(period_month: period_month.to_date.beginning_of_month) }
  scope :chronological, -> { order(period_month: :asc, id: :asc) }
  scope :newest_first, -> { order(period_month: :desc, id: :desc) }

  def self.current_period_month(time = Time.zone.now)
    time.to_date.beginning_of_month
  end

  def self.period_locked?(period_month, time: Time.zone.now)
    period_month.to_date.beginning_of_month < current_period_month(time)
  end

  # Latest reflection per teammate (any month). Returns Hash[teammate_id => stance].
  def self.latest_by_teammate_id(teammate_ids)
    ids = Array(teammate_ids).map(&:to_i).uniq
    return {} if ids.empty?

    where(company_teammate_id: ids)
      .includes(:stance_set_by)
      .newest_first
      .to_a
      .uniq(&:company_teammate_id)
      .index_by(&:company_teammate_id)
  end

  # Most recent reflection strictly before period_month, per teammate.
  def self.prior_by_teammate_id(teammate_ids, before_period:)
    ids = Array(teammate_ids).map(&:to_i).uniq
    return {} if ids.empty?

    before = before_period.to_date.beginning_of_month
    where(company_teammate_id: ids)
      .where("period_month < ?", before)
      .includes(:stance_set_by)
      .newest_first
      .to_a
      .uniq(&:company_teammate_id)
      .index_by(&:company_teammate_id)
  end

  def locked?
    self.class.period_locked?(period_month)
  end

  def open?
    !locked?
  end

  def legacy_notes?
    notes.present?
  end

  def display_name
    person = company_teammate&.person
    period = period_month&.strftime("%B %Y")
    base = if person
      person.display_name.presence || person.casual_name
    else
      "##{id}"
    end
    "Confidential Talent Reflection — #{base} (#{period})"
  end

  def record_stance_set_by!(person)
    self.stance_set_by = person
    self.stance_set_at = Time.current
  end

  private

  def set_company_from_teammate
    self.company_id ||= company_teammate&.organization_id
  end

  def normalize_period_month
    self.period_month = period_month.to_date.beginning_of_month if period_month.present?
  end

  def immutable_when_locked
    return unless locked?
    return if new_record?

    errors.add(:base, "This Confidential Talent Reflection is locked and cannot be changed")
  end
end
