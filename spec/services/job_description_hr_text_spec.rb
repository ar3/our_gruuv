# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobDescriptionHrText do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:seat) { create(:seat, title: title) }

  describe 'defaults seeded on organization' do
    it 'seeds job description HR fields when creating an organization' do
      org = create(:organization)
      expect(org.job_description_disclaimer).to eq(JobDescriptionHrText::DEFAULT_DISCLAIMER)
      expect(org.work_environment).to eq(JobDescriptionHrText::DEFAULT_WORK_ENVIRONMENT)
      expect(org.physical_requirements).to eq(JobDescriptionHrText::DEFAULT_PHYSICAL_REQUIREMENTS)
      expect(org.travel).to eq(JobDescriptionHrText::DEFAULT_TRAVEL)
    end

    it 'rejects blank org HR fields' do
      organization.job_description_disclaimer = ''
      expect(organization).not_to be_valid
      expect(organization.errors[:job_description_disclaimer]).to be_present
    end
  end

  describe '.for cascade' do
    it 'uses organization when title and seat are blank' do
      organization.update!(work_environment: 'Org work env')
      hr = described_class.for(organization: organization)

      expect(hr.work_environment).to eq('Org work env')
      expect(hr.disclaimer).to eq(organization.job_description_disclaimer)
    end

    it 'uses title over organization when title value present' do
      organization.update!(work_environment: 'Org work env')
      title.update!(work_environment: 'Title work env')
      hr = described_class.for(organization: organization, title: title)

      expect(hr.work_environment).to eq('Title work env')
    end

    it 'inherits org from title when title field is blank' do
      organization.update!(travel: 'Org travel')
      title.update!(travel: nil)
      hr = described_class.for(organization: organization, title: title)

      expect(hr.travel).to eq('Org travel')
    end

    it 'uses seat over title and organization' do
      organization.update!(physical_requirements: 'Org physical')
      title.update!(physical_requirements: 'Title physical')
      seat.update!(physical_requirements: 'Seat physical')
      hr = described_class.for(organization: organization, title: title, seat: seat)

      expect(hr.physical_requirements).to eq('Seat physical')
    end

    it 'falls back seat blank → title → org for disclaimer (seat_disclaimer attr)' do
      organization.update!(job_description_disclaimer: 'Org disclaimer')
      title.update!(job_description_disclaimer: 'Title disclaimer')
      seat.update!(seat_disclaimer: nil)
      hr = described_class.for(organization: organization, title: title, seat: seat)

      expect(hr.disclaimer).to eq('Title disclaimer')
    end

    it 'falls back seat blank + title blank → org' do
      organization.update!(travel: 'Org only travel')
      title.update!(travel: nil)
      seat.update!(travel: nil)
      hr = described_class.for(organization: organization, title: title, seat: seat)

      expect(hr.travel).to eq('Org only travel')
    end

    it 'falls back to OG defaults when organization value is blank' do
      organization.write_attribute(:travel, nil)
      hr = described_class.for(organization: organization)

      expect(hr.travel).to eq(described_class::DEFAULT_TRAVEL)
      travel = hr.field_resolutions.find { |resolution| resolution.key == :travel }
      expect(travel.source_key).to eq(:og_defaults)
    end

    it 'resolves fields independently' do
      organization.update!(work_environment: 'Org env', travel: 'Org travel')
      title.update!(work_environment: 'Title env', travel: nil)
      seat.update!(work_environment: nil, travel: 'Seat travel')
      hr = described_class.for(organization: organization, title: title, seat: seat)

      expect(hr.work_environment).to eq('Title env')
      expect(hr.travel).to eq('Seat travel')
    end
  end

  describe '#source_cascade' do
    it 'marks seat N/A and organization using when only org has values' do
      organization.update!(work_environment: 'Org work env')
      hr = described_class.for(organization: organization, title: title)

      expect(hr.source_cascade.map { |node| [node.key, node.state] }).to eq(
        [
          [:seat, :na],
          [:title, :does_not_exist],
          [:organization, :using],
          [:og_defaults, :not_used]
        ]
      )
    end

    it 'marks seat using and more-specific overrides when seat has values' do
      organization.update!(
        job_description_disclaimer: 'Org disclaimer',
        work_environment: 'Org env',
        physical_requirements: 'Org physical',
        travel: 'Org travel'
      )
      title.update!(
        job_description_disclaimer: 'Title disclaimer',
        work_environment: 'Title env',
        physical_requirements: 'Title physical',
        travel: 'Title travel'
      )
      seat.update!(
        seat_disclaimer: 'Seat disclaimer',
        work_environment: 'Seat env',
        physical_requirements: 'Seat physical',
        travel: 'Seat travel'
      )
      hr = described_class.for(organization: organization, title: title, seat: seat)

      expect(hr.source_cascade.map { |node| [node.key, node.state] }).to eq(
        [
          [:seat, :using],
          [:title, :not_used],
          [:organization, :not_used],
          [:og_defaults, :not_used]
        ]
      )
    end

    it 'marks layers using for only the fields they supply when sources are mixed' do
      organization.update!(work_environment: 'Org env', travel: 'Org travel')
      title.update!(work_environment: 'Title env', travel: nil)
      seat.update!(work_environment: nil, travel: 'Seat travel')
      hr = described_class.for(organization: organization, title: title, seat: seat)

      cascade = hr.source_cascade.index_by(&:key)
      expect(cascade[:seat].state).to eq(:using)
      expect(cascade[:seat].fields_using).to eq(['Travel'])
      expect(cascade[:title].state).to eq(:using)
      expect(cascade[:title].fields_using).to include('Work environment')
      expect(cascade[:organization].state).to eq(:using)
    end

    it 'falls back cascade to OG defaults when organization value is blank' do
      organization.write_attribute(:travel, nil)
      organization.write_attribute(:work_environment, nil)
      organization.write_attribute(:physical_requirements, nil)
      organization.write_attribute(:job_description_disclaimer, nil)
      hr = described_class.for(organization: organization)

      expect(hr.source_cascade.map { |node| [node.key, node.state] }).to eq(
        [
          [:seat, :na],
          [:title, :na],
          [:organization, :does_not_exist],
          [:og_defaults, :using]
        ]
      )
    end
  end
end
