# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilityMilestoneCalibrationHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:casual) { teammate.person.casual_name }

  describe '#ability_milestone_calibration_source_html' do
    it 'links Position names to the position check-in page' do
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      title = create(:title, company: organization, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      position = create(:position, title: title, position_level: position_level)
      assignment = create(:assignment, company: organization, title: 'Required Assign')

      position_direct = AbilityMilestoneCalibrationAbilitiesCatalog::Source.new(
        kind: :position_direct,
        milestone_level: 2,
        assignment: nil,
        position: position,
        position_context: :current
      )
      required_assignment = AbilityMilestoneCalibrationAbilitiesCatalog::Source.new(
        kind: :required_assignment,
        milestone_level: 1,
        assignment: assignment,
        position: position,
        position_context: :current
      )

      position_path = position_check_in_organization_teammate_path(organization, teammate)
      assignment_path = organization_teammate_assignment_path(organization, teammate, assignment)

      direct_html = helper.ability_milestone_calibration_source_html(
        position_direct, organization: organization, teammate: teammate, casual: casual
      )
      expect(direct_html).to include(position.display_name)
      expect(direct_html).to include(position_path)

      required_html = helper.ability_milestone_calibration_source_html(
        required_assignment, organization: organization, teammate: teammate, casual: casual
      )
      expect(required_html).to include(position.display_name)
      expect(required_html).to include(position_path)
      expect(required_html).to include(assignment_path)
    end
  end
end
