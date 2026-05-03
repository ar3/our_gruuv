# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::CsvBlockParser do
  let(:csv) do
    <<~CSV
      Assignment,Ability,Description,Milestone 1,Milestone 2,Milestone 3,Milestone 4,Milestone 5,Ability milestone
      Line Cook,,
      ,Knife work,Use knives safely.,M1 body,,,,,2
    CSV
  end

  it 'parses assignment header then ability row' do
    parser = described_class.new(csv)
    expect(parser.parse).to be true
    expect(parser.errors).to be_empty
    expect(parser.ability_rows.size).to eq(1)
    row = parser.ability_rows.first
    expect(row['assignment_raw']).to eq('Line Cook')
    expect(row['ability_name']).to eq('Knife work')
    expect(row['description_raw']).to include('knives')
    expect(row['milestone_1_raw']).to include('M1')
    expect(row['ability_milestone_raw']).to eq('2')
  end
end
