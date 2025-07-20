# Huddle-related constants
module HuddleConstants
  ROLES = %w[facilitator active observer note_taker time_keeper other].freeze
  
  ROLE_LABELS = {
    'facilitator' => 'Facilitator',
    'active' => 'Active Participant', 
    'observer' => 'Observer',
    'note_taker' => 'Note Taker',
    'time_keeper' => 'Time Keeper',
    'other' => 'Other'
  }.freeze
end 