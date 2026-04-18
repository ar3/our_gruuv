# frozen_string_literal: true

# Aggregates milestone mileage and gap stats for the My Growth > Abilities totals row.
class MyGrowthMileageSummary
  def self.build(teammate:, organization:, ability_rows:, current_position:, target_position:)
    org_id = organization.id
    earned = EligibilityMileageAddends.earned_for(teammate)
    total_earned = earned[:total].to_i

    milestones_scope = teammate.teammate_milestones.joins(:ability).where(abilities: { company_id: org_id })
    milestone_record_count = milestones_scope.count
    abilities_with_earned = earned[:addends].size

    certifier_counts = milestones_scope.group(:certifying_teammate_id).count
    certifier_rows = certifier_rows_from_counts(certifier_counts)

    current_bundle = current_position ? position_mileage_bundle(teammate, current_position, ability_rows, :current) : nil
    target_bundle = target_position.present? ? position_mileage_bundle(teammate, target_position, ability_rows, :target) : nil

    {
      total_earned_miles: total_earned,
      milestone_record_count: milestone_record_count,
      abilities_with_milestones_count: abilities_with_earned,
      certifier_rows: certifier_rows,
      current: current_bundle,
      target: target_bundle
    }
  end

  def self.certifier_rows_from_counts(certifier_counts)
    return [] if certifier_counts.blank?

    rows = []
    CompanyTeammate.where(id: certifier_counts.keys).includes(:person).find_each do |ct|
      next unless ct.person

      rows << { display_name: ct.person.display_name, count: certifier_counts[ct.id] }
    end
    rows.sort_by { |r| r[:display_name].downcase }
  end

  def self.position_mileage_bundle(teammate, position, ability_rows, mode)
    required_total = EligibilityMileageAddends.required_for(position)[:total].to_i
    report = PositionEligibilityService.new.check_eligibility(teammate, position)
    check = report[:checks].find { |c| c[:key] == :mileage_requirements }
    minimum = extract_minimum_miles(check)
    remainder = minimum.nil? ? 0 : [minimum - required_total, 0].max
    miles_needed_headline = minimum.present? && minimum.positive? ? minimum : required_total

    gaps = gap_stats(ability_rows, mode)

    {
      miles_needed_total: miles_needed_headline,
      required_addends_total: required_total,
      minimum_mileage_points: minimum,
      remainder_unique_miles: remainder,
      mileage_configured: check.present? && check[:status] != :not_configured,
      gap_level_sum: gaps[:gap_level_sum],
      gap_ability_count: gaps[:gap_ability_count]
    }
  end

  def self.extract_minimum_miles(check)
    return nil if check.blank? || check[:status] == :not_configured

    v = check.dig(:details, :minimum_mileage_points)
    return nil if v.blank?

    v.to_i
  end

  def self.gap_stats(ability_rows, mode)
    req_key = mode == :current ? :current : :target
    gap_level_sum = 0
    gap_ability_count = 0
    Array(ability_rows).each do |row|
      req = row[req_key]
      next unless req

      need = req[:minimum_milestone_level].to_i
      earned_max = row[:earned_levels].present? ? row[:earned_levels].map(&:to_i).max : 0
      delta = need - earned_max
      next unless delta.positive?

      gap_ability_count += 1
      gap_level_sum += delta
    end
    { gap_level_sum: gap_level_sum, gap_ability_count: gap_ability_count }
  end
  private_class_method :certifier_rows_from_counts, :position_mileage_bundle, :extract_minimum_miles, :gap_stats
end
