# frozen_string_literal: true

# "+3172866905" style rows (plus + 10 digits) were kept as-is; treat as US → +1XXXXXXXXXX.
class RecanonicalizePlusTenDigitPhones < ActiveRecord::Migration[8.0]
  def up
    say_with_time 'Re-canonicalize plus+10-digit phones to +1…' do
      Person.reset_column_information
      Person.where.not(unique_textable_phone_number: [nil, '']).find_each do |person|
        normalized = PhoneNumberNormalizer.call(person.unique_textable_phone_number)
        next if normalized.blank? || normalized == person.unique_textable_phone_number

        conflict = Person.where(unique_textable_phone_number: normalized).where.not(id: person.id).exists?
        if conflict
          say "skip person #{person.id}: #{person.unique_textable_phone_number.inspect} → #{normalized} (conflict)", true
          next
        end

        person.update_columns(unique_textable_phone_number: normalized, updated_at: Time.current)
      end
    end
  end

  def down
    # Irreversible
  end
end
