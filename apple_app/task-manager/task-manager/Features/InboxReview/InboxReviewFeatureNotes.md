# Inbox Review Feature

Standalone sticky-note review flow for routing raw captures into the right module without forcing everything through Home or a single universal form.

## Purpose

Inbox Review owns the pending-review queue, reviewed-history list, destination selection, and manifest-driven inline forms for capture processing.
Home launches the inbox, but the routing and persistence rules live in the shared capture models and intake registry.

## Current Objects

- `InboxReviewView`
- `InboxReviewViewModel`
- `CaptureIntakeRegistry`
- `CaptureReviewDraft`
- `CaptureIntakeKindProviding`

## Current Scope

- Tabs are the default module picker.
- Tabs and templates can be reordered locally from the inbox surface and the order persists on the device.
- Template rows use a dedicated drag handle for reordering and a long-press context menu for saved-template actions.
- The template row includes a trailing plus action that creates a saved custom copy of the current template.
- Editing from the template menu updates the saved template itself; form edits made after template selection remain draft-only for that review item.
- The legacy tile picker is treated as retired implementation detail.
- Optional intake sections open and close like dropdowns.
- task conversion
- project idea conversion
- project note conversion
- shopping-item conversion
- practice-piece conversion
- people-memory conversion
