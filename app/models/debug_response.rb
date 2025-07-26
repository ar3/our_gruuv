class DebugResponse < ApplicationRecord
  belongs_to :responseable, polymorphic: true
end
