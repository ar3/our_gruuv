# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GroupAvatarHelper, type: :helper do
  let(:company) { create(:organization, name: 'Acme Corp') }

  describe '#group_avatar_initials' do
    it 'uses the first letters of the name' do
      expect(helper.group_avatar_initials(company)).to eq('AC')
    end

    it 'uses only the department name, not parent hierarchy' do
      parent = create(:department, company: company, name: 'Engineering')
      child = create(:department, company: company, name: 'Platform Squad', parent_department: parent)
      expect(helper.group_avatar_initials(child)).to eq('PS')
    end
  end

  describe '#group_avatar' do
    it 'falls back to initials when no image is attached' do
      department = create(:department, company: company, name: 'Sales Ops')
      result = helper.group_avatar(department, size: 48)

      expect(result).to include('SO')
      expect(result).to include('rounded-circle')
      expect(result).to include('bg-secondary')
    end

    it 'uses the company logo when attached' do
      company.logo.attach(
        io: StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/logo.png'))),
        filename: 'logo.png',
        content_type: 'image/png'
      )
      result = helper.group_avatar(company, size: 40)

      expect(result).to include('rounded-circle')
      expect(result).to include('40px')
      expect(result).to include('img')
      expect(result).not_to include('bg-secondary')
    end

    it 'uses a department profile image when attached' do
      department = create(:department, company: company, name: 'Sales')
      department.profile_image.attach(
        io: StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/logo.png'))),
        filename: 'dept.png',
        content_type: 'image/png'
      )
      result = helper.group_avatar(department, size: 48)

      expect(result).to include('img')
      expect(result).to include('rounded-circle')
      expect(result).not_to include('bg-secondary')
    end

    it 'uses a team profile image when attached' do
      team = create(:team, company: company, name: 'Alpha Team')
      team.profile_image.attach(
        io: StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/logo.png'))),
        filename: 'team.png',
        content_type: 'image/png'
      )
      result = helper.group_avatar(team, size: 32)

      expect(result).to include('img')
      expect(result).to include('32px')
      expect(result).not_to include('AT')
    end
  end

  describe '#organization_initials_circle' do
    it 'returns a div with initials' do
      result = helper.organization_initials_circle('AB', size: 48)

      expect(result).to include('AB')
      expect(result).to include('rounded-circle')
      expect(result).to include('bg-secondary')
      expect(result).to include('48px')
    end
  end
end
