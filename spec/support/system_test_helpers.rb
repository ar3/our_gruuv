module SystemTestHelpers
  # Navigate helper that waits for page load
  def visit_and_wait(path)
    visit(path)
    expect(page).to have_current_path(path, wait: 5)
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end


