# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Titles::FillMissingLevelsControl do
  let(:organization) { create(:organization) }
  let(:major) { create(:position_major_level) }
  let(:title) { create(:title, company: organization, position_major_level: major) }
  let!(:level_1) { create(:position_level, position_major_level: major, level: '3.1') }
  let!(:level_2) { create(:position_level, position_major_level: major, level: '3.2') }
  let!(:level_3) { create(:position_level, position_major_level: major, level: '3.3') }

  def attach_required_count(position, count)
    position.instance_variable_set(:@required_count, count)
  end

  describe '.for' do
    it 'returns muted when all levels are filled' do
      [level_1, level_2, level_3].each do |level|
        create(:position, title: title, position_level: level)
      end
      title.reload

      control = described_class.for(title)

      expect(control.button?).to eq(false)
      expect(control.incomplete?).to eq(false)
      expect(control.missing_count).to eq(0)
      expect(control.available_count).to eq(3)
      expect(control.message).to eq('All 3 position levels filled')
    end

    it 'returns muted when there are no positions' do
      control = described_class.for(title)

      expect(control.button?).to eq(false)
      expect(control.incomplete?).to eq(true)
      expect(control.missing_count).to eq(3)
      expect(control.message).to include('Create a position with at least 2 required assignments')
      expect(control.message).to include('3 missing')
    end

    it 'returns muted when source has 1 or fewer required assignments' do
      position = create(:position, title: title, position_level: level_1)
      attach_required_count(position, 1)
      title.reload
      title.positions.each { |p| attach_required_count(p, 1) }

      control = described_class.for(title)

      expect(control.button?).to eq(false)
      expect(control.message).to include('Source needs at least 2 required assignments')
      expect(control.message).to include('2 missing')
    end

    it 'returns a button with missing levels when source has more than one required assignment' do
      position = create(:position, title: title, position_level: level_1)
      title.reload
      title.positions.each { |p| attach_required_count(p, 2) }

      control = described_class.for(title)

      expect(control.button?).to eq(true)
      expect(control.source_position).to eq(position)
      expect(control.missing_count).to eq(2)
      expect(control.missing_levels.map(&:id)).to match_array([level_2.id, level_3.id])
    end

    it 'picks the position with the most required assignments as source' do
      pos_low = create(:position, title: title, position_level: level_1)
      pos_high = create(:position, title: title, position_level: level_2)
      title.reload
      title.positions.find { |p| p.id == pos_low.id }.tap { |p| attach_required_count(p, 2) }
      title.positions.find { |p| p.id == pos_high.id }.tap { |p| attach_required_count(p, 5) }

      control = described_class.for(title)

      expect(control.button?).to eq(true)
      expect(control.source_position.id).to eq(pos_high.id)
      expect(control.missing_count).to eq(1)
    end

    it 'on a required-count tie, picks the lowest level string' do
      pos_later = create(:position, title: title, position_level: level_2)
      pos_earlier = create(:position, title: title, position_level: level_1)
      title.reload
      title.positions.each { |p| attach_required_count(p, 3) }

      control = described_class.for(title)

      expect(control.source_position.id).to eq(pos_earlier.id)
      expect(control.missing_count).to eq(1)
    end
  end
end
