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

  # Color System - Semantic meanings for consistent UI
  COLORS = {
    # Status Colors
    'success' => {
      meaning: 'Positive outcomes, completion, achievement',
      usage: ['completed actions', 'submitted feedback', 'high ratings (4-5)', 'appreciations', 'active status']
    },
    'primary' => {
      meaning: 'Primary actions, main focus, key metrics',
      usage: ['primary buttons', 'overall scores', 'main navigation', 'key information']
    },
    'warning' => {
      meaning: 'Attention needed, improvement areas, caution',
      usage: ['pending actions', 'improvement suggestions', 'medium ratings (3)', 'needs attention']
    },
    'danger' => {
      meaning: 'Errors, critical issues, low performance',
      usage: ['errors', 'low ratings (1-2)', 'critical issues', 'failed actions']
    },
    'info' => {
      meaning: 'Information, data, neutral metrics',
      usage: ['counts', 'statistics', 'neutral information', 'data points']
    },
    'secondary' => {
      meaning: 'Secondary information, inactive, placeholder',
      usage: ['roles', 'inactive status', 'placeholder data', 'secondary actions']
    },
    'light' => {
      meaning: 'Empty states, zero values, inactive',
      usage: ['empty states', 'zero counts', 'inactive elements', 'no data']
    }
  }.freeze

  # Specific color mappings for different data types
  RATING_COLORS = {
    1 => 'danger',    # Very poor
    2 => 'danger',    # Poor
    3 => 'warning',   # Average
    4 => 'success',   # Good
    5 => 'success'    # Excellent
  }.freeze

  # Nat 20 score color mapping (composite score, different from individual ratings)
  NAT_20_COLORS = {
    0.0..9.9 => 'danger',     # Critical issues, needs immediate attention
    10.0..12.9 => 'warning',   # Significant room for improvement
    13.0..16.4 => 'warning-subtle',     # Average performance
    16.5..19.9 => 'success-subtle',  # Good performance
    20.0..20.0 => 'success'       # Perfect score - exceptional performance
  }.freeze

  STATUS_COLORS = {
    'active' => 'info',
    'completed' => 'success',
    'submitted' => 'success',
    'pending' => 'light',
    'inactive' => 'light',
    'cancelled' => 'danger'
  }.freeze

  FEEDBACK_COLORS = {
    'appreciation' => 'success',
    'suggestion' => 'warning',
    'private' => 'info'
  }.freeze

  CONFLICT_STYLE_COLORS = {
    'Collaborative' => 'success',
    'Competing' => 'warning',
    'Compromising' => 'warning',
    'Accommodating' => 'warning',
    'Avoiding' => 'danger'
  }.freeze

  # Feedback participation color mapping (percentage-based)
  FEEDBACK_PARTICIPATION_COLORS = {
    0..25 => 'danger',      # Very low participation
    26..50 => 'warning',     # Low participation
    51..75 => 'warning-subtle',        # Moderate participation
    76..99 => 'success-subtle',     # Good participation
    100..100 => 'success'     # Perfect participation
  }.freeze
end 