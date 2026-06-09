/**
 * Copyright (c) 2014, the Railo Company Ltd.
 * Copyright (c) 2015, Lucee Assosication Switzerland
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 */
package org.lucee.extension.cache.eh;

import java.io.IOException;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.ehcache.Cache;
import org.ehcache.CacheManager;
import org.ehcache.config.builders.CacheConfigurationBuilder;
import org.ehcache.config.builders.CacheEventListenerConfigurationBuilder;
import org.ehcache.config.builders.ResourcePoolsBuilder;
import org.ehcache.config.units.EntryUnit;
import org.ehcache.config.units.MemoryUnit;
import org.ehcache.core.spi.service.StatisticsService;
import org.ehcache.core.statistics.CacheStatistics;
import org.ehcache.core.statistics.TierStatistics;
import org.ehcache.event.EventType;

import org.lucee.extension.cache.eh.LuceeExpiryPolicy.EntryMeta;

import lucee.commons.io.cache.CacheEntry;
import lucee.commons.io.cache.exp.CacheException;
import lucee.commons.io.log.Log;
import lucee.commons.io.res.Resource;
import lucee.loader.engine.CFMLEngine;
import lucee.loader.engine.CFMLEngineFactory;
import lucee.runtime.config.Config;
import lucee.runtime.type.Collection.Key;
import lucee.runtime.type.Struct;
import lucee.runtime.util.Cast;
import lucee.runtime.util.Excepton;

public class EHCache extends EHCacheSupport {

	private static final boolean DISK_PERSISTENT = true;
	private static final boolean ETERNAL = false;
	private static final int MAX_ELEMENTS_IN_MEMORY = 10000;
	private static final boolean OVERFLOW_TO_DISK = true;
	private static final long TIME_TO_IDLE_SECONDS = 86400;
	private static final long TIME_TO_LIVE_SECONDS = 86400;
	private static final long DISK_SIZE_MB = 100;
	private static final long OFFHEAP_SIZE_MB = 0;
	private static final boolean TRACK_METADATA = true;
	private static final boolean REPORT_STATISTICS = false;
	private static final boolean REPORT_TIER_STATISTICS = false;

	// Pre-built Keys for struct writes — avoids string-to-Key conversion on every setEL
	private static final Key KEY_HIT_COUNT;
	private static final Key KEY_MISS_COUNT;
	private static final Key KEY_GET_COUNT;
	private static final Key KEY_PUT_COUNT;
	private static final Key KEY_REMOVE_COUNT;
	private static final Key KEY_EVICTION_COUNT;
	private static final Key KEY_EXPIRATION_COUNT;
	private static final Key KEY_HIT_PERCENTAGE;
	private static final Key KEY_MISS_PERCENTAGE;
	private static final Key KEY_TIERS;
	private static final Key KEY_HITS;
	private static final Key KEY_MISSES;
	private static final Key KEY_PUTS;
	private static final Key KEY_REMOVALS;
	private static final Key KEY_EVICTIONS;
	private static final Key KEY_EXPIRATIONS;
	private static final Key KEY_MAPPINGS;
	private static final Key KEY_ALLOCATED_BYTES;
	private static final Key KEY_OCCUPIED_BYTES;
	static {
		lucee.runtime.util.Creation cu = CFMLEngineFactory.getInstance().getCreationUtil();
		KEY_HIT_COUNT = cu.createKey( "hit_count" );
		KEY_MISS_COUNT = cu.createKey( "miss_count" );
		KEY_GET_COUNT = cu.createKey( "get_count" );
		KEY_PUT_COUNT = cu.createKey( "put_count" );
		KEY_REMOVE_COUNT = cu.createKey( "remove_count" );
		KEY_EVICTION_COUNT = cu.createKey( "eviction_count" );
		KEY_EXPIRATION_COUNT = cu.createKey( "expiration_count" );
		KEY_HIT_PERCENTAGE = cu.createKey( "hit_percentage" );
		KEY_MISS_PERCENTAGE = cu.createKey( "miss_percentage" );
		KEY_TIERS = cu.createKey( "tiers" );
		KEY_HITS = cu.createKey( "hits" );
		KEY_MISSES = cu.createKey( "misses" );
		KEY_PUTS = cu.createKey( "puts" );
		KEY_REMOVALS = cu.createKey( "removals" );
		KEY_EVICTIONS = cu.createKey( "evictions" );
		KEY_EXPIRATIONS = cu.createKey( "expirations" );
		KEY_MAPPINGS = cu.createKey( "mappings" );
		KEY_ALLOCATED_BYTES = cu.createKey( "allocated_bytes" );
		KEY_OCCUPIED_BYTES = cu.createKey( "occupied_bytes" );
	}

	// CacheManager pool: one per config directory
	private static final ConcurrentHashMap<String, ManagedCacheManager> managers = new ConcurrentHashMap<>();

	private String cacheName;
	private boolean trackItemMetadata;
	private boolean reportStatistics;
	private boolean reportTierStatistics;
	private ManagedCacheManager mcm;
	private JavaObjectSerializer valueSerializer;

	public void init( String cacheName, Struct arguments ) throws IOException {
		init( CFMLEngineFactory.getInstance().getThreadConfig(), cacheName, arguments );
	}

	@Override
	public void init( Config config, String cacheName, Struct arguments ) throws IOException {
		Log log = getLogger( config );
		this.logger = log;
		this.cacheName = cacheName;

		// Resolve ehcache disk storage directory
		Resource dir = config.getConfigDir().getRealResource( "ehcache" );
		if ( !dir.isDirectory() ) dir.createDirectory( true );
		String diskPath = dir.getAbsolutePath();

		// Parse config arguments
		Cast cast = CFMLEngineFactory.getInstance().getCastUtil();
		boolean eternal = cast.toBooleanValue( arguments.get( "eternal", Boolean.FALSE ), ETERNAL );
		int maxElementsInMemory = cast.toIntValue( arguments.get( "maxelementsinmemory", MAX_ELEMENTS_IN_MEMORY ), MAX_ELEMENTS_IN_MEMORY );
		boolean overflowToDisk = cast.toBooleanValue( arguments.get( "overflowtodisk", Boolean.FALSE ), OVERFLOW_TO_DISK );
		boolean diskPersistent = cast.toBooleanValue( arguments.get( "diskpersistent", Boolean.FALSE ), DISK_PERSISTENT );
		long timeToIdleSeconds = cast.toLongValue( arguments.get( "timeToIdleSeconds", TIME_TO_IDLE_SECONDS ), TIME_TO_IDLE_SECONDS );
		long timeToLiveSeconds = cast.toLongValue( arguments.get( "timeToLiveSeconds", TIME_TO_LIVE_SECONDS ), TIME_TO_LIVE_SECONDS );
		long diskSizeMB = cast.toLongValue( arguments.get( "diskSizeMB", DISK_SIZE_MB ), DISK_SIZE_MB );
		long offheapSizeMB = cast.toLongValue( arguments.get( "offheapSizeMB", OFFHEAP_SIZE_MB ), OFFHEAP_SIZE_MB );
		this.trackItemMetadata = cast.toBooleanValue( arguments.get( "trackItemMetadata", Boolean.TRUE ), TRACK_METADATA );
		this.reportStatistics = cast.toBooleanValue( arguments.get( "reportStatistics", Boolean.FALSE ), REPORT_STATISTICS );
		this.reportTierStatistics = cast.toBooleanValue( arguments.get( "reportTierStatistics", Boolean.FALSE ), REPORT_TIER_STATISTICS );

		// Backwards compat: estimate disk size from maxelementsondisk if diskSizeMB not set
		if ( arguments.get( "diskSizeMB", null ) == null ) {
			long maxElementsOnDisk = cast.toLongValue( arguments.get( "maxelementsondisk", 0L ), 0L );
			if ( maxElementsOnDisk > 0 ) {
				diskSizeMB = Math.max( 10, maxElementsOnDisk / 1024 );
			}
		}

		log.debug( "ehcache", "Initialising cache [" + cacheName + "] with ehcache 3 (heap=" + maxElementsInMemory + " entries"
				+ ( offheapSizeMB > 0 ? ", offheap=" + offheapSizeMB + "MB" : "" )
				+ ", disk=" + ( overflowToDisk ? diskSizeMB + "MB" : "off" ) + ", eternal=" + eternal + ")" );

		// Get or create CacheManager for this config directory
		mcm = managers.computeIfAbsent( diskPath, ManagedCacheManager::new );
		CacheManager cacheManager = mcm.getOrCreate();

		// Build the expiry policy
		expiryPolicy = new LuceeExpiryPolicy( eternal, timeToLiveSeconds, timeToIdleSeconds );

		// Build resource pools — tiering order: heap > offheap > disk
		ResourcePoolsBuilder pools = ResourcePoolsBuilder.newResourcePoolsBuilder();
		pools = pools.heap( maxElementsInMemory, EntryUnit.ENTRIES );

		if ( offheapSizeMB > 0 ) {
			pools = pools.offheap( offheapSizeMB, MemoryUnit.MB );
		}

		if ( overflowToDisk && diskSizeMB > 0 ) {
			pools = pools.disk( diskSizeMB, MemoryUnit.MB, diskPersistent );
		}

		// Build cache configuration
		this.valueSerializer = new JavaObjectSerializer( getClass().getClassLoader() );
		CacheConfigurationBuilder<String, Object> cacheConfig = CacheConfigurationBuilder
				.newCacheConfigurationBuilder( String.class, Object.class, pools )
				.withExpiry( expiryPolicy )
				.withValueSerializer( valueSerializer );

		// Only register the event listener when tracking metadata — it adds per-operation
		// allocation overhead (InvocationScopedEventSink, StoreEventImpl, FireableStoreEventHolder)
		if ( trackItemMetadata ) {
			LuceeCacheEventListener eventListener = new LuceeCacheEventListener( expiryPolicy );
			cacheConfig = cacheConfig.withService(
					CacheEventListenerConfigurationBuilder
							.newEventListenerConfiguration( eventListener, EventType.EXPIRED, EventType.EVICTED, EventType.REMOVED )
							.unordered()
							.asynchronous()
			);
		}

		// Create the cache (or retrieve if already exists from disk persistence).
		// The get-then-create pattern is non-atomic — ehcache 3's createCache throws
		// IllegalArgumentException if the cache already exists. Concurrent init()
		// calls for the same name would race here, but Lucee's CacheConnectionImpl
		// already serializes cache instantiation via double-checked locking on the
		// class definition (see CacheConnectionImpl.getInstance), so this isn't
		// reachable from the normal Lucee lifecycle.
		Cache<String, Object> existing = cacheManager.getCache( cacheName, String.class, Object.class );
		if ( existing == null ) {
			cacheManager.createCache( cacheName, cacheConfig );
		}

		mcm.addRef();
		log.debug( "ehcache", "Cache [" + cacheName + "] initialised" );
	}

	public void release() {
		if ( mcm == null ) return;
		mcm.release();
	}

	@Override
	protected Cache<String, Object> getCache() {
		CacheManager cm = mcm.getOrCreate();
		Cache<String, Object> c = cm.getCache( cacheName, String.class, Object.class );
		if ( c == null ) {
			CFMLEngine engine = CFMLEngineFactory.getInstance();
			Excepton exp = engine.getExceptionUtil();
			throw exp.createPageRuntimeException(
					exp.createApplicationException( "there is no cache with name [" + cacheName + "]" ) );
		}
		return c;
	}

	@Override
	public boolean remove( String key ) {
		try {
			org.ehcache.Cache<String, Object> cache = getCache();
			boolean exists = cache.containsKey( key );
			cache.remove( key );
			return exists;
		}
		catch ( Exception e ) {
			return false;
		}
	}

	@Override
	public CacheEntry getCacheEntry( String key ) throws CacheException {
		try {
			Object value = getCache().get( key );
			if ( value == null ) {
				throw new CacheException( "there is no entry in cache with key [" + key + "]" );
			}
			EntryMeta meta = expiryPolicy.getEntryMeta( key );
			return new EHCacheEntry( key, value, meta, reportStatistics ? buildCacheStats() : null );
		}
		catch ( CacheException ce ) {
			throw ce;
		}
		catch ( IllegalStateException ise ) {
			throw new CacheException( ise.getMessage() );
		}
	}

	@Override
	public CacheEntry getCacheEntry( String key, CacheEntry defaultValue ) {
		try {
			Object value = getCache().get( key );
			if ( value != null ) {
				EntryMeta meta = expiryPolicy.getEntryMeta( key );
				return new EHCacheEntry( key, value, meta, reportStatistics ? buildCacheStats() : null );
			}
		}
		catch ( Exception e ) {
		}
		return defaultValue;
	}

	@Override
	public long hitCount() {
		StatisticsService statsService = mcm.getStatisticsService();
		if ( statsService != null ) {
			try {
				return statsService.getCacheStatistics( cacheName ).getCacheHits();
			}
			catch ( IllegalArgumentException e ) { /* cache not yet registered */ }
		}
		return 0;
	}

	@Override
	public long missCount() {
		StatisticsService statsService = mcm.getStatisticsService();
		if ( statsService != null ) {
			try {
				return statsService.getCacheStatistics( cacheName ).getCacheMisses();
			}
			catch ( IllegalArgumentException e ) { /* cache not yet registered */ }
		}
		return 0;
	}

	@Override
	public Struct getCustomInfo() {
		Struct info = super.getCustomInfo();
		Struct stats = buildCacheStats();
		if ( stats != null ) {
			Iterator<Key> it = stats.keyIterator();
			while ( it.hasNext() ) {
				Key k = it.next();
				info.setEL( k, stats.get( k, null ) );
			}
		}
		return info;
	}

	private Struct buildCacheStats() {
		StatisticsService statsService = mcm.getStatisticsService();
		if ( statsService == null ) return null;
		try {
			CacheStatistics stats = statsService.getCacheStatistics( cacheName );
			Struct info = CFMLEngineFactory.getInstance().getCreationUtil().createStruct();
			info.setEL( KEY_HIT_COUNT, Double.valueOf( stats.getCacheHits() ) );
			info.setEL( KEY_MISS_COUNT, Double.valueOf( stats.getCacheMisses() ) );
			info.setEL( KEY_GET_COUNT, Double.valueOf( stats.getCacheGets() ) );
			info.setEL( KEY_PUT_COUNT, Double.valueOf( stats.getCachePuts() ) );
			info.setEL( KEY_REMOVE_COUNT, Double.valueOf( stats.getCacheRemovals() ) );
			info.setEL( KEY_EVICTION_COUNT, Double.valueOf( stats.getCacheEvictions() ) );
			info.setEL( KEY_EXPIRATION_COUNT, Double.valueOf( stats.getCacheExpirations() ) );
			info.setEL( KEY_HIT_PERCENTAGE, Double.valueOf( stats.getCacheHitPercentage() ) );
			info.setEL( KEY_MISS_PERCENTAGE, Double.valueOf( stats.getCacheMissPercentage() ) );
			if ( reportTierStatistics ) {
				Struct tiers = buildTierStats( stats );
				if ( tiers != null ) info.setEL( KEY_TIERS, tiers );
			}
			return info;
		}
		catch ( IllegalArgumentException e ) {
			return null;
		}
	}

	private Struct buildTierStats( CacheStatistics stats ) {
		Map<String, TierStatistics> tierMap = stats.getTierStatistics();
		if ( tierMap == null || tierMap.isEmpty() ) return null;
		Struct out = CFMLEngineFactory.getInstance().getCreationUtil().createStruct();
		for ( Map.Entry<String, TierStatistics> e : tierMap.entrySet() ) {
			TierStatistics t = e.getValue();
			Struct tier = CFMLEngineFactory.getInstance().getCreationUtil().createStruct();
			tier.setEL( KEY_HITS, Double.valueOf( t.getHits() ) );
			tier.setEL( KEY_MISSES, Double.valueOf( t.getMisses() ) );
			tier.setEL( KEY_PUTS, Double.valueOf( t.getPuts() ) );
			tier.setEL( KEY_REMOVALS, Double.valueOf( t.getRemovals() ) );
			tier.setEL( KEY_EVICTIONS, Double.valueOf( t.getEvictions() ) );
			tier.setEL( KEY_EXPIRATIONS, Double.valueOf( t.getExpirations() ) );
			tier.setEL( KEY_MAPPINGS, Double.valueOf( t.getMappings() ) );
			long alloc = t.getAllocatedByteSize();
			long occ = t.getOccupiedByteSize();
			if ( alloc >= 0 ) tier.setEL( KEY_ALLOCATED_BYTES, Double.valueOf( alloc ) );
			if ( occ >= 0 ) tier.setEL( KEY_OCCUPIED_BYTES, Double.valueOf( occ ) );
			out.setEL( e.getKey(), tier );
		}
		return out;
	}

	@Override
	public int clear() throws IOException {
		org.ehcache.Cache<String, Object> cache = getCache();
		int count = countEntries( cache );
		cache.clear();
		expiryPolicy.clearAll();
		if ( valueSerializer != null ) valueSerializer.reset();
		return count;
	}

	/**
	 * Entry-count source for clear(), tried in cost order:
	 *
	 * 1. TierStatistics.getMappings() — max across tiers. In ehcache 3's tiered
	 *    storage, lower tiers are authoritative (heap caches a subset of offheap
	 *    caches a subset of disk), so the largest tier mapping count is the
	 *    total entry count. Exact, O(tiers). Stats service is always created
	 *    by ManagedCacheManager, so this path is normally available.
	 * 2. expiryPolicy.metaSize() — when trackItemMetadata is enabled.
	 *    Approximate during high churn because the cache event listener is
	 *    asynchronous; evictions may not yet be reflected in entryMeta.
	 * 3. Cache iteration — O(N), exact, but forces deserialization of disk-tier
	 *    entries. Last resort only.
	 */
	private int countEntries( org.ehcache.Cache<String, Object> cache ) {
		StatisticsService statsService = mcm.getStatisticsService();
		if ( statsService != null ) {
			try {
				Map<String, TierStatistics> tiers = statsService.getCacheStatistics( cacheName ).getTierStatistics();
				if ( tiers != null && !tiers.isEmpty() ) {
					long max = -1;
					for ( TierStatistics t : tiers.values() ) {
						long m = t.getMappings();
						if ( m > max ) max = m;
					}
					if ( max >= 0 ) return (int) max;
				}
			}
			catch ( IllegalArgumentException ignored ) { /* cache not yet registered */ }
		}
		if ( trackItemMetadata ) return expiryPolicy.metaSize();
		int count = 0;
		for ( org.ehcache.Cache.Entry<String, Object> ignored : cache ) count++;
		return count;
	}

}
