# Shopping Domain

## Purpose

Shopping helps the user collect things they intend to buy, group them into practical trips, and separate necessary purchases from vague wants.

This should be lighter than ordinary tasks because the main workflow is fast capture into a named shopping list, with only a few optional details when they are actually helpful.

## Product Shape

The first version supports:

- quick item capture into a shopping list
- list selection and list creation
- optional price
- optional store
- optional notes and quantity
- bought / skipped / archived status
- grouped shopping trip suggestions

Examples:

- grocery items grouped into a grocery trip
- pharmacy items grouped into a drugstore trip
- household supplies grouped by store type
- online-only items grouped separately

## Shopping vs Wish List

Shopping list and wish list should be related but distinct.

Shopping list:

- items the user intends to buy
- optimized around trips and errands
- organized by named shopping lists

Wish list:

- items the user is considering
- includes luxury, optional, or uncertain purchases
- optimized around decision quality and budget awareness

Some wish-list items may eventually move into the shopping list after a waiting period or decision.

## Possible Item Fields

A `ShoppingItem` might include:

- title
- shopping list name
- estimated cost
- notes
- specific store, optional
- quantity, optional
- status
- source domain, such as nutrition, routine, task, or manual
- created date
- purchased date

## Possible Wish List Fields

A `WishListItem` might include:

- title
- notes
- category
- estimated cost
- desire level
- usefulness level
- waiting period
- decision status
- reason wanted
- cheaper alternative
- reviewed date

## Interaction With Tasks / Planner

Shopping items can create or inform errand tasks, but not every item should become a task.

Planner should schedule shopping trips, not individual grocery items. A suggested shopping trip can be based on item urgency, store type, and calendar availability.

Shopping should not write directly to Apple Calendar. Any scheduled trip should flow through the existing Planner / ScheduledBlock system.

## Interaction With Nutrition / Budgeting

Nutrition can generate shopping items from meal plans or missing staples.

Budgeting can consume estimated and actual purchase costs, especially for optional or wish-list items.

## Implementation Sketch

```text
Models/
  ShoppingModels.swift

Persistence/
  SwiftDataModels/
    ShoppingItemRecord.swift
  Repositories/
    ShoppingRepository.swift
  SwiftDataRepositories/
    SwiftDataShoppingRepository.swift

Features/Shopping/
  Shopping list
  List grouping
  Wish list
```

Start with shopping items. Add wish-list decision support as a second step if needed.

## Design Principles

- Optimize for real trips and errands.
- Keep necessities visually distinct from optional purchases.
- Do not clutter Tasks with every shopping item.
- Let Budgeting participate without making Shopping feel like accounting.

## Open Questions

- Should wish list live inside Shopping or Budgeting?
- Should item categories be fixed, user-defined, or both?
- Should store types be user-defined?
- Should repeated purchases become templates?

## Status

First-pass Shopping is implemented in Swift with:

- `ShoppingItem`, `ShoppingTripGroup`, and status models
- SwiftData persistence through `ShoppingItemRecord` and `SwiftDataShoppingRepository`
- `ShoppingListViewModel`
- Home module access and a dedicated Shopping Quick Add widget
- active list, grouped trip view, history, bought/skipped/archive/reopen, delete, and search flows
- targeted model, repository, view-model, and Home conversion tests

Wish-list decision support, estimated/actual costs, budget integration, nutrition-generated items, repeated-purchase templates, and Planner-generated shopping trips remain planned.
