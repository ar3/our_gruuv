require 'rails_helper'

RSpec.describe 'Organizations::FeedbackRequests Subject Selection', type: :request do
  let(:company) { create(:organization) }
  let(:manager_person) { create(:person) }
  let(:manager_teammate) do
    CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) do |t|
      t.organization = company
      t.first_employed_at = 1.year.ago
    end
  end
  
  let(:direct_report_person) { create(:person) }
  let(:direct_report_teammate) do
    CompanyTeammate.find_or_create_by!(person: direct_report_person, organization: company) do |t|
      t.organization = company
      t.first_employed_at = 6.months.ago
    end
  end
  
  let(:indirect_report_person) { create(:person) }
  let(:indirect_report_teammate) do
    CompanyTeammate.find_or_create_by!(person: indirect_report_person, organization: company) do |t|
      t.organization = company
      t.first_employed_at = 3.months.ago
    end
  end
  
  let(:unrelated_person) { create(:person) }
  let(:unrelated_teammate) do
    CompanyTeammate.find_or_create_by!(person: unrelated_person, organization: company) do |t|
      t.organization = company
      t.first_employed_at = 1.year.ago
    end
  end
  
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:manager_tenure) do
    create(:employment_tenure,
      teammate: manager_teammate,
      company: company,
      position: position,
      manager_teammate: nil,
      started_at: 1.year.ago
    )
  end
  
  let(:direct_report_tenure) do
    create(:employment_tenure,
      teammate: direct_report_teammate,
      company: company,
      position: position,
      manager_teammate: manager_teammate,
      started_at: 6.months.ago
    )
  end
  
  let(:indirect_report_tenure) do
    create(:employment_tenure,
      teammate: indirect_report_teammate,
      company: company,
      position: position,
      manager_teammate: direct_report_teammate,
      started_at: 3.months.ago
    )
  end
  
  let(:unrelated_tenure) do
    create(:employment_tenure,
      teammate: unrelated_teammate,
      company: company,
      position: position,
      manager_teammate: nil,
      started_at: 1.year.ago
    )
  end

  before do
    manager_tenure
    direct_report_tenure
    indirect_report_tenure
    unrelated_tenure
  end

  describe 'GET /organizations/:organization_id/feedback_requests/new' do
    context 'when user is a regular manager (no can_manage_employment)' do
      before do
        sign_in_as_teammate_for_request(manager_person, company)
      end

      it 'shows only the viewing teammate and their hierarchy' do
        get new_organization_feedback_request_path(company)
        
        expect(response).to have_http_status(:success)
        
        # Should include manager themselves
        expect(response.body).to include(manager_person.display_name)
        
        # Should include direct report
        expect(response.body).to include(direct_report_person.display_name)
        
        # Should include indirect report
        expect(response.body).to include(indirect_report_person.display_name)
        
        # Should NOT include unrelated teammate
        expect(response.body).not_to include(unrelated_person.display_name)
      end
    end

    context 'when user has can_manage_employment permission' do
      before do
        manager_teammate.update!(can_manage_employment: true)
        sign_in_as_teammate_for_request(manager_person, company)
      end

      it 'shows all active company teammates' do
        get new_organization_feedback_request_path(company)
        
        expect(response).to have_http_status(:success)
        
        # Should include manager themselves
        expect(response.body).to include(manager_person.display_name)
        
        # Should include direct report
        expect(response.body).to include(direct_report_person.display_name)
        
        # Should include indirect report
        expect(response.body).to include(indirect_report_person.display_name)
        
        # Should also include unrelated teammate (because of can_manage_employment)
        expect(response.body).to include(unrelated_person.display_name)
      end
    end

    context 'when user has no reports' do
      let(:individual_person) { create(:person) }
      let(:individual_teammate) do
        CompanyTeammate.find_or_create_by!(person: individual_person, organization: company) do |t|
          t.organization = company
          t.first_employed_at = 1.year.ago
        end
      end
      
      let(:individual_tenure) do
        create(:employment_tenure,
          teammate: individual_teammate,
          company: company,
          position: position,
          manager_teammate: nil,
          started_at: 1.year.ago
        )
      end

      before do
        individual_tenure
        sign_in_as_teammate_for_request(individual_person, company)
      end

      it 'shows only themselves' do
        get new_organization_feedback_request_path(company)
        
        expect(response).to have_http_status(:success)
        
        # Should include themselves
        expect(response.body).to include(individual_person.display_name)
        
        # Should NOT include others
        expect(response.body).not_to include(manager_person.display_name)
        expect(response.body).not_to include(direct_report_person.display_name)
        expect(response.body).not_to include(unrelated_person.display_name)
      end
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/edit' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: manager_teammate,
        subject_of_feedback_teammate: direct_report_teammate,
        subject_line: 'Test feedback request'
      )
    end

    context 'when user is a regular manager' do
      before do
        sign_in_as_teammate_for_request(manager_person, company)
      end

      it 'shows only the viewing teammate and their hierarchy' do
        get edit_organization_feedback_request_path(company, feedback_request)
        
        expect(response.status).to be_between(200, 399).inclusive
        
        # Should include manager themselves
        expect(response.body).to include(manager_person.display_name)
        
        # Should include direct report
        expect(response.body).to include(direct_report_person.display_name)
        
        # Should include indirect report
        expect(response.body).to include(indirect_report_person.display_name)
        
        # Should NOT include unrelated teammate
        expect(response.body).not_to include(unrelated_person.display_name)
      end
    end

    context 'when user has can_manage_employment permission' do
      before do
        manager_teammate.update!(can_manage_employment: true)
        sign_in_as_teammate_for_request(manager_person, company)
      end

      it 'shows all active company teammates' do
        get edit_organization_feedback_request_path(company, feedback_request)
        
        expect(response.status).to be_between(200, 399).inclusive
        
        # Should include all teammates
        expect(response.body).to include(manager_person.display_name)
        expect(response.body).to include(direct_report_person.display_name)
        expect(response.body).to include(indirect_report_person.display_name)
        expect(response.body).to include(unrelated_person.display_name)
      end
    end
  end
end
