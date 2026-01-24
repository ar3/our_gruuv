require 'rails_helper'
require 'ostruct'

RSpec.describe PositionPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:person) { create(:person) }
  let(:title) { create(:title, organization: company) }
  let(:title_in_department) { create(:title, organization: department) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level).tap { |p| p.title } }
  let(:position_in_department) { create(:position, title: title_in_department, position_level: position_level).tap { |p| p.title } }
  
  let(:company_teammate) { create(:company_teammate, person: person, organization: company) }
  let(:pundit_user) { OpenStruct.new(user: company_teammate, impersonating_teammate: nil) }
  
  subject { described_class.new(pundit_user, position) }

  describe '#create?' do
    context 'as admin' do
      let(:admin_person) { create(:person, :admin) }
      let(:admin_teammate) { create(:company_teammate, person: admin_person, organization: company) }
      let(:admin_pundit_user) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
      subject { described_class.new(admin_pundit_user, position) }
      
      it 'allows creation' do
        expect(subject.create?).to be true
      end
    end

    context 'with can_manage_maap permission on company teammate record' do
      before do
        company_teammate.update(can_manage_maap: true)
      end

      it 'allows creation' do
        expect(subject.create?).to be true
      end
    end

    context 'without can_manage_maap permission' do
      before do
        company_teammate.update(can_manage_maap: false)
      end

      it 'denies creation' do
        expect(subject.create?).to be false
      end
    end

    context 'for position in department' do
      subject { described_class.new(pundit_user, position_in_department) }

      before do
        company_teammate.update(can_manage_maap: true)
      end

      it 'allows creation when user has permission on root company' do
        expect(subject.create?).to be true
      end
    end

    context 'for position in different company' do
      let(:other_company) { create(:organization, :company) }
      let(:other_title) { create(:title, organization: other_company) }
      let(:other_position) { create(:position, title: other_title, position_level: position_level) }
      subject { described_class.new(pundit_user, other_position) }

      before do
        company_teammate.update(can_manage_maap: true)
      end

      it 'denies creation when user does not have permission on that company' do
        expect(subject.create?).to be false
      end
    end
  end

  describe '#update?' do
    context 'as admin' do
      let(:admin_person) { create(:person, :admin) }
      let(:admin_teammate) { create(:company_teammate, person: admin_person, organization: company) }
      let(:admin_pundit_user) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
      subject { described_class.new(admin_pundit_user, position) }
      
      it 'allows update' do
        expect(subject.update?).to be true
      end
    end

    context 'with can_manage_maap permission on company teammate record' do
      before do
        company_teammate.update(can_manage_maap: true)
      end

      it 'allows update' do
        expect(subject.update?).to be true
      end
    end

    context 'without can_manage_maap permission' do
      before do
        company_teammate.update(can_manage_maap: false)
      end

      it 'denies update' do
        expect(subject.update?).to be false
      end
    end
  end

  describe '#destroy?' do
    context 'as admin' do
      let(:admin_person) { create(:person, :admin) }
      let(:admin_teammate) { create(:company_teammate, person: admin_person, organization: company) }
      let(:admin_pundit_user) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
      subject { described_class.new(admin_pundit_user, position) }
      
      it 'allows destruction' do
        expect(subject.destroy?).to be true
      end
    end

    context 'with can_manage_maap permission on company teammate record' do
      before do
        company_teammate.update(can_manage_maap: true)
      end

      it 'allows destruction' do
        expect(subject.destroy?).to be true
      end
    end

    context 'without can_manage_maap permission' do
      before do
        company_teammate.update(can_manage_maap: false)
      end

      it 'denies destruction' do
        expect(subject.destroy?).to be false
      end
    end
  end

  describe '#show?' do
    context 'when user is in the same organization hierarchy' do
      it 'allows viewing' do
        expect(subject.show?).to be true
      end
    end

    context 'when user is not in the organization hierarchy' do
      let(:other_company) { create(:organization, :company) }
      let(:other_company_teammate) { create(:company_teammate, person: person, organization: other_company) }
      let(:other_pundit_user) { OpenStruct.new(user: other_company_teammate, impersonating_teammate: nil) }
      subject { described_class.new(other_pundit_user, position) }
      
      it 'denies viewing' do
        expect(subject.show?).to be false
      end
    end
  end
end
