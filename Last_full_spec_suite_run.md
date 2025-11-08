# Last Full Spec Suite Run

## Run Date
2025-11-08

## Execution Method
Run in segments to avoid timeouts and identify issues more efficiently. Never run `bundle exec rspec` without arguments.

## Status
✅ **Complete** - All segments finished

**Started**: 2025-11-08 13:51:09
**Completed**: 2025-11-08 14:30:45

## Timing Results

### Model Specs
- **Status**: ✅ Complete
- **Time**: 50.89 seconds (55.74 seconds total with load time)
- **Date/Time**: 2025-11-08 13:51:09
- **Examples**: 993
- **Failures**: 0

### Controller Specs
- **Status**: ✅ Complete
- **Time**: 46.22 seconds (51.50 seconds total with load time)
- **Date/Time**: 2025-11-08 13:52:11
- **Examples**: 402
- **Failures**: 0

### Request Specs
- **Status**: ✅ Complete
- **Time**: 28.77 seconds (33.91 seconds total with load time)
- **Date/Time**: 2025-11-08 13:53:08
- **Examples**: 159
- **Failures**: 0

### System Specs - Abilities
- **Status**: ✅ Complete
- **Time**: 88.32 seconds (93.37 seconds total with load time)
- **Date/Time**: 2025-11-08 13:53:48
- **Examples**: 39
- **Failures**: 1

### System Specs - Aspirations
- **Status**: ✅ Complete
- **Time**: 26.05 seconds (31.06 seconds total with load time)
- **Date/Time**: 2025-11-08 13:55:24
- **Examples**: 6
- **Failures**: 1

### System Specs - Assignments
- **Status**: ✅ Complete
- **Time**: 147.7 seconds (152.62 seconds total with load time)
- **Date/Time**: 2025-11-08 13:55:57
- **Examples**: 44
- **Failures**: 10

### System Specs - Check-ins
- **Status**: ❌ Error
- **Time**: 0.00009 seconds (5.13 seconds total with load time)
- **Date/Time**: 2025-11-08 14:16:13
- **Examples**: 0
- **Failures**: 1 error (cannot load shared_examples/check_in_form_fields)

### System Specs - Finalization
- **Status**: ✅ Complete
- **Time**: 64.41 seconds (67.62 seconds total with load time)
- **Date/Time**: 2025-11-08 14:16:26
- **Examples**: 27
- **Failures**: 5

### System Specs - Goals
- **Status**: ✅ Complete
- **Time**: 242.5 seconds (245.82 seconds total with load time)
- **Date/Time**: 2025-11-08 14:17:42
- **Examples**: 54
- **Failures**: 19

### System Specs - Huddles
- **Status**: ✅ Complete
- **Time**: 90.12 seconds (96.00 seconds total with load time)
- **Date/Time**: 2025-11-08 14:22:39
- **Examples**: 32
- **Failures**: 3

### System Specs - Misc
- **Status**: ✅ Complete
- **Time**: 83.03 seconds (87.80 seconds total with load time)
- **Date/Time**: 2025-11-08 14:24:39
- **Examples**: 31
- **Failures**: 3

### System Specs - Observations
- **Status**: ✅ Complete
- **Time**: 144.1 seconds (150.13 seconds total with load time)
- **Date/Time**: 2025-11-08 14:26:21
- **Examples**: 32
- **Failures**: 1

### System Specs - Positions and Seats
- **Status**: ✅ Complete
- **Time**: 104.76 seconds (109.04 seconds total with load time)
- **Date/Time**: 2025-11-08 14:28:54
- **Examples**: 38
- **Failures**: 3

### System Specs - Teammates
- **Status**: ✅ Complete
- **Time**: 420.0 seconds (425.07 seconds total with load time)
- **Date/Time**: 2025-11-08 14:30:45
- **Examples**: 83
- **Failures**: 40

## Total Summary
- **Total Examples**: 1,554 (993 models + 402 controllers + 159 requests + 386 system)
- **Total Failures**: 88 (0 models + 0 controllers + 0 requests + 88 system)
- **Total Time**: ~22 minutes (when run in segments)
- **System Spec Examples**: 386
- **System Spec Failures**: 88

## Known Issues to Fix

### High Priority
1. **System Specs - Check-ins**: Load error - cannot load shared_examples/check_in_form_fields
2. **System Specs - Teammates**: 40 failures (highest failure count)
3. **System Specs - Goals**: 19 failures
4. **System Specs - Assignments**: 10 failures
5. **System Specs - Finalization**: 5 failures

### Notes
- All model, controller, and request specs passed (0 failures)
- System specs have 88 total failures across 386 examples
- Check-ins folder has a load error preventing any specs from running
- Teammates folder has the highest failure rate (40 failures out of 83 examples)
- Total execution time: ~22 minutes when run in segments
