# Lucee EHCache Extension

[![Java CI](https://github.com/lucee/extension-ehcache/actions/workflows/main.yml/badge.svg)](https://github.com/lucee/extension-ehcache/actions/workflows/main.yml)

Cache provider for Lucee using [Ehcache 3](https://www.ehcache.org/). Supports heap and disk tiers, per-entry TTL, eviction policies, and disk persistence.

**Requires Lucee 7.0+** — uses maven-based classloading.

## Installation

Install via Lucee Admin, or pin in your environment:

```bash
LUCEE_EXTENSIONS=org.lucee:ehcache-extension:3.0.0.0-SNAPSHOT
```

## Documentation

Full documentation at **[docs.lucee.org/categories/cache](https://docs.lucee.org/categories/cache.html)**.

### Quick Example

```cfml
// Application.cfc
this.cache.connections[ "myCache" ] = {
  class: "org.lucee.extension.cache.eh.EHCache",
  storage: false,
  custom: {
    "maxelementsinmemory": "10000",
    "timeToLiveSeconds": "3600",
    "timeToIdleSeconds": "0",
    "overflowtodisk": "true",
    "diskpersistent": "true",
    "diskSizeMB": "100"
  },
  default: "object"
};

// Usage
cachePut( "key", "value", createTimespan( 0, 1, 0, 0 ), createTimespan( 0, 0, 30, 0 ), "myCache" );
result = cacheGet( "key", "myCache" );
```

### Configuration Options

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `eternal` | `false` | Never expire entries (ignores TTL/TTI) |
| `maxelementsinmemory` | `10000` | Max entries in the heap tier |
| `timeToLiveSeconds` | `86400` | Default TTL in seconds |
| `timeToIdleSeconds` | `86400` | Default TTI in seconds (see [TTI limitations](#tti-limitations)) |
| `overflowtodisk` | `true` | Overflow to a disk tier when heap is full |
| `diskpersistent` | `true` | Persist disk tier across restarts |
| `diskSizeMB` | `100` | Max disk tier size in MB |
| `trackItemMetadata` | `true` | Track per-entry creation time and timespans |
| `reportStatistics` | `false` | Include cache statistics in `cacheGetMetadata().custom` |

### Statistics

Set `reportStatistics` to `true` to include cache-level statistics in `cacheGetMetadata().custom`. Off by default — adds a struct allocation per `cacheGet()`.

Statistics are always collected by ehcache's built-in statistics service regardless of this setting. This flag only controls whether they're included in metadata output. `hitCount()` and `missCount()` (visible as `cache_hitcount`/`cache_misscount` in metadata) are always available.

| Key | Description |
| --- | ----------- |
| `hit_count` | Total cache hits (existing in v2) |
| `miss_count` | Total cache misses (existing in v2) |
| `get_count` | Total get operations (hits + misses) |
| `put_count` | Total put operations |
| `remove_count` | Total explicit removals |
| `eviction_count` | Entries evicted by capacity pressure |
| `expiration_count` | Entries expired by TTL/TTI |
| `hit_percentage` | Hit rate as a percentage (0-100) |
| `miss_percentage` | Miss rate as a percentage (0-100) |

Stats are cumulative — they survive `cacheClear()` and are not reset until the cache is re-initialised.

```cfml
var meta = cacheGetMetadata( "someKey", "myCache" );
dump( meta.custom.hit_percentage );   // e.g. 96.15
dump( meta.custom.eviction_count );   // e.g. 300
```

### trackItemMetadata

ehcache 2 stored per-entry metadata (creation time, TTL, TTI) directly on its `Element` class. ehcache 3 removed this — its `ExpiryPolicy` is stateless. When enabled, the extension maintains a per-entry metadata sidecar to restore this functionality, and a `CacheEventListener` keeps it in sync on expiry/eviction/removal.

Set to `false` to disable the sidecar and event listener. This reduces per-operation object allocation at the cost of:

- Per-entry TTL/TTI passed to `cachePut()` are ignored — all entries use cache-level defaults
- `cacheGetMetadata()` won't have per-entry creation time or timespans

Use `false` when you only need cache-level TTL/TTI and want lower GC pressure under sustained load.

## TTI Limitations

Time-to-idle (TTI) does not work as expected when combined with TTL. ehcache 3's `ExpiryPolicy` can only **extend** an entry's expiry on access, never shorten it. This means:

- If TTL and TTI are both set, the entry lives for the full TTL regardless of idle time
- TTI only takes effect when it's the sole expiry mechanism (no TTL, or TTL set to infinite/eternal)
- `containsKey()` doesn't trigger TTI — only `get()` does (we use `get() != null` for `contains()` to work around this)

This is a [deliberate design decision](https://github.com/ehcache/ehcache3/issues/1097) by the ehcache team, who consider TTI informally deprecated. For most use cases, TTL with capacity-based eviction is the recommended approach.

## Technical Details

Maven-based extension using embedded `/maven/` repo layout. Extension version tracks the core library (e.g. 3.11.1.0 bundles ehcache 3.11.1). Also includes javax.cache API 1.1.0 and SLF4J API 1.7.36.

## Issues

[Lucee JIRA - EHCache Issues](https://luceeserver.atlassian.net/issues/?jql=labels%20%3D%20ehcache)
