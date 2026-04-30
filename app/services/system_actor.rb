class SystemActor
  SYSTEM_EMAIL = 'automation@og.local'.freeze
  SYSTEM_FIRST_NAME = 'OG'.freeze
  SYSTEM_LAST_NAME = 'Automation'.freeze

  class << self
    def person
      Person.find_or_create_by_email!(SYSTEM_EMAIL) do |p|
        p.first_name = SYSTEM_FIRST_NAME
        p.last_name = SYSTEM_LAST_NAME
      end
    end
  end
end
