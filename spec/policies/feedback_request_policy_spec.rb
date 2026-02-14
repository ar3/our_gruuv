require 'rails_helper'

RSpec.describe FeedbackRequestPolicy, type: :policy do
  subject { described_class }

  let(:company) { create(:organization, :company) }
  let(:requestor_person) { create(:person) }
  let(:requestor_teammate) { create(:company_teammate, person: requestor_person, organization: company) }
  let(:subject_person) { create(:person) }
  let(:subject_teammate) { create(:company_teammate, person: subject_person, organization: company) }
  let(:responder_person) { create(:person) }
  let(:responder_teammate) { create(:company_teammate, person: responder_person, organization: company) }
  let(:other_person) { create(:person) }
  let(:other_teammate) { create(:company_teammate, person: other_person, organization: company) }
  
  let(:feedback_request) do
    create(:feedback_request,
      company: company,
      requestor_teammate: requestor_teammate,
      subject_of_feedback_teammate: subject_teammate
    )
  end

  let(:pundit_user_requestor) { OpenStruct.new(user: requestor_teammate, impersonating_teammate: nil) }
  let(:pundit_user_subject) { OpenStruct.new(user: subject_teammate, impersonating_teammate: nil) }
  let(:pundit_user_responder) { OpenStruct.new(user: responder_teammate, impersonating_teammate: nil) }
  let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

  permissions :show? do
    it "allows requestor to view" do
      expect(subject).to permit(pundit_user_requestor, feedback_request)
    end

    it "allows subject to view" do
      expect(subject).to permit(pundit_user_subject, feedback_request)
    end

    it "denies responder from viewing (responders only see the answer page)" do
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      expect(subject).not_to permit(pundit_user_responder, feedback_request)
    end

    it "denies other users from viewing" do
      expect(subject).not_to permit(pundit_user_other, feedback_request)
    end

    it "denies terminated teammates from viewing" do
      # Ensure first_employed_at is set before setting last_terminated_at (validation requirement)
      requestor_teammate.update!(first_employed_at: 1.year.ago) unless requestor_teammate.first_employed_at
      requestor_teammate.update!(last_terminated_at: Date.current)
      pundit_user_requestor_terminated = OpenStruct.new(user: requestor_teammate.reload, impersonating_teammate: nil)
      expect(subject).not_to permit(pundit_user_requestor_terminated, feedback_request)
    end
  end

  permissions :new? do
    it "allows user to access new page when no subject is set" do
      # For new action, subject can be nil - policy allows if user is in organization
      new_request = FeedbackRequest.new(company: company)
      expect(subject).to permit(pundit_user_requestor, new_request)
    end

    it "allows user to access new page with subject set if they can create for that subject (self)" do
      # Requestor can create for themselves
      new_request = FeedbackRequest.new(company: company, subject_of_feedback_teammate: requestor_teammate)
      expect(subject).to permit(pundit_user_requestor, new_request)
    end

    it "allows manager to access new page with subject set if they can create for that subject" do
      # Manager can create for their direct report
      manager = create(:company_teammate, organization: company)
      direct_report = create(:company_teammate, organization: company)
      # Set up manager relationship through employment tenure
      create(:employment_tenure, teammate: direct_report, company: company, manager_teammate: manager)
      new_request = FeedbackRequest.new(company: company, subject_of_feedback_teammate: direct_report)
      pundit_user_manager = OpenStruct.new(user: manager, impersonating_teammate: nil)
      expect(subject).to permit(pundit_user_manager, new_request)
    end
  end

  permissions :create? do
    context "when creating for self" do
      let(:new_request) { FeedbackRequest.new(company: company, subject_of_feedback_teammate: requestor_teammate) }

      it "allows user to create request about themselves" do
        expect(subject).to permit(pundit_user_requestor, new_request)
      end
    end

    context "when creating for someone they manage" do
      let(:manager) { create(:company_teammate, organization: company) }
      let(:direct_report) { create(:company_teammate, organization: company) }
      let(:new_request) { FeedbackRequest.new(company: company, subject_of_feedback_teammate: direct_report) }
      let(:pundit_user_manager) { OpenStruct.new(user: manager, impersonating_teammate: nil) }

      before do
        # Set up manager relationship through employment tenure
        create(:employment_tenure, teammate: direct_report, company: company, manager_teammate: manager)
      end

      it "allows manager to create request about direct report" do
        expect(subject).to permit(pundit_user_manager, new_request)
      end
    end

    context "when creating for someone else" do
      let(:new_request) { FeedbackRequest.new(company: company, subject_of_feedback_teammate: subject_teammate) }

      it "denies user from creating request about someone else" do
        expect(subject).not_to permit(pundit_user_other, new_request)
      end
    end

    context "when user has can_manage_employment permission" do
      let(:admin_teammate) { create(:company_teammate, organization: company, can_manage_employment: true) }
      let(:unrelated_teammate) { create(:company_teammate, organization: company) }
      let(:new_request) { FeedbackRequest.new(company: company, subject_of_feedback_teammate: unrelated_teammate) }
      let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

      it "allows user with can_manage_employment to create request for anyone" do
        expect(subject).to permit(pundit_user_admin, new_request)
      end

      it "allows user with can_manage_employment to create request for themselves" do
        self_request = FeedbackRequest.new(company: company, subject_of_feedback_teammate: admin_teammate)
        expect(subject).to permit(pundit_user_admin, self_request)
      end
    end

    context "when no subject is set (new action)" do
      let(:new_request) { FeedbackRequest.new(company: company) }

      it "allows user in organization to access new page" do
        expect(subject).to permit(pundit_user_requestor, new_request)
      end
    end
  end

  permissions :edit? do
    it "allows requestor to edit" do
      expect(subject).to permit(pundit_user_requestor, feedback_request)
    end

    it "denies subject from editing" do
      expect(subject).not_to permit(pundit_user_subject, feedback_request)
    end

    it "denies responder from editing" do
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      expect(subject).not_to permit(pundit_user_responder, feedback_request)
    end

    it "denies other users from editing" do
      expect(subject).not_to permit(pundit_user_other, feedback_request)
    end

    it "denies terminated teammates from editing" do
      # Ensure first_employed_at is set before setting last_terminated_at (validation requirement)
      requestor_teammate.update!(first_employed_at: 1.year.ago) unless requestor_teammate.first_employed_at
      requestor_teammate.update!(last_terminated_at: Date.current)
      pundit_user_requestor_terminated = OpenStruct.new(user: requestor_teammate.reload, impersonating_teammate: nil)
      expect(subject).not_to permit(pundit_user_requestor_terminated, feedback_request)
    end
  end

  permissions :update? do
    it "allows requestor to update" do
      expect(subject).to permit(pundit_user_requestor, feedback_request)
    end

    it "denies subject from updating" do
      expect(subject).not_to permit(pundit_user_subject, feedback_request)
    end

    it "denies responder from updating" do
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      expect(subject).not_to permit(pundit_user_responder, feedback_request)
    end

    it "denies other users from updating" do
      expect(subject).not_to permit(pundit_user_other, feedback_request)
    end

    it "denies terminated teammates from updating" do
      # Ensure first_employed_at is set before setting last_terminated_at (validation requirement)
      requestor_teammate.update!(first_employed_at: 1.year.ago) unless requestor_teammate.first_employed_at
      requestor_teammate.update!(last_terminated_at: Date.current)
      pundit_user_requestor_terminated = OpenStruct.new(user: requestor_teammate.reload, impersonating_teammate: nil)
      expect(subject).not_to permit(pundit_user_requestor_terminated, feedback_request)
    end
  end

  permissions :destroy? do
    it "allows requestor to destroy" do
      expect(subject).to permit(pundit_user_requestor, feedback_request)
    end

    it "denies subject from destroying" do
      expect(subject).not_to permit(pundit_user_subject, feedback_request)
    end

    it "denies responder from destroying" do
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      expect(subject).not_to permit(pundit_user_responder, feedback_request)
    end

    it "denies other users from destroying" do
      expect(subject).not_to permit(pundit_user_other, feedback_request)
    end

    it "denies terminated teammates from destroying" do
      # Ensure first_employed_at is set before setting last_terminated_at (validation requirement)
      requestor_teammate.update!(first_employed_at: 1.year.ago) unless requestor_teammate.first_employed_at
      requestor_teammate.update!(last_terminated_at: Date.current)
      pundit_user_requestor_terminated = OpenStruct.new(user: requestor_teammate.reload, impersonating_teammate: nil)
      expect(subject).not_to permit(pundit_user_requestor_terminated, feedback_request)
    end
  end

  permissions :answer? do
    it "allows responder to answer" do
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      expect(subject).to permit(pundit_user_responder, feedback_request)
    end

    it "denies requestor from answering (unless they are also a responder)" do
      expect(subject).not_to permit(pundit_user_requestor, feedback_request)
    end

    it "allows requestor to answer if they are also a responder" do
      feedback_request.feedback_request_responders.create!(teammate: requestor_teammate)
      expect(subject).to permit(pundit_user_requestor, feedback_request)
    end

    it "denies subject from answering (unless they are also a responder)" do
      expect(subject).not_to permit(pundit_user_subject, feedback_request)
    end

    it "denies other users from answering" do
      expect(subject).not_to permit(pundit_user_other, feedback_request)
    end

    it "denies terminated teammates from answering" do
      # Ensure first_employed_at is set before setting last_terminated_at (validation requirement)
      responder_teammate.update!(first_employed_at: 1.year.ago) unless responder_teammate.first_employed_at
      responder_teammate.update!(last_terminated_at: Date.current)
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      pundit_user_responder_terminated = OpenStruct.new(user: responder_teammate.reload, impersonating_teammate: nil)
      expect(subject).not_to permit(pundit_user_responder_terminated, feedback_request)
    end
  end

  permissions :add_responder? do
    it "allows requestor to add responders" do
      expect(subject).to permit(pundit_user_requestor, feedback_request)
    end

    it "denies subject from adding responders" do
      expect(subject).not_to permit(pundit_user_subject, feedback_request)
    end

    it "denies responder from adding responders" do
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      expect(subject).not_to permit(pundit_user_responder, feedback_request)
    end

    it "denies other users from adding responders" do
      expect(subject).not_to permit(pundit_user_other, feedback_request)
    end

    it "denies terminated teammates from adding responders" do
      # Ensure first_employed_at is set before setting last_terminated_at (validation requirement)
      requestor_teammate.update!(first_employed_at: 1.year.ago) unless requestor_teammate.first_employed_at
      requestor_teammate.update!(last_terminated_at: Date.current)
      pundit_user_requestor_terminated = OpenStruct.new(user: requestor_teammate.reload, impersonating_teammate: nil)
      expect(subject).not_to permit(pundit_user_requestor_terminated, feedback_request)
    end
  end

  describe "scope" do
    let!(:requestor_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate
      )
    end

    let!(:subject_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: other_teammate,
        subject_of_feedback_teammate: subject_teammate
      )
    end

    let!(:responder_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: other_teammate,
        subject_of_feedback_teammate: other_teammate
      ).tap do |fr|
        fr.feedback_request_responders.create!(teammate: responder_teammate)
      end
    end

    let!(:unrelated_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: other_teammate,
        subject_of_feedback_teammate: other_teammate
      )
    end

    it "returns requests where user is the requestor" do
      scope = Pundit.policy_scope(pundit_user_requestor, FeedbackRequest)
      expect(scope).to include(requestor_request)
    end

    it "returns requests where user is the subject" do
      scope = Pundit.policy_scope(pundit_user_subject, FeedbackRequest)
      expect(scope).to include(subject_request)
    end

    it "returns requests where user is a responder" do
      scope = Pundit.policy_scope(pundit_user_responder, FeedbackRequest)
      expect(scope).to include(responder_request)
    end

    it "does not return unrelated requests" do
      scope = Pundit.policy_scope(pundit_user_requestor, FeedbackRequest)
      expect(scope).not_to include(unrelated_request)
    end
  end
end
