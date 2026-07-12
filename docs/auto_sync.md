# Auto Sync & Notification Preferences

How the **Data & Storage → Auto Sync** setting and the two **Notifications** switches
behave, and which code owns each part.

## Auto Sync

Auto Sync decides whether an **automatic** background refresh is allowed to hit the
network. It is a data-saver control, not a sync engine: nothing runs on a timer and no
writes are queued offline.

### Modes

| Mode (`AutoSyncMode`) | Settings label | Refreshes over WiFi | Refreshes over mobile data |
| --- | --- | --- | --- |
| `dataAndWifi` | On | yes | yes |
| `wifiOnly` *(default)* | WiFi Only | yes | no |
| `off` | Off | no | no |

Persisted as the enum's `name` under the SharedPreferences key `auto_sync_mode`
(`PrefsKeys.autoSyncMode`).

### What the gate applies to

`AutoSyncProvider.shouldSync()` is consulted by `HeritageProvider.fetchSites()` — the
heritage catalogue refresh — and nothing else.

**Automatic refreshes are gated. User-initiated actions are not.** A search, a category
filter, or an explicit `forceRemote` (pull-to-refresh) always goes to the network: the
user asked for fresh data by acting, so honouring a data-saver preference there would
just look broken. Concretely, in `fetchSites`:

```dart
final isUserInitiated = forceRemote || query != null || category != null;
final canSync = isUserInitiated ? true : await autoSyncProvider.shouldSync();
```

To change that policy, change `isUserInitiated` — it is the single decision point.

### Online vs offline data access

The two paths are separate repository methods, and the distinction is load-bearing:

| Method | Behaviour |
| --- | --- |
| `HeritageRepository.getHeritageSites(...)` | **Remote-first.** Calls the API; falls back to the SQLite cache only if the request throws. |
| `HeritageRepository.getCachedHeritageSites({limit})` | **Cache-only.** Reads SQLite. Issues no HTTP request under any circumstances. |

When the gate says no, `fetchSites` takes the cache-only method. (Historically it called
the remote-first one, so Auto Sync = Off still made the request — the setting saved no
data at all. The cache-only API exists to make that class of bug impossible; a unit test
in `test/data/heritage_repository_cache_test.dart` asserts the remote datasource is never
touched.)

Both methods return a `HeritageSitesResult` carrying a `HeritageDataSource`
(`remote` | `cache`), so callers always know where the data came from rather than
guessing. That drives two things:

* **Logging** — the repository logs `… sites from REMOTE` / `… from CACHE` on every
  fetch, including which of the two cache paths it took.
* **The "Offline data" badge** — `HeritageProvider.isShowingCachedData` mirrors the
  reported source, and the heritage search screen shows a `cloud_off` chip
  (`l10n.offlineData`) while it is true. It covers both reasons for stale data: the gate
  blocked the refresh, *or* the request failed and the repository fell back.

## Notification preferences

Both switches are persisted **and** applied to the machinery that actually delivers the
notification. A local flag alone would not stop anything — the server pushes to FCM
topics, and the geofences live in the OS.

| Switch | Pref key | Default | What it actually does |
| --- | --- | --- | --- |
| Push Notifications | `push_notifications_enabled` | on | Subscribes/unsubscribes the FCM topics `all_users` and `lang_<ne\|en>`, which is what the backend broadcasts to (`_topic_for_target` in `apps/notifications/views.py`). |
| Nearby Site Alerts | `nearby_site_alerts_enabled` | on | Starts/stops `NearbyService`: the OS-native heritage geofences whose ENTER event posts a validated fix, which the server turns into the "you are near" push. |

`NotificationPrefsProvider` owns both. Startup ordering matters:

* `NotificationService._acquireTokenAndRegister()` reads the push pref itself once it has
  an FCM token, so a device that opted out never re-subscribes on launch.
  `syncAfterLogin()` does the same — logging in must not silently re-enable push.
* `NotificationPrefsProvider.applyOnStartup()` arms the geofences only if Nearby Site
  Alerts is on. `NearbyService.stop()` removes every region it registered; cancelling the
  Dart subscription alone would leave the native geofences armed.

The language topic follows the current UI language, so the settings screen passes
`localeProvider.locale.languageCode` when toggling push.

## Tests

* `test/providers/auto_sync_provider_test.dart` — the full `shouldSync()` matrix
  (mode × connectivity) plus persistence. `AutoSyncProvider` takes an injectable
  `ConnectivityCheck`, so no platform channel is involved.
* `test/data/heritage_repository_cache_test.dart` — cache-only really is cache-only
  (a remote datasource that throws if touched at all), plus the remote-first path's
  source reporting and its fallback/rethrow behaviour.
