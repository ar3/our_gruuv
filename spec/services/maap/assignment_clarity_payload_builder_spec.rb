# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Maap::AssignmentClarityPayloadBuilder do
  describe '.call' do
    it 'orders peer assignments by department neighborhood then title, then truncates' do
      company = create(:organization)
      root = create(:department, company: company, name: 'Root')
      dept_a = create(:department, company: company, name: 'DeptA', parent_department: root)
      dept_b = create(:department, company: company, name: 'DeptB', parent_department: root)
      dept_child = create(:department, company: company, name: 'ChildA', parent_department: dept_a)
      dept_other_root = create(:department, company: company, name: 'OtherRoot', parent_department: nil)
      dept_far_root = create(:department, company: company, name: 'FarRoot', parent_department: nil)

      subject_assignment = create(:assignment, company: company, department: dept_a, title: 'Subject')

      create(:assignment, company: company, department: dept_a, title: 'Peer-A2')
      create(:assignment, company: company, department: dept_a, title: 'Peer-A1')
      create(:assignment, company: company, department: root, title: 'Peer-Root')
      create(:assignment, company: company, department: dept_child, title: 'Peer-Child')
      create(:assignment, company: company, department: dept_b, title: 'Peer-Sib')
      create(:assignment, company: company, department: dept_other_root, title: 'Peer-Other')
      create(:assignment, company: company, department: dept_far_root, title: 'Peer-ZZ')

      stub_const("#{described_class}::PEER_ASSIGNMENTS_FOR_CLARITY_LIMIT", 6)

      payload = described_class.call(assignment: subject_assignment)
      section = payload['sections'].find { |s| s['title'].include?('Other company assignments') }
      titles = section['body'].map { |h| h['Title'] }

      expect(titles).to eq(%w[Peer-A1 Peer-A2 Peer-Root Peer-Child Peer-Sib Peer-Other])
    end

    it 'when assignment has no department, orders peers by title only' do
      company = create(:organization)
      a = create(:assignment, company: company, department: nil, title: 'Zebra')
      create(:assignment, company: company, department: nil, title: 'Alpha')
      create(:assignment, company: company, department: nil, title: 'Mike')

      stub_const("#{described_class}::PEER_ASSIGNMENTS_FOR_CLARITY_LIMIT", 10)

      payload = described_class.call(assignment: a)
      section = payload['sections'].find { |s| s['title'].include?('Other company assignments') }
      titles = section['body'].map { |h| h['Title'] }

      expect(titles).to eq(%w[Alpha Mike])
    end
  end
end
