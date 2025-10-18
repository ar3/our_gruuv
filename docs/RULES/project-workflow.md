# Project Workflow Rules

This document defines the project workflow, deployment, and team collaboration processes.

## Git & Version Control

### Commit Messages
- Start commit messages with the new mechanic introduced, followed by a summary of other notable changes
- Don't list every change in commit messages

### Deployment Process
- When user says 'make it so', run the full specs, commit merge and push to main, then perform the Railway deploy steps

## Deployment

### Platform
- Use Railway exclusively for deployment
- Remove all other deployment options and focus on the Railway deploy flow

## Team Collaboration

### Workflow Confirmation
- **Always provide commit message, summary, and questions before implementation**
- **Wait for user confirmation** before starting any work
- **Confirmation phrases**: 
  - "Make it happen" = Start implementing the work
  - "Make it so" = Commit, merge, push to main, and deploy

### Code Changes
- **Ask for confirmation before making any changes** to existing code changes
- **Always ask for verification before committing** - after each unit of work, ask user to verify either with code review or manually walking through the UI before executing any commits
- **Write commit message before starting work** - write the top line commit message before beginning each unit of work to ensure clarity on what we're trying to accomplish

## Iteration Progression Framework

Our development follows a three-stage iteration cycle: **Functional => Usable => Lovable**

### Functional
- Solid, tested, and as bug-free as we can get it
- Core functionality works correctly
- UX, visual design, and overall delight are left wanting

### Usable  
- Easy to work with from a UX perspective
- Intuitive workflows and clear user guidance
- Visual design and overall delight may still be lacking

### Lovable
- Functional, usable, AND there is joy in working with it
- Delightful interactions and polished experience
- Users actively enjoy using the feature

### Usage
- **Always ask which iteration level we're targeting** when starting development chats
- Check-ins is a centerpiece feature for OurGruuv, so it must be lovable
- Most features should reach at least Usable before moving to new features

## Implementation Checklist

When following project workflow, ensure:
- [ ] Provide commit message and summary before starting work
- [ ] Wait for user confirmation before implementing
- [ ] Ask for verification before committing changes
- [ ] Use Railway exclusively for deployment
- [ ] Run full specs before 'make it so' deployments
- [ ] Ask which iteration level (Functional/Usable/Lovable) we're targeting
