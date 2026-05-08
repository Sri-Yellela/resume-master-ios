# Resume Master — Cross-Platform Sync

Last updated: 2026-05-08

## Feature Registry

| Feature | Web | iOS | Android | Notes |
|---------|-----|-----|---------|-------|
| Swipe card job feed        | ✅ | ✅ | ✅ | |
| Soft swipe → Queue         | ❌ | ✅ | ✅ | Web uses button fallback |
| Hard throw → Apply         | ❌ | ✅ | ✅ | Web uses button fallback |
| Star / save job            | ✅ | ✅ | ✅ | |
| Resume builder             | ✅ | ✅ | ✅ | |
| Section swipe-to-edit      | ❌ | ✅ | ✅ | Web uses click |
| Template picker            | ✅ | ✅ | ✅ | |
| PDF export                 | ✅ | ✅ | ✅ | |
| Auto-apply queue           | ✅ | ✅ | ✅ | |
| Admin panel                | ✅ | ✅ | ✅ | |
| Dark mode                  | ✅ | ✅ | ✅ | |
| Job detail expand          | ✅ | ✅ | ✅ | |
| Action badge notices       | ❌ | ✅ | ✅ | Web uses toast |
| ATS score per job          | ✅ | ✅ | ✅ | |
| Profile / settings         | ✅ | ✅ | ✅ | |

## Pending Sync Items

None.

## Data Model Version

Current shared model version: 1.0.0
All platforms must use the same Resume, Job, SwipeAction,
ResumeSection, ResumeField, and Template data structures.
When the model changes, bump this version and list the diff below.

### Model changelog
- 1.0.0 (initial): Resume, Job, Template, SwipeAction defined

## Admin Panel Sync

Admin panel must show identical data and controls on all platforms.
When a flag is toggled in web admin, iOS and Android must reflect
it within one app open (via API poll or push).
