# frozen_string_literal: true

class AbilityMilestoneCalibrationItem < ApplicationRecord
  belongs_to :ability_milestone_calibration, inverse_of: :items
  belongs_to :ability
  belongs_to :awarded_by_teammate, class_name: 'CompanyTeammate', optional: true

  before_validation :normalize_unanswered_ratings

  validates :ability, presence: true
  validates :ability_id, uniqueness: { scope: :ability_milestone_calibration_id }
  # nil = not answered; 1–5 = answered proposal (current).
  validates :employee_rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :manager_rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :employee_first_rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :manager_first_rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :official_milestone_level, numericality: { only_integer: true, in: 0..5 }, allow_nil: true

  scope :ordered_by_ability_name, -> {
    joins(:ability).order(Arel.sql('LOWER(abilities.name) ASC'))
  }
  scope :ready_for_review, -> {
    where(employee_rating: 1..5).where(manager_rating: 1..5).where(awarded_at: nil)
  }
  scope :needing_award, -> { ready_for_review }
  scope :calibration_history, -> {
    where.not(awarded_at: nil)
      .where(employee_rating: 1..5)
      .where(manager_rating: 1..5)
  }
  scope :awarded_positive, -> {
    where.not(awarded_at: nil).where('official_milestone_level >= 1')
  }
  scope :not_awarded_positive, -> {
    where(awarded_at: nil).or(where(official_milestone_level: [nil, 0]))
  }

  def awarded?
    awarded_at.present?
  end

  def awarded_positive?
    awarded? && !official_milestone_level.nil? && official_milestone_level >= 1
  end

  def employee_rated?
    answered_rating?(employee_rating)
  end

  def manager_rated?
    answered_rating?(manager_rating)
  end

  def both_rated?
    employee_rated? && manager_rated?
  end

  def ready_for_review?
    both_rated? && !awarded?
  end

  def rated_for?(role)
    role.to_sym == :employee ? employee_rated? : manager_rated?
  end

  def rating_for(role)
    role.to_sym == :employee ? employee_rating : manager_rating
  end

  def other_rated_for?(role)
    role.to_sym == :employee ? manager_rated? : employee_rated?
  end

  def first_rating_for(role)
    role.to_sym == :employee ? employee_first_rating : manager_first_rating
  end

  def first_rated_at_for(role)
    role.to_sym == :employee ? employee_first_rated_at : manager_first_rated_at
  end

  def rating_changed_at_for(role)
    role.to_sym == :employee ? employee_rating_changed_at : manager_rating_changed_at
  end

  # Sets current rating; locks first_* on first answer; updates *_changed_at when value changes.
  # Does not clear — selections are not undone.
  def assign_side_rating!(role:, value:, at: Time.current)
    value = Integer(value)
    raise ArgumentError, 'Each rating must be between 1 and 5.' unless (1..5).cover?(value)

    role = role.to_sym
    rating_attr = role == :employee ? :employee_rating : :manager_rating
    first_attr = role == :employee ? :employee_first_rating : :manager_first_rating
    first_at_attr = role == :employee ? :employee_first_rated_at : :manager_first_rated_at
    changed_at_attr = role == :employee ? :employee_rating_changed_at : :manager_rating_changed_at

    current = public_send(rating_attr)
    if current == value
      return self
    end

    attrs = { rating_attr => value, changed_at_attr => at }
    if public_send(first_attr).nil?
      attrs[first_attr] = value
      attrs[first_at_attr] = at
    end

    update!(attrs)
    self
  end

  def self.answered_rating?(value)
    value.present? && value.to_i >= 1 && value.to_i <= 5
  end

  def answered_rating?(value)
    self.class.answered_rating?(value)
  end

  private

  def normalize_unanswered_ratings
    self.employee_rating = nil if employee_rating.present? && employee_rating.to_i < 1
    self.manager_rating = nil if manager_rating.present? && manager_rating.to_i < 1
  end
end
