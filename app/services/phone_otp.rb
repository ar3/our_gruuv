# frozen_string_literal: true

# Sends and verifies SMS one-time codes for phone login / verification.
# Codes live in Rails.cache (not the DB). Delivery uses NotificationAPI only.
module PhoneOtp
  CODE_TTL = 10.minutes
  CODE_LENGTH = 6
  CACHE_PREFIX = 'phone_otp:'

  class << self
    def send_code!(phone:)
      normalized = PhoneNumberNormalizer.call(phone)
      return fail_result('Enter a valid phone number.') if normalized.blank?

      code = format("%0#{CODE_LENGTH}d", SecureRandom.random_number(10**CODE_LENGTH))
      Rails.cache.write(cache_key(normalized), code, expires_in: CODE_TTL)

      if Rails.env.test? && ENV['PHONE_OTP_SKIP_SMS'] != 'false'
        return Result.new(ok: true, phone: normalized, error: nil, debug_code: code)
      end

      delivery = deliver_sms!(normalized, code)
      return fail_result(delivery[:error].presence || 'Could not send SMS.', phone: normalized) unless delivery[:success]

      Result.new(ok: true, phone: normalized, error: nil, debug_code: nil)
    end

    def verify_code!(phone:, code:)
      normalized = PhoneNumberNormalizer.call(phone)
      return fail_result('Enter a valid phone number.') if normalized.blank?

      expected = Rails.cache.read(cache_key(normalized)).to_s
      submitted = code.to_s.gsub(/\D/, '')
      valid = expected.present? &&
              submitted.present? &&
              expected.length == submitted.length &&
              ActiveSupport::SecurityUtils.secure_compare(expected, submitted)
      unless valid
        return fail_result('That code is invalid or expired. Request a new one.', phone: normalized)
      end

      Rails.cache.delete(cache_key(normalized))
      Result.new(ok: true, phone: normalized, error: nil, debug_code: nil)
    end

    private

    def cache_key(normalized_phone)
      "#{CACHE_PREFIX}#{normalized_phone}"
    end

    def deliver_sms!(normalized_phone, code)
      client_id = ENV['NOTIFICATION_API_CLIENT_ID']
      client_secret = ENV['NOTIFICATION_API_CLIENT_SECRET']
      if client_id.blank? || client_secret.blank?
        return { success: false, error: 'SMS is not configured.' }
      end

      service = NotificationApiService.new(client_id: client_id, client_secret: client_secret)
      service.send_notification(
        type: 'phone_login_otp',
        to: { id: normalized_phone, number: normalized_phone },
        sms: { message: "Your OurGruuv code is #{code}. It expires in 10 minutes." }
      )
    end

    def fail_result(message, phone: nil)
      Result.new(ok: false, phone: phone, error: message, debug_code: nil)
    end
  end

  Result = Data.define(:ok, :phone, :error, :debug_code) do
    def ok?
      ok
    end
  end
end

