# Layout Migration TODO

## **🎯 Goal:**
Migrate all authenticated pages to use the new `authenticated-v2-0.html.haml` layout for consistent header, navigation, and action areas.

## **📋 Layout Structure:**
- **Header Area**: Title (left) + View Switcher/Primary Action (right)
- **Navigation Area**: "Back to X" links (optional)
- **Action Area**: Top-right actions (optional, designed for 1 button but flexible)
- **Content Area**: Main content with consistent card structure

## **✅ COMPLETED:**
- [x] Create `authenticated-v2-0.html.haml` layout
- [x] Migrate person show page
- [x] Migrate person public page  
- [x] Migrate person teammate page

## **🔄 IN PROGRESS:**
- [ ] None currently

## **⏳ PENDING MIGRATION:**

### **Person Pages:**
- [ ] person edit page
- [ ] person index page

### **Organization Pages:**
- [ ] organization show page
- [ ] organization index page
- [ ] employment management page
- [ ] employees page

### **Huddle Pages:**
- [ ] huddle index page
- [ ] huddle show page
- [ ] huddle new page
- [ ] my huddles page

### **Assignment Pages:**
- [ ] assignment index page
- [ ] assignment show page
- [ ] assignment new page

### **Other Pages:**
- [ ] profile edit page
- [ ] dashboard page
- [ ] any other authenticated pages

## **🔧 Migration Checklist:**
When modifying any page, ask: **"Should this page be migrated to the new layout?"**

### **Migration Steps:**
1. Change layout to `authenticated-v2-0`
2. Move title to header area
3. Move primary action/view switcher to header right
4. Move "back to" links to navigation area
5. Move top-right actions to action area
6. Ensure content follows card structure pattern

## **📝 Notes:**
- Layout inherits from `application.html.haml`
- All areas are optional - pages can implement what they need
- Action area designed for single button but handles multiple gracefully
- Navigation area blank if not implemented
- Use semantic versioning for layout updates (v2.1, v2.2, etc.)
