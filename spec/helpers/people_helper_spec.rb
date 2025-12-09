require 'rails_helper'

RSpec.describe PeopleHelper, type: :helper do
  describe '#people_current_view_name' do
    # Test the helper method by stubbing the controller/action context
    # Since helper specs have controller context, we need to stub properly
    
    context 'when action is show' do
      before do
        allow(helper).to receive(:action_name).and_return('show')
      end
      
      it 'returns Manage Profile Mode for people controller' do
        allow(helper).to receive(:controller_name).and_return('people')
        expect(helper.people_current_view_name).to eq('Manage Profile Mode')
      end
      
      it 'returns Check-In for check_ins controller' do
        allow(helper).to receive(:controller_name).and_return('check_ins')
        expect(helper.people_current_view_name).to eq('Check-In')
      end
      
      it 'returns Check-In Review for finalizations controller' do
        allow(helper).to receive(:controller_name).and_return('finalizations')
        expect(helper.people_current_view_name).to eq('Check-In Review')
      end
      
      it 'returns Seat History Mode for position controller' do
        allow(helper).to receive(:controller_name).and_return('position')
        expect(helper.people_current_view_name).to eq('Seat History Mode')
      end
      
      it 'returns Assignment Mode for assignment_tenures controller' do
        allow(helper).to receive(:controller_name).and_return('assignment_tenures')
        expect(helper.people_current_view_name).to eq('Assignment Mode')
      end
    end

    it 'returns Public View for public action' do
      allow(helper).to receive(:action_name).and_return('public')
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Public View')
    end

    it 'returns Teammate View for teammate action' do
      allow(helper).to receive(:action_name).and_return('teammate')
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Teammate View')
    end

    it 'returns Active Job View for complete_picture action' do
      allow(helper).to receive(:action_name).and_return('complete_picture')
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Active Job View')
    end

    it 'returns Acknowledgement for audit action' do
      allow(helper).to receive(:action_name).and_return('audit')
      allow(helper).to receive(:controller_name).and_return('employees')
      expect(helper.people_current_view_name).to eq('Acknowledgement')
    end

    it 'returns Growth View for growth action' do
      allow(helper).to receive(:action_name).and_return('growth')
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Growth View')
    end

    it 'returns Check-In for check_in action' do
      allow(helper).to receive(:action_name).and_return('check_in')
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Check-In')
    end

    it 'returns Manage Profile Mode when action_name is nil' do
      allow(helper).to receive(:action_name).and_return(nil)
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Manage Profile Mode')
    end
  end

  describe '#slack_connection_status' do
    let(:person) { create(:person) }
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, person: person, organization: organization) }

    context 'when person has Slack identity for organization' do
      let!(:slack_identity) { create(:teammate_identity, :slack, teammate: teammate) }

      it 'returns connected status with organization name' do
        result = helper.slack_connection_status(person, organization)
        expect(result).to include('Connected to')
        expect(result).to include(organization.name)
        expect(result).to include('check-circle')
        expect(result).to include('text-success')
      end
    end

    context 'when person has no Slack identity for organization' do
      it 'returns not connected status' do
        result = helper.slack_connection_status(person, organization)
        expect(result).to include('Not connected to')
        expect(result).to include(organization.name)
        expect(result).to include('text-muted')
      end
    end
  end

  describe '#identity_provider_icon' do
    let(:person) { create(:person) }
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, person: person, organization: organization) }

    it 'returns bi-google for google_oauth2 provider' do
      identity = create(:person_identity, :google, person: person)
      expect(helper.identity_provider_icon(identity)).to eq('bi-google')
    end

    it 'returns bi-envelope for email provider' do
      identity = create(:person_identity, :email, person: person)
      expect(helper.identity_provider_icon(identity)).to eq('bi-envelope')
    end

    it 'returns bi-slack for slack provider' do
      identity = create(:teammate_identity, :slack, teammate: teammate)
      expect(helper.identity_provider_icon(identity)).to eq('bi-slack')
    end

    it 'returns bi-kanban for asana provider' do
      identity = create(:teammate_identity, :asana, teammate: teammate)
      expect(helper.identity_provider_icon(identity)).to eq('bi-kanban')
    end
  end

  describe '#identity_provider_name' do
    let(:person) { create(:person) }
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, person: person, organization: organization) }

    it 'returns Google for google_oauth2 provider' do
      identity = create(:person_identity, :google, person: person)
      expect(helper.identity_provider_name(identity)).to eq('Google')
    end

    it 'returns Email for email provider' do
      identity = create(:person_identity, :email, person: person)
      expect(helper.identity_provider_name(identity)).to eq('Email')
    end

    it 'returns Slack for slack provider' do
      identity = create(:teammate_identity, :slack, teammate: teammate)
      expect(helper.identity_provider_name(identity)).to eq('Slack')
    end

    it 'returns Asana for asana provider' do
      identity = create(:teammate_identity, :asana, teammate: teammate)
      expect(helper.identity_provider_name(identity)).to eq('Asana')
    end
  end

  describe '#identity_status_badge' do
    let(:person) { create(:person) }
    let(:organization) { create(:organization, :company, name: 'Test Company') }
    let(:teammate) { create(:teammate, person: person, organization: organization) }

    context 'for PersonIdentity' do
      it 'returns Connected badge for Google identity' do
        identity = create(:person_identity, :google, person: person)
        result = helper.identity_status_badge(identity)
        expect(result).to include('Connected')
        expect(result).to include('badge bg-success')
      end

      it 'returns Email badge for email identity' do
        identity = create(:person_identity, :email, person: person)
        result = helper.identity_status_badge(identity)
        expect(result).to include('Email')
        expect(result).to include('badge bg-secondary')
      end
    end

    context 'for TeammateIdentity' do
      it 'returns organization name badge for Slack identity' do
        identity = create(:teammate_identity, :slack, teammate: teammate)
        result = helper.identity_status_badge(identity)
        expect(result).to include(organization.display_name)
        expect(result).to include('badge bg-info')
      end

      it 'returns organization name badge for Asana identity' do
        identity = create(:teammate_identity, :asana, teammate: teammate)
        result = helper.identity_status_badge(identity)
        expect(result).to include(organization.display_name)
        expect(result).to include('badge bg-info')
      end
    end
  end

  describe '#disconnect_identity_button' do
    let(:person) { create(:person) }
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, person: person, organization: organization) }

    before do
      # Stub the helper methods that are called
      allow(helper).to receive(:can_disconnect_identity?).and_return(true)
      allow(helper).to receive(:disconnect_identity_path).and_return('/profile/identities/1')
    end

    it 'returns button for PersonIdentity' do
      identity = create(:person_identity, :google, person: person)
      result = helper.disconnect_identity_button(identity)
      expect(result).to be_present
      expect(result).to include('Disconnect')
    end

    it 'returns nil for TeammateIdentity' do
      identity = create(:teammate_identity, :slack, teammate: teammate)
      result = helper.disconnect_identity_button(identity)
      expect(result).to be_nil
    end
  end

  describe '#identity_raw_data_button' do
    let(:person) { create(:person) }
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, person: person, organization: organization) }

    it 'returns details element for identity with raw_data' do
      identity = create(:person_identity, :google, person: person, raw_data: { 'test' => 'data' })
      result = helper.identity_raw_data_button(identity)
      expect(result).to be_present
      expect(result).to include('View Raw Data')
    end

    it 'returns nil for identity without raw_data' do
      identity = create(:person_identity, :google, person: person, raw_data: nil)
      result = helper.identity_raw_data_button(identity)
      expect(result).to be_nil
    end

    it 'works for TeammateIdentity' do
      identity = create(:teammate_identity, :slack, teammate: teammate, raw_data: { 'test' => 'data' })
      result = helper.identity_raw_data_button(identity)
      expect(result).to be_present
      expect(result).to include('View Raw Data')
    end
  end
end
