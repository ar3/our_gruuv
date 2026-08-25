# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InsightsHelper, type: :helper do
  describe '#values_insights_clarity_reveal_name?' do
    let(:company) { create(:organization, :company) }
    let(:manager) { create(:company_teammate, :assigned_employee, organization: company) }
    let(:ic) { create(:company_teammate, :assigned_employee, organization: company) }
    let(:other) { create(:company_teammate, :assigned_employee, organization: company) }
    let(:aspiration) { create(:aspiration, company: company) }
    let(:point) do
      Insights::AspirationRatingAlignmentQuery::Point.new(
        teammate: ic,
        aspiration: aspiration,
        check_in: nil,
        agreement: :all_same,
        arrow: nil
      )
    end

    before do
      create(:employment_tenure, company_teammate: ic, company: company, manager_teammate: manager)
    end

    it 'never reveals in dots mode' do
      expect(
        helper.values_insights_clarity_reveal_name?(
          point, viewer_teammate: ic, can_manage_employment: false, display: 'dots'
        )
      ).to be(false)
      expect(
        helper.values_insights_clarity_reveal_name?(
          point, viewer_teammate: manager, can_manage_employment: true, display: 'dots'
        )
      ).to be(false)
    end

    it 'in names mode reveals subject and hierarchy for non-manage-employment viewers' do
      expect(
        helper.values_insights_clarity_reveal_name?(
          point, viewer_teammate: ic, can_manage_employment: false, display: 'names'
        )
      ).to be(true)
      expect(
        helper.values_insights_clarity_reveal_name?(
          point, viewer_teammate: manager, can_manage_employment: false, display: 'names'
        )
      ).to be(true)
      expect(
        helper.values_insights_clarity_reveal_name?(
          point, viewer_teammate: other, can_manage_employment: false, display: 'names'
        )
      ).to be(false)
    end

    it 'in names mode reveals everyone when viewer can manage employment' do
      expect(
        helper.values_insights_clarity_reveal_name?(
          point, viewer_teammate: other, can_manage_employment: true, display: 'names'
        )
      ).to be(true)
    end
  end
end
