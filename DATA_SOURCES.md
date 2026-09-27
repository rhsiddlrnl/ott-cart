# Data Sources & API Integration

Research notes on where the data comes from and how it fills the tables in [DESIGN.md](DESIGN.md).
Researched **2026-09-19**. Re-check prices and deals before the final presentation, because they change often.

---

## 1. Services in scope

| Service | TMDB `provider_id` (KR) | Notes |
|---|---|---|
| Netflix | `8` | |
| Netflix Standard with Ads | `1796` | Listed as a **separate provider**. Some titles aren't in the ad tier |
| Disney+ | `337` | |
| TVING | `1883` | Sells bundles and the Apple TV 패스 add-on (see below) |
| wavve | `356` | The only KR service with **rent/buy** data |
| Watcha | `97` | |
| Coupang Play | `1881` | Needs a Coupang WOW membership. Carries HBO content |
| Apple TV+ | `350` | Standalone service in KR. Also reachable through TVING (Apple TV 패스 add-on, or Premium) |

Provider IDs come from JustWatch's KR provider list (TMDB's watch data is supplied by JustWatch and uses the same IDs). **Confirm them once** with:
```
GET https://api.themoviedb.org/3/watch/providers/tv?watch_region=KR
```

### Partner content: what actually needs special handling

| Content | Where it is in Korea | Needs handling? |
|---|---|---|
| **HBO / HBO Max / Warner Bros.** | **Coupang Play**, exclusive since 2025-03-21 | **No.** The data lists these titles under Coupang Play directly |
| **Apple TV+** | Its own service, **plus** inside TVING: the **Apple TV 패스** add-on (₩4,400/month, since 2026-01-28, only on top of eligible TVING plans), and the Apple TV+ zone in **TVING Premium** (since 2024-12-10) | **Yes.** A title shows up as "Apple TV+" in the data, but TVING users can reach it only through Premium or the add-on |
| **Sony** | No dedicated service or zone found in KR | **No.** Sony films appear under whichever service licensed them |
| **TVING × wavve / × Disney+ bundles** | TVING × wavve plans, TVING × Disney+ plans, and the 3 PACK (2025-11-18) | **Yes.** One payment unlocks several services |

Bundles are cases where **one plan unlocks several services**, which is handled by the `plan_services` table. The Apple TV 패스 is a plan that **can only be bought on top of certain other plans**, which is handled by the `addon_bases` table (DESIGN.md §3).

---

## 2. APIs compared

| API | KR support | Rent/buy prices for KR | Verdict |
|---|---|---|---|
| **TMDB** (`watch/providers`, data from JustWatch) | ✅ All 6 services + Apple TV+ | ❌ Only says rent/buy *exists*, never the price | **Use this** as the main source |
| **Streaming Availability API** (Movie of the Night) | ❌ KR is not in its country list | — | Not usable |
| **Watchmode** | ❓ 54 regions, KR not confirmed (`GET /v1/regions/` needs a free key) | Would include price if KR is covered | Optional: check with a free key |
| **JustWatch** (official) | ✅ | ❌ Almost no KR rental stores | Partner-only API. The unofficial GraphQL endpoint breaks its terms, so don't build on it |
| **KOBIS / KMDb** (Korean government) | ✅ Film info, box office | ❌ No OTT data | Optional for Korean film metadata |

### The rental price gap (important)
In JustWatch's KR data, the only one of your services with **rent/buy** listings is **wavve**. It also lists Amazon Video and a few niche stores. **Google Play, the Apple TV store and Naver Series On are not covered.** No API found in this research provides Korean rental prices.

**Decision:** store rental prices **by hand** for a demo set of titles, and mark each row's origin in `availability.source` (`'tmdb'` or `'manual'`). In the presentation, say it plainly: "Subscription availability is collected automatically. Rental prices are curated because no public API provides them for Korea."

---

## 3. TMDB setup

1. Create an account at themoviedb.org → Settings → API, and request a developer key (non-commercial, free).
2. You get two credentials. Use either one:
   - `api_key` as a query parameter (v3), **or**
   - **API Read Access Token** as a header: `Authorization: Bearer <token>`
3. Keep it in a config file (`config.php` / `config.properties`) that isn't shared publicly.
4. **Attribution** (required): show the TMDB logo with "This product uses the TMDB API but is not endorsed or certified by TMDB", **and** credit **JustWatch** wherever watch-provider data is shown.
5. Rate limit is roughly 40–50 requests/second. A batch import with a short delay between calls is enough.

---

## 4. Endpoints → tables mapping

### 4.1 One-time seeding

| Endpoint | Fills | How |
|---|---|---|
| `GET /3/watch/providers/movie?watch_region=KR`<br>`GET /3/watch/providers/tv?watch_region=KR` | `services` | Insert only the 8 providers in §1. `provider_id` → `tmdb_provider_id`, `provider_name` → `name`, `logo_path` → `logo_url` (prefix `https://image.tmdb.org/t/p/w92`) |
| `GET /3/genre/movie/list?language=ko-KR`<br>`GET /3/genre/tv/list?language=ko-KR` | `genres` | IDs don't collide between the two lists, so both go in one table. Use TMDB's `id` as `genre_id`, and store the Korean `name` |
| *(manual)* official pricing pages | `plans`, `plan_services`, `addon_bases` | See §5 |
| *(manual)* | `services` rows with `kind='store'` | Google Play, Apple TV store, Naver Series On |

### 4.2 Title import (batch job)

Pull popular titles that are on your services in Korea:

```
GET /3/discover/movie?watch_region=KR
    &with_watch_providers=8|337|356|97|1883|1881|350     # | = OR
    &with_watch_monetization_types=flatrate
    &language=ko-KR&sort_by=popularity.desc&page=1..5
GET /3/discover/tv?...same params...
```

For each result, fetch the details and the providers in **one call**:

```
GET /3/movie/{id}?language=ko-KR&append_to_response=watch/providers
GET /3/tv/{id}?language=ko-KR&append_to_response=watch/providers
```

| Response field | → Column |
|---|---|
| `id` | `titles.tmdb_id` |
| `"movie"` / `"tv"` (which endpoint) | `titles.title_type` |
| movie `title` / tv `name` | `titles.name` (Korean when available) |
| movie `release_date` / tv `first_air_date` (first 4 chars) | `titles.release_year` |
| `poster_path` | `titles.poster_url` (prefix `https://image.tmdb.org/t/p/w342`) |
| `genres[].id` | `title_genres` rows |
| `["watch/providers"].results.KR.flatrate[].provider_id` | `availability` rows, `access_type = subscription`, `price = NULL`, `source = 'tmdb'` |
| `…results.KR.ads[]` | same as flatrate (ad-supported access still counts as subscription access) |
| `…results.KR.rent[]` / `.buy[]` | `availability` rows with `access_type = rent/buy`, **price entered by hand** (`source = 'manual'`) |
| `…results.KR.link` | optional: a JustWatch page link to show users |

Ignore providers that aren't in `services`. If `results.KR` is missing, the title isn't streamable in Korea. Keep the title anyway so the site can say so.

**Example response (shape):**
```json
{
  "id": 496243,
  "title": "기생충",
  "release_date": "2019-05-30",
  "watch/providers": {
    "results": {
      "KR": {
        "link": "https://www.themoviedb.org/movie/496243-parasite/watch?locale=KR",
        "flatrate": [ { "provider_id": 1883, "provider_name": "TVING", "logo_path": "/…" } ],
        "rent":     [ { "provider_id": 356,  "provider_name": "wavve", "logo_path": "/…" } ]
      }
    }
  }
}
```
*(Illustrative shape only. The real providers for this title may differ.)*

### 4.3 Upsert SQL (MySQL)

```sql
INSERT INTO titles (tmdb_id, title_type, name, release_year, poster_url)
VALUES (?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE name = VALUES(name), poster_url = VALUES(poster_url);

INSERT INTO availability (title_id, service_id, access_type_id, price, source)
SELECT ?, s.service_id, 1, NULL, 'tmdb'
FROM services s WHERE s.tmdb_provider_id = ?
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;
```

### 4.4 Keeping it fresh
- Re-run the import weekly. Before the run, record `@run_start = NOW()`. After it, delete `source = 'tmdb'` availability rows with `updated_at < @run_start`, because those titles have left the service.
- **Never auto-delete `source = 'manual'` rows.**
- Live user search: call `GET /3/search/multi?query=…&language=ko-KR&region=KR` and import the chosen title on demand.

---

## 5. Plans to enter by hand (template)

You'll look up the prices yourself. This section only shows **how each kind of plan becomes rows**.
Record the date you checked each price in `plans.price_checked_on`.

### Three kinds of plan (`plans.plan_type`)

| Type | Meaning | Example |
|---|---|---|
| `base` | A normal plan of one service | Netflix 스탠다드, TVING 베이직 |
| `bundle` | One payment that unlocks several services | TVING × wavve, TVING × Disney+, 3 PACK |
| `addon` | Can't be bought alone. Only on top of certain plans | **TVING Apple TV 패스** (₩4,400/month, since 2026-01-28) |

### How rows are filled

| Plan (`plans`) | `plan_type` | Sold by | Unlocks (`plan_services`) | Can be added to (`addon_bases`) |
|---|---|---|---|---|
| Netflix 광고형 스탠다드 | base | Netflix | `1796` | |
| Netflix 스탠다드 / 프리미엄 | base | Netflix | `8`, `1796` | |
| TVING 광고형 스탠다드 / 베이직 / 스탠다드 | base | TVING | `1883` | |
| TVING 프리미엄 | base | TVING | `1883`, `350`* (Apple TV+ included) | |
| TVING × wavve (더블 광고형 / 슬림 / 베이직 / 스탠다드 …) | bundle | TVING | `1883`, `356` | |
| TVING × Disney+ | bundle | TVING | `1883`, `337` | |
| 3 PACK (TVING + wavve + Disney+) | bundle | TVING | `1883`, `356`, `337` | |
| **TVING Apple TV 패스** | **addon** | TVING | `350` | TVING 광고형 스탠다드, 베이직, 스탠다드; TVING × wavve 더블 광고형, 슬림, 베이직, 스탠다드 |
| wavve / Disney+ / Watcha plans | base | each | own ID | |
| Coupang WOW membership | base | Coupang Play | `1881` | |
| Apple TV+ (standalone) | base | Apple TV+ | `350` | *(optional; see below)* |

\* Confirmed on [TVING's plan page](https://www.tving.com/bill/subscription/plan) (2026-09-19): Premium includes Apple TV+ content, and the Apple TV 패스 is listed separately at the bottom of the page.

**Apple TV 패스 eligibility** (from the 2026-01 launch news): it can be added to TVING monthly/annual 광고형 스탠다드, 베이직 and 스탠다드, and to TVING × wavve 더블 광고형, 슬림, 베이직 and 스탠다드. It **can't** be added to TVING × Disney+ bundles, telecom partner plans or coupon plans.

**Standalone Apple TV+:** it exists in Korea and is in the data as provider `350`. It's probably rare in practice, so including it is optional. If you leave it out, Apple titles can only be covered through TVING.

**The Netflix trick:** the ad plan unlocks only provider `1796`, and Standard/Premium unlock `8` **and** `1796`. A title missing from the ad tier is then correctly treated as not covered by the ad plan.

**Tip:** start with only the plans you need for the demo (for example the cheapest non-ad plan and the ad plan of each service, one or two bundles, and the Apple TV 패스). The schema supports every plan, but you don't have to enter all of them.

---

## 6. Sources
- [Korea Herald: Coupang Play to exclusively provide HBO, HBO Max content](https://www.koreaherald.com/article/10440838)
- [Korea Herald: TVING partners with Disney+ for a 3-way bundle](https://www.koreaherald.com/article/10618377)
- [CJ Newsroom: TVING opens Apple TV+ brand zone (Premium plan)](https://cjnews.cj.net/%ED%8B%B0%EB%B9%99-apple-tv-%EB%B8%8C%EB%9E%9C%EB%93%9C%EA%B4%80-%EC%98%A4%ED%94%88%EA%B8%80%EB%A1%9C%EB%B2%8C-%EC%BD%98%ED%85%90%EC%B8%A0-%EB%8C%80%ED%8F%AD-%EA%B0%95/)
- [TVING Wikipedia (Apple TV+ zone, TVING–Wavve merger)](https://en.wikipedia.org/wiki/TVING)
- [Daum News 2026-01-31: TVING launches the Apple TV 패스](https://v.daum.net/v/20260131071304513)
- [TVING plan page](https://www.tving.com/bill/subscription/plan) (Premium includes Apple TV+; Apple TV 패스 listed at the bottom)
- [Streaming Availability API: supported countries](https://docs.movieofthenight.com/resource/countries)
- [Watchmode API](https://api.watchmode.com/)
- [TMDB: watch providers reference](https://developer.themoviedb.org/reference/watch-providers-movie-list)
- [Pickle Plus: OTT price comparison, 2026-05](https://pickle.plus/blog/ott-comparison-cheapest-options) (premium prices)
- [OTT price overview 2026 (foxcg)](https://foxcg.com/ott-service-recommendations/) (Netflix plan prices)
- The KR provider list and IDs were checked against JustWatch's public KR data on 2026-09-19
