class EmploymentStateConsistencyService
  def self.call(teammate:)
    new(teammate: teammate).call
  end

  def initialize(teammate:)
    @teammate = teammate
  end

  def call
    return Result.err('Teammate is required') unless teammate

    attrs = desired_attributes
    changed_fields = attrs.keys.select { |key| teammate.public_send(key) != attrs[key] }

    return Result.ok(changed_fields: [], attributes: attrs) if changed_fields.empty?

    teammate.update!(attrs)
    Result.ok(changed_fields: changed_fields, attributes: attrs)
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages.join(', '))
  rescue => e
    Result.err("Failed to sync employment state: #{e.message}")
  end

  private

  attr_reader :teammate

  def desired_attributes
    tenures = teammate.employment_tenures
    return { first_employed_at: teammate.first_employed_at, last_terminated_at: teammate.last_terminated_at } unless tenures.exists?

    active_tenure_exists = tenures.active.exists?
    earliest_started_at = tenures.minimum(:started_at)&.to_date
    latest_ended_at = tenures.where.not(ended_at: nil).maximum(:ended_at)&.to_date

    {
      first_employed_at: teammate.first_employed_at.presence || earliest_started_at,
      last_terminated_at: active_tenure_exists ? nil : latest_ended_at
    }
  end
end
