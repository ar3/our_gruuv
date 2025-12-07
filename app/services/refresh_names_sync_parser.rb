class RefreshNamesSyncParser
  attr_reader :organization, :errors, :parsed_data

  def initialize(organization)
    @organization = organization
    @errors = []
    @parsed_data = {}
  end

  def parse
    @errors = []
    @parsed_data = {}

    begin
      # Find active company teammates (first_employed_at present, last_terminated_at nil)
      active_teammates = organization.teammates
                                      .joins(:person)
                                      .where.not(first_employed_at: nil)
                                      .where(last_terminated_at: nil)
                                      .includes(:person)

      # Find teammates where preferred_name is nil or empty string
      teammates_to_update = active_teammates.select do |teammate|
        person = teammate.person
        person.preferred_name.nil? || person.preferred_name == ''
      end

      # Build parsed data
      @parsed_data = {
        preferred_name_updates: teammates_to_update.map.with_index(1) do |teammate, index|
          person = teammate.person
          {
            row: index,
            teammate_id: teammate.id,
            person_id: person.id,
            person_name: person.display_name,
            current_preferred_name: person.preferred_name || '(empty)',
            new_preferred_name: person.first_name,
            will_update: true,
            email: person.email
          }
        end
      }

      true
    rescue => e
      @errors << "Error parsing data: #{e.message}"
      Rails.logger.error "RefreshNamesSyncParser error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  def enhanced_preview_actions
    {
      'preferred_name_updates' => parsed_data[:preferred_name_updates] || []
    }
  end
end

