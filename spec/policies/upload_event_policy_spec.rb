require 'rails_helper'
require 'ostruct'

RSpec.describe UploadEventPolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization) }
  let(:creator) { create(:person) }
  let(:other_person) { create(:person) }
  let(:admin_person) { create(:person, :admin) }
  
  let(:upload_event) { create(:upload_event, creator: creator, organization: organization) }
  let(:other_upload_event) { create(:upload_event, creator: other_person, organization: organization) }

  # Create pundit user objects that match the controller's pundit_user structure
  let(:pundit_user_creator) { OpenStruct.new(user: creator, pundit_organization: organization) }
  let(:pundit_user_other) { OpenStruct.new(user: other_person, pundit_organization: organization) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_person, pundit_organization: organization) }

  permissions :index? do
    it "allows users with employment management permission" do
      # Create teammate with employment management permission
      create(:teammate, person: creator, organization: organization, can_manage_employment: true)
      
      expect(subject).to permit(pundit_user_creator, UploadEvent)
    end

    it "allows admins" do
      expect(subject).to permit(pundit_user_admin, UploadEvent)
    end

    it "denies users without employment management permission" do
      # Create teammate without employment management permission
      create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
      
      expect(subject).not_to permit(pundit_user_other, UploadEvent)
    end
  end

  permissions :show? do
    it "allows users with employment management permission" do
      create(:teammate, person: creator, organization: organization, can_manage_employment: true)
      
      expect(subject).to permit(pundit_user_creator, upload_event)
    end

    it "allows admins" do
      expect(subject).to permit(pundit_user_admin, upload_event)
    end

    it "denies users without employment management permission" do
      create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
      
      expect(subject).not_to permit(pundit_user_other, upload_event)
    end
  end

  permissions :create? do
    it "allows users with employment management permission" do
      create(:teammate, person: creator, organization: organization, can_manage_employment: true)
      
      expect(subject).to permit(pundit_user_creator, UploadEvent)
    end

    it "allows admins" do
      expect(subject).to permit(pundit_user_admin, UploadEvent)
    end

    it "denies users without employment management permission" do
      create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
      
      expect(subject).not_to permit(pundit_user_other, UploadEvent)
    end
  end

  permissions :new? do
    it "allows users with employment management permission" do
      create(:teammate, person: creator, organization: organization, can_manage_employment: true)
      
      expect(subject).to permit(pundit_user_creator, UploadEvent)
    end

    it "allows admins" do
      expect(subject).to permit(pundit_user_admin, UploadEvent)
    end

    it "denies users without employment management permission" do
      create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
      
      expect(subject).not_to permit(pundit_user_other, UploadEvent)
    end
  end

  permissions :destroy? do
    it "allows users with employment management permission" do
      create(:teammate, person: creator, organization: organization, can_manage_employment: true)
      
      expect(subject).to permit(pundit_user_creator, upload_event)
    end

    it "allows admins" do
      expect(subject).to permit(pundit_user_admin, upload_event)
    end

    it "denies users without employment management permission" do
      create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
      
      expect(subject).not_to permit(pundit_user_other, upload_event)
    end
  end

  permissions :process_upload? do
    it "allows users with employment management permission" do
      create(:teammate, person: creator, organization: organization, can_manage_employment: true)
      
      expect(subject).to permit(pundit_user_creator, upload_event)
    end

    it "allows admins" do
      expect(subject).to permit(pundit_user_admin, upload_event)
    end

    it "denies users without employment management permission" do
      create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
      
      expect(subject).not_to permit(pundit_user_other, upload_event)
    end
  end

  describe "scope" do
    let!(:upload_event1) { create(:upload_event, creator: creator, organization: organization) }
    let!(:upload_event2) { create(:upload_event, creator: other_person, organization: organization) }
    let!(:other_org_upload_event) { create(:upload_event, creator: creator, organization: create(:organization)) }

    it "shows upload events for users with employment management permission" do
      create(:teammate, person: creator, organization: organization, can_manage_employment: true)
      
      scope = UploadEventPolicy::Scope.new(pundit_user_creator, UploadEvent).resolve
      expect(scope).to include(upload_event1)
      expect(scope).to include(upload_event2)
      expect(scope).not_to include(other_org_upload_event)
    end

    it "shows all upload events for admins" do
      scope = UploadEventPolicy::Scope.new(pundit_user_admin, UploadEvent).resolve
      expect(scope).to include(upload_event1)
      expect(scope).to include(upload_event2)
      expect(scope).to include(other_org_upload_event)
    end

    it "shows no upload events for users without employment management permission" do
      create(:teammate, person: other_person, organization: organization, can_manage_employment: false)
      
      scope = UploadEventPolicy::Scope.new(pundit_user_other, UploadEvent).resolve
      expect(scope).to be_empty
    end
  end
end
