require 'rails_helper'

RSpec.describe TimezoneService do
  describe '.valid_timezone?' do
    it 'returns true for valid timezones' do
      expect(TimezoneService.valid_timezone?('Eastern Time (US & Canada)')).to be true
      expect(TimezoneService.valid_timezone?('Pacific Time (US & Canada)')).to be true
      expect(TimezoneService.valid_timezone?('London')).to be true
    end

    it 'returns false for invalid timezones' do
      expect(TimezoneService.valid_timezone?('Invalid/Timezone')).to be false
      expect(TimezoneService.valid_timezone?('')).to be false
      expect(TimezoneService.valid_timezone?(nil)).to be false
    end
  end

  describe '.ensure_valid_timezone' do
    it 'returns the timezone if valid' do
      expect(TimezoneService.ensure_valid_timezone('Eastern Time (US & Canada)')).to eq('Eastern Time (US & Canada)')
    end

    it 'returns default timezone if blank' do
      expect(TimezoneService.ensure_valid_timezone('')).to eq(TimezoneService::DEFAULT_TIMEZONE)
      expect(TimezoneService.ensure_valid_timezone(nil)).to eq(TimezoneService::DEFAULT_TIMEZONE)
    end

    it 'returns default timezone if invalid' do
      expect(TimezoneService.ensure_valid_timezone('Invalid/Timezone')).to eq(TimezoneService::DEFAULT_TIMEZONE)
    end
  end

  describe '.detect_from_request' do
    let(:request) { double('request') }

    it 'returns default timezone when no Accept-Language header' do
      allow(request).to receive(:headers).and_return({})
      expect(TimezoneService.detect_from_request(request)).to eq(TimezoneService::DEFAULT_TIMEZONE)
    end

    it 'maps en-US to Eastern Time' do
      allow(request).to receive(:headers).and_return('Accept-Language' => 'en-US,en;q=0.9')
      expect(TimezoneService.detect_from_request(request)).to eq('Eastern Time (US & Canada)')
    end

    it 'maps en-GB to London' do
      allow(request).to receive(:headers).and_return('Accept-Language' => 'en-GB,en;q=0.9')
      expect(TimezoneService.detect_from_request(request)).to eq('London')
    end

    it 'returns default timezone for unknown locale' do
      allow(request).to receive(:headers).and_return('Accept-Language' => 'xx-XX')
      expect(TimezoneService.detect_from_request(request)).to eq(TimezoneService::DEFAULT_TIMEZONE)
    end
  end

  describe '.map_locale_to_timezone' do
    it 'maps common locales correctly' do
      expect(TimezoneService.map_locale_to_timezone('en-US')).to eq('Eastern Time (US & Canada)')
      expect(TimezoneService.map_locale_to_timezone('en-GB')).to eq('London')
      expect(TimezoneService.map_locale_to_timezone('fr-FR')).to eq('Paris')
      expect(TimezoneService.map_locale_to_timezone('es-MX')).to eq('Central Time (US & Canada)')
    end

    it 'returns nil for unknown locales' do
      expect(TimezoneService.map_locale_to_timezone('xx-XX')).to be_nil
      expect(TimezoneService.map_locale_to_timezone(nil)).to be_nil
    end
  end

  describe '.valid_timezones' do
    it 'returns an array of valid timezone names' do
      timezones = TimezoneService.valid_timezones
      expect(timezones).to be_an(Array)
      expect(timezones).to include('Eastern Time (US & Canada)')
      expect(timezones).to include('Pacific Time (US & Canada)')
      expect(timezones).to include('London')
    end
  end

  describe '.timezone_options' do
    it 'returns timezone options for select dropdowns' do
      options = TimezoneService.timezone_options
      expect(options).to be_an(Array)
      expect(options.first).to be_an(Array)
      expect(options.first.length).to eq(2)
    end
  end

  describe '.format_time' do
    let(:time) { Time.zone.parse('2025-07-21 14:30:00 UTC') }

    it 'formats time in the specified timezone' do
      formatted = TimezoneService.format_time(time, 'Eastern Time (US & Canada)')
      expect(formatted).to include('EDT')
      expect(formatted).to include('10:30 AM')
    end

    it 'handles invalid timezones by defaulting to Eastern' do
      formatted = TimezoneService.format_time(time, 'Invalid/Timezone')
      expect(formatted).to include('EDT')
      expect(formatted).to include('10:30 AM')
    end
  end
end 