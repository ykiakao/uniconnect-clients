# Mobile Demo Activities Design

## Goal

Deliver a reliable student demonstration using the existing EduKMais demo accounts and seeded academic data. The presentation flow is login, student dashboard, activities, activity details, and grades. The web panel, institutional invitations, chat, submissions, and session refresh are outside this delivery.

## User And Primary Flow

The user is a student already registered in the fictional EduKMais institution. After signing in, the student reaches the dashboard, opens the complete activities list, narrows it with text search or priority filters, opens an activity, and then consults grades.

## Scope

### Included

- Preserve the existing authenticated student routes and role guard.
- Fetch activities through the existing `activitiesProvider` and `AcademicApiService` using the authenticated token and tenant slug.
- Keep the activities list, pull-to-refresh, text search, priority filter, empty state, retry state, and navigation to a detail page.
- Present activity details as read-only: subject, title, deadline, instructions, support materials when supplied, and responsible teacher.
- Remove controls that imply a completed workflow not backed by the API: sending a message and starting or submitting an activity.
- Keep the grades page as the final consultation screen in the demonstration route.

### Excluded

- Activity submission, attachments upload, grading mutations, chat, notifications, institutional invitation, dashboard metrics work, and web panel work.
- New API endpoints or database schema changes.

## Technical Design

`ActivitiesPage` remains responsible for local search and priority-filter state. It observes `activitiesProvider`, which calls `AcademicApiService.listActivities` with the current session token and tenant slug. The service builds the list from the existing courses, classes, and activities API routes, then orders activities by deadline.

`ActivityDetailPage` resolves an item from the already fetched activities list through `activityByIdProvider`. Its UI stays read-only. The static points field is not presented as live data because the current activity model does not carry a points value. Where criteria or materials are absent from the API response, the page communicates their absence rather than implying an available submission flow.

No routing, authentication contract, API contract, or persistent model changes are required.

## States And Errors

- Loading: show the existing progress indicator while activities are requested.
- Request failure: show the existing retry state and reload the provider on retry.
- Empty list or empty filter result: show the existing empty state and allow clearing filters.
- Missing activity ID: show the existing not-found state and let the user return to activities.
- Refresh: invalidate the provider and wait for the next API result without retaining stale failure state.

## Acceptance Criteria

- A valid EduKMais student login reaches the student dashboard.
- The dashboard link opens the activities list without an authorization or routing failure.
- The list displays activity data returned by the API for the authenticated tenant.
- Search and priority filters update the displayed list without another request.
- Selecting an item opens a read-only detail page with no message, start, or submit action.
- The user can navigate from the main flow to the grades page.
- `flutter analyze` and `flutter test` pass after the changes.

## Demonstration Boundary

The presentation explicitly states that the accounts and academic records belong to the fictional EduKMais tenant. It demonstrates authenticated, tenant-aware data retrieval, not a complete virtual learning environment.
