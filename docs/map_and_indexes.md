# Live Map Architecture, Composite Indexes & Tile Provider Policy

## 1. OpenStreetMap Tile Provider Usage Policy Compliance

CleanSpot uses OpenStreetMap standard tile layers (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`) under the official [OpenStreetMap Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).

### Strict Compliance Requirements Enforced in Code:

1. **Custom Valid User-Agent / Package Identifier**:
   - OpenStreetMap policy prohibits generic or blank user agents.
   - Configured in `TileLayer`:
     ```dart
     TileLayer(
       urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
       userAgentPackageName: 'app.cleanspot.dengue',
     )
     ```
2. **Attribution**:
   - Clear attribution is displayed on the map interface: `© OpenStreetMap contributors` with a link to OSM copyright.
3. **No Heavy Bulk Scraping**:
   - Tiles are rendered on-demand during map viewport interactions (pan/zoom).
   - Tile caching via standard HTTP caching is honored; offline bulk downloading of national tiles is prohibited.
4. **Alternative Production Tile Endpoints**:
   - For high-volume municipal deployments, a self-hosted vector tile server or dedicated commercial provider (e.g. Mapbox, Stadia Maps, Jawg) can be configured via environment settings.

---

## 2. Firestore Composite Indexes

To support bounding-box / geohash queries, category filters, and chronological ordering of approved reports, the following composite indexes are deployed in `firestore.indexes.json`:

| Collection | Fields & Order | Query Purpose |
| :--- | :--- | :--- |
| `reports` | `reporterId` ASC, `createdAt` DESC | User's own report history stream (`my-reports`) |
| `reports` | `status` ASC, `geohash` ASC, `createdAt` DESC | Spatial bounding-box & geohash proximity range queries on approved reports |
| `reports` | `status` ASC, `category` ASC, `createdAt` DESC | Hazard category filtering on approved live map hotspots |
| `reports` | `status` ASC, `district` ASC, `createdAt` DESC | Administrative district aggregation and filtering |
| `reports` | `status` ASC, `createdAt` DESC | Chronological ordering and date range filtering (last 24h, 7d, 30d) |
| `redemptions` | `userId` ASC, `redeemedAt` DESC | Citizen redemption history and coupon management |

---

## 3. Privacy & Reporter Anonymity

- **Strict Anonymization**: Bounding-box and map queries only expose public hazard attributes:
  - `reportId`, `location (lat, lng)`, `category`, `riskLevel`, `createdAt`, `imageUrl`, `addressText`.
- **Callable Sanitization**: Tapping a map pin invokes `getPublicReportDetails`, which enforces server-side sanitization.
- Under **no circumstances** are `reporterId`, `reporterName`, `email`, `pointsAwarded`, or `pointsTransactionId` transferred to the public map client or detail bottom sheet.
