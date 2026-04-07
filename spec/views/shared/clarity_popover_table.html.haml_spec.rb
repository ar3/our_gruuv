# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/clarity_popover_table', type: :view do
  let(:table_data) do
    {
      position: { employee: 10, manager: 20, together: 30 },
      assignments: { employee: 40, manager: 50, together: 60 },
      aspirations: { employee: 70, manager: 80, together: 90 }
    }
  end

  it 'renders the grid and footnote using clear vs blurred day counts' do
    render partial: 'shared/clarity_popover_table', locals: { table_data: table_data }

    expect(rendered).to have_css('table.table')
    expect(rendered).to have_css('tfoot td', text: /#{CheckInBehavior::CLARITY_CLEAR_DAYS}/)
    expect(rendered).to have_css('tfoot td', text: /#{CheckInBehavior::CLARITY_BLURRED_DAYS}/)
    expect(rendered).to include('overall clarity percentage')
  end
end
