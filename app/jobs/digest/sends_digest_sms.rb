# frozen_string_literal: true

module Digest
  # Shared SMS delivery for digest jobs. Sends a short summary to the employee's
  # phone when the SMS channel is on and a textable phone number is present.
  module SendsDigestSms
    private

    # The message is built lazily (via block) since builders can run expensive queries.
    def send_digest_sms(person, prefs, type:)
      return if person.unique_textable_phone_number.blank?
      return unless prefs.effective_digest_sms(person) == 'on'

      client_id = ENV['NOTIFICATION_API_CLIENT_ID']
      client_secret = ENV['NOTIFICATION_API_CLIENT_SECRET']
      return if client_id.blank? || client_secret.blank?

      service = NotificationApiService.new(client_id: client_id, client_secret: client_secret)
      result = service.send_notification(
        type: type,
        to: { id: person.email, number: person.unique_textable_phone_number },
        sms: { message: yield }
      )
      unless result[:success]
        Rails.logger.warn "#{self.class.name}: SMS failed for person #{person.id}: #{result[:error]}"
      end
    end
  end
end
