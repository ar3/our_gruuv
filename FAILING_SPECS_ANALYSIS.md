# Current Failing Specs Analysis

**Total: 2129 examples, 19 failures**

## Breakdown

### ENM Specs (4 failures) - SKIPPED per your request
- Controller spec
- Service specs (2)  
- System spec
- **Status**: Known broken, you're not working on ENM now

### MaapSnapshot Spec (1 failure)
- Model spec: `spec/models/maap_snapshot_107_duplication_bug_spec.rb`
- **Status**: Bug reproduction spec

### Assignment Finalization Specs (3 failures)
- `spec/system/assignment_finalization_bug_reproduction_spec.rb` (2 failures)
- `spec/system/assignment_finalization_visibility_spec.rb` (2 failures)
- **Status**: Testing finalization visibility - related to your known finalization issues

### Assignment Selection Specs (8 failures)
- `spec/system/assignment_selection_spec.rb` - 8 failures
- **Status**: Testing assignment selection UI

### Card View Specs (2 failures)
- `spec/system/check_ins_card_view_spec.rb` - 2 failures
- **Status**: Form field rendering issues

## Recommendation

These are **more substantial failures** than I initially reported. Let me check what's actually failing.

