# Active TODOs - Permissioning System Development

## 🎯 **Final Goal: Push Changes with Solid Permissioning System**

### **Phase 1: "Modify Myself" System** ✅
- [x] Understand current self-modification capabilities
- [x] Test and verify self-editing works correctly
- [x] Ensure proper authorization for self-modification
- [x] **Bonus**: Unified person page architecture (show + manager combined)
- [x] **Cleanup**: Restructured layout with full-width sections and consistent design
- [x] **Cleanup**: Created reusable view switcher partial
- [x] **Cleanup**: Added multi-company context section for organizational switching
- [x] **Cleanup**: Restructured About Me section with 8:4 column split (stats left, actions right)
- [x] **Cleanup**: Restructured Security & Permissions section with 8:4 column split
- [x] **Cleanup**: Fixed route issues and HAML indentation
- [x] **Cleanup**: Improved navigation layout (Back link below header, view switcher on right)
- [x] **Cleanup**: Updated view switcher to show current selection as button text
- [x] **Cleanup**: Created STYLES.md documentation for standard page patterns
- [x] **Cleanup**: Fixed header margin from mb-4 to mb-2 for tighter spacing
- [x] **Cleanup**: Restructure Security & Permissions section (always visible, show placeholders for restricted content)
- [x] **Cleanup**: Restructure Organization Permissions section (8:4 layout, single modify button, permission-based UX)
- [x] **Cleanup**: Enhanced permissions display (ALLOWED/BLOCKED/INHERITED statuses, inheritance source, all 3 permission types)
- [x] **Cleanup**: Fixed access conditions and warning tooltips for permission modification
- [x] **Cleanup**: Fixed inheritance display nil errors and MAAP permission bug
- [x] **Cleanup**: Improved inheritance logic (nil + no parent = BLOCKED, nil + parent = INHERITED)
- [x] **Cleanup**: Fixed access logic (anyone with can_manage_employment can edit permissions)
- [x] **Cleanup**: Fixed disabled button/tooltip not showing when user lacks employment management permissions
- [ ] **Cleanup**: Complete Align section restructuring (employment history with 8:4 split)
- [ ] **Cleanup**: Add Collaborate section (huddles and feedback)
- [ ] **Cleanup**: Add Transform section (performance and growth)
- [ ] **Cleanup**: Move multi-company context to bottom
- [ ] **Standardization**: Convert all show/index pages to use new header layout pattern

### **Phase 2: Employment Management Permissions**
- [ ] Add "manage employment" permission to user
- [ ] Test ability to manage own employment
- [ ] Test ability to manage others' employment
- [ ] Verify permission-based UI shows correct states

### **Phase 3: Employment Creation Permissions**
- [ ] Add "create employee" permission to user
- [ ] Test creating employees from potential employees list
- [ ] Test creating employees from scratch
- [ ] Test creating hierarchical relationships (direct reports of direct reports)

### **Phase 4: Permission Hierarchy Testing**
- [ ] Remove "manage employment" permission
- [ ] Verify can still manage direct reports' employment
- [ ] Verify can still manage direct reports' direct reports' employment
- [ ] Verify cannot manage employment of non-hierarchical employees
- [ ] Verify can still create new employees

## 🔍 **Person Page Architecture Analysis**

### **Current Page Versions (3 total)**
1. **Public Page** - Social media shareable professional identity
2. **Unified Show Page** - Personal view + Professional data + Management actions (all integrated)
3. **Teammate Page** - Organization-specific teammate view

### **Architecture Decisions Made** ✅
- [x] **Show vs Manager Page**: Combined into single unified page
  - Show page: Personal view with integrations (Google, Asana, Jira, Slack) + Professional data + Management actions
  - Manager page: Redirects to show page (functionality integrated)
  - **Result**: Single page with role-based sections for better UX and cleaner architecture

### **Public Page Vision**
- [ ] **Dream Goal**: "Make the public profile page such that people will want to share it on their social media accounts… ideally this page will challenge what is the center of their professional identity, rivaling LinkedIn"

## 🚀 **Immediate Next Steps**
1. Test current permission system
2. Implement "modify myself" functionality
3. Add employment management permissions
4. Test hierarchical management capabilities

## 📝 **Notes**
- Current permission system uses Pundit with `can_manage_employment?` and `can_create_employment?`
- Person pages have consistent view switching with permission-based UI
- Authorization failures redirect appropriately (person views → public, others → homepage)
