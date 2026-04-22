# Changelog

All notable changes to the Lucee EHCache Extension.

## 3.11.1.0 (unreleased)

Major rewrite — ehcache 2 to ehcache 3, Maven-native build, Lucee 7+ only.

### Breaking changes

- **Requires Lucee 7.0.4.21 / 7.1+** — uses Maven classloading for cache classes via the `maven:` manifest attribute. The maven cache provider support shipped in 7.1 and was backported to 7.0.4.21 ([LDEV-6270](https://luceeserver.atlassian.net/browse/LDEV-6270)).
- **RMI distribution removed** — ehcache 3 dropped built-in RMI. All distributed config fields
  (automatic/manual discovery, listener, bootstrap, replication) are gone. Use the Redis cache
  extension for distributed caching.
- **REST/SOAP remote cache client removed** — dead code that talked to ehcache-server (separate WAR)
- **Disk cache format incompatible** — v2 disk caches will not migrate to v3. Clear disk caches
  before upgrading.
- **`memoryEvictionPolicy` removed** — v3 does not expose LRU/LFU/FIFO as configurable choices
- **`overflowToDisk` removed** — v3 uses a tiered storage model (heap -> disk) instead of overflow
- **`maxElementsOnDisk` replaced by `diskSizeMB`** — v3 sizes disk tier in MB, not element count

### Added

- ehcache 3.11.1 (was 2.10.9.2)
- Maven-native build system (replaces Ant + bundled JARs)
- Per-entry TTL/TTI via custom `ExpiryPolicy` (preserves Lucee's `cachePut()` timeout behaviour)
- Cache event listener for metadata sidecar cleanup on expiry/eviction/removal
- Java 11 minimum (was 8)

### Changed

- `maxelementsinmemory` renamed to `heapEntries`
- `maxelementsondisk` replaced by `diskSizeMB` (MB-based sizing)
- Programmatic cache configuration via builders (replaces dynamic XML generation)
- `CacheManager.close()` replaces `CacheManager.shutdown()` for lifecycle
- `cache.get(key)` returns value directly (v2 returned `Element` wrapper)
- `cache.clear()` replaces `cache.removeAll()`
- `Status.AVAILABLE` replaces `Status.STATUS_ALIVE`
- `cache.containsKey(key)` replaces `cache.isKeyInCache(key)`

### Removed

- `EHCacheClassLoader.java` — RMI-specific classloader hack
- `LuceeRMIAsynchronousCacheReplicator.java`
- `LuceeRMICacheReplicatorFactory.java`
- `LuceeRMISynchronousCacheReplicator.java`
- `remote/` package — REST/SOAP client (Converter, RESTClient, SoapClient, SAX parsers)
- Bundled JARs (`source/java/libs/`)
- Ant build (`build.xml`)
- Eclipse project files (`.project`, `.classpath`)

## 2.10.0.39 (2025-08-15)

- LDEV-4630 improve test coverage, update GH workflow
- Add Maven build alongside Ant
- Add GAV coordinates to pom.xml

## 2.10.0.36 (2023-05-26)

- LDEV-4429 custom classloader for deserialising classes from extension JARs (fixes jsonb, PGobject)
- LDEV-4886 test case for RMI distribution (disabled — `java.rmi.Remote` not found)
- LDEV-4429 test case for QueryStruct in distributed cache
- Update bundled Lucee version for tests

## 2.10.0.35 (2022-11-19)

- LDEV-4205 update ehcache library to 2.10.9.2
- Java 17 compatibility fix

## 2.10.0.34 (2022-11-19)

- LDEV-1575 CFML<->JVM type conversion for RMI replication of complex types
- Add GitHub Actions CI workflow
- Change compile target to Java 8
- Fix RMI manual distribution bug
- Add `EHCacheClassLoader` for custom deserialization

## 2.10.0.30 (2017-12-11)

- Reorganise init method (no static init)

## 2.10.0.29 (2017-12-11)

- Remove non-working `EHCacheRemote` class

## 2.10.0.28 (2017-12-11)

- Remove unnecessary classes

## 2.10.0.27 (2017-11-10)

- LDEV-1579 fix NullPointerException

## 2.10.0.25 (2017-08-28)

- Remove xerces/xalan dependency

## 2.10.0.24 (2017-08-07)

- LDEV-1312 fix `LuceeRMICacheReplicatorFactory` class loading

## 2.10.0.23 (2017-08-03)

- Improve CacheManager lifecycle control

## 2.10.0.22 (2017-07-31)

- LDEV-1332 fix "CacheManager has been shut down" error

## 2.10.0.21 (2017-04-11)

- Add release method for CacheManager cleanup

## 2.10.0.19 (2017-01-02)

- LDEV-1103 fix

## 2.10.0.18 (2016-12-19)

- LDEV-549 fix

## 2.10.0.17 (2016-08-15)

- Initial release as extension (extracted from Lucee core)
