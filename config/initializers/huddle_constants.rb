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
  
  CONFLICT_STYLES = %w[Collaborative Competing Compromising Accommodating Avoiding].freeze
  
  CONFLICT_STYLE_DESCRIPTIONS = {
    'Collaborative' => 'High cooperativeness (speak up), High assertiveness (step up) - Seeks win-win solutions',
    'Competing' => 'Low cooperativeness (speak up), High assertiveness (step up) - Pursues own concerns at others\' expense',
    'Compromising' => 'Medium cooperativeness (speak up), Medium assertiveness (step up) - Seeks middle ground',
    'Accommodating' => 'High cooperativeness (speak up), Low assertiveness (step up) - Yields to others\' concerns',
    'Avoiding' => 'Low cooperativeness (speak up), Low assertiveness (step up) - Withdraws from conflict'
  }.freeze
end 