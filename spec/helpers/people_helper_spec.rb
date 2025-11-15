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
      
      it 'returns Self-Check-In Mode for check_ins controller' do
        allow(helper).to receive(:controller_name).and_return('check_ins')
        expect(helper.people_current_view_name).to eq('Self-Check-In Mode')
      end
      
      it 'returns Manager-Check-In Mode for finalizations controller' do
        allow(helper).to receive(:controller_name).and_return('finalizations')
        expect(helper.people_current_view_name).to eq('Manager-Check-In Mode')
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

    it 'returns Acknowledge-Check-In Mode for audit action' do
      allow(helper).to receive(:action_name).and_return('audit')
      allow(helper).to receive(:controller_name).and_return('employees')
      expect(helper.people_current_view_name).to eq('Acknowledge-Check-In Mode')
    end

    it 'returns Growth View for growth action' do
      allow(helper).to receive(:action_name).and_return('growth')
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Growth View')
    end

    it 'returns Self-Check-In Mode for check_in action' do
      allow(helper).to receive(:action_name).and_return('check_in')
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Self-Check-In Mode')
    end

    it 'returns Manage Profile Mode when action_name is nil' do
      allow(helper).to receive(:action_name).and_return(nil)
      allow(helper).to receive(:controller_name).and_return('people')
      expect(helper.people_current_view_name).to eq('Manage Profile Mode')
    end
  end
end
