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

import java.io.File;
import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import org.ehcache.Cache;
import org.ehcache.CacheManager;
import org.ehcache.Status;
import org.ehcache.config.builders.CacheConfigurationBuilder;
import org.ehcache.config.builders.CacheEventListenerConfigurationBuilder;
import org.ehcache.config.builders.CacheManagerBuilder;
import org.ehcache.config.builders.ResourcePoolsBuilder;
import org.ehcache.config.units.EntryUnit;
import org.ehcache.config.units.MemoryUnit;
import org.ehcache.event.EventType;

import org.lucee.extension.cache.eh.LuceeExpiryPolicy.EntryMeta;

import lucee.commons.io.cache.CacheEntry;
import lucee.commons.io.cache.exp.CacheException;
import lucee.commons.io.log.Log;
import lucee.commons.io.res.Resource;
import lucee.loader.engine.CFMLEngine;
import lucee.loader.engine.CFMLEngineFactory;
import lucee.runtime.config.Config;
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
	private static final boolean TRACK_METADATA = true;

	// CacheManager pool: one per config directory
	private static final ConcurrentHashMap<String, ManagedCacheManager> managers = new ConcurrentHashMap<>();

	private final AtomicLong hits = new AtomicLong();
	private final AtomicLong misses = new AtomicLong();
	private String cacheName;
	private boolean trackItemMetadata;
	private ManagedCacheManager mcm;

	public void init( String cacheName, Struct arguments ) throws IOException {
		init( CFMLEngineFactory.getInstance().getThreadConfig(), cacheName, arguments );
	}

	@Override
	public void init( Config config, String cacheName, Struct arguments ) throws IOException {
		Log log = getLogger( config );
		this.logger = log;
		this.cacheName = cacheName = improveCacheName( cacheName );

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
		this.trackItemMetadata = cast.toBooleanValue( arguments.get( "trackItemMetadata", Boolean.TRUE ), TRACK_METADATA );

		// Backwards compat: estimate disk size from maxelementsondisk if diskSizeMB not set
		if ( arguments.get( "diskSizeMB", null ) == null ) {
			long maxElementsOnDisk = cast.toLongValue( arguments.get( "maxelementsondisk", 0L ), 0L );
			if ( maxElementsOnDisk > 0 ) {
				diskSizeMB = Math.max( 10, maxElementsOnDisk / 1024 );
			}
		}

		log.debug( "ehcache", "Initialising cache [" + label( cacheName ) + "] with ehcache 3 (heap=" + maxElementsInMemory
				+ ", disk=" + ( overflowToDisk ? diskSizeMB + "MB" : "off" ) + ", eternal=" + eternal + ")" );

		// Get or create CacheManager for this config directory
		mcm = managers.computeIfAbsent( diskPath, ManagedCacheManager::new );
		CacheManager cacheManager = mcm.getOrCreate();

		// Build the expiry policy
		expiryPolicy = new LuceeExpiryPolicy( eternal, timeToLiveSeconds, timeToIdleSeconds );

		// Build resource pools
		ResourcePoolsBuilder pools = ResourcePoolsBuilder.newResourcePoolsBuilder()
				.heap( maxElementsInMemory, EntryUnit.ENTRIES );

		if ( overflowToDisk && diskSizeMB > 0 ) {
			pools = pools.disk( diskSizeMB, MemoryUnit.MB, diskPersistent );
		}

		// Build cache configuration
		JavaObjectSerializer valueSerializer = new JavaObjectSerializer( getClass().getClassLoader() );
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

		// Create the cache (or retrieve if already exists from disk persistence)
		Cache<String, Object> existing = cacheManager.getCache( cacheName, String.class, Object.class );
		if ( existing == null ) {
			cacheManager.createCache( cacheName, cacheConfig );
		}

		mcm.addRef();
		log.debug( "ehcache", "Cache [" + label( cacheName ) + "] initialised" );
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
					exp.createApplicationException( "there is no cache with name [" + label( cacheName ) + "]" ) );
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
		catch ( Throwable t ) {
			if ( t instanceof ThreadDeath ) throw (ThreadDeath) t;
			return false;
		}
	}

	@Override
	public CacheEntry getCacheEntry( String key ) throws CacheException {
		try {
			Object value = getCache().get( key );
			if ( value == null ) {
				misses.incrementAndGet();
				throw new CacheException( "there is no entry in cache with key [" + key + "]" );
			}
			hits.incrementAndGet();
			EntryMeta meta = expiryPolicy.getEntryMeta( key );
			return new EHCacheEntry( key, value, meta );
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
				hits.incrementAndGet();
				EntryMeta meta = expiryPolicy.getEntryMeta( key );
				return new EHCacheEntry( key, value, meta );
			}
			misses.incrementAndGet();
		}
		catch ( Throwable t ) {
			if ( t instanceof ThreadDeath ) throw (ThreadDeath) t;
			misses.incrementAndGet();
		}
		return defaultValue;
	}

	@Override
	public long hitCount() {
		return hits.get();
	}

	@Override
	public long missCount() {
		return misses.get();
	}

	@Override
	public int clear() throws IOException {
		org.ehcache.Cache<String, Object> cache = getCache();
		// Count via iteration — metaSize() can be 0 when trackItemMetadata is off
		int count = 0;
		for ( org.ehcache.Cache.Entry<String, Object> ignored : cache ) {
			count++;
		}
		cache.clear();
		expiryPolicy.clearAll();
		return count;
	}

	// --- name helpers ---

	private static String improveCacheName( String cacheName ) {
		if ( cacheName.equalsIgnoreCase( "default" ) )
			return "___default___";
		return cacheName;
	}

	private static String label( String cacheName ) {
		if ( cacheName.equalsIgnoreCase( "___default___" ) )
			return "default";
		return cacheName;
	}

}

/**
 * Reference-counted CacheManager wrapper, one per config directory.
 */
class ManagedCacheManager {

	private final String diskPath;
	private CacheManager manager;
	private final AtomicInteger refCount = new AtomicInteger( 0 );

	ManagedCacheManager( String diskPath ) {
		this.diskPath = diskPath;
	}

	synchronized CacheManager getOrCreate() {
		if ( manager == null || manager.getStatus() != Status.AVAILABLE ) {
			manager = CacheManagerBuilder.newCacheManagerBuilder()
					.with( CacheManagerBuilder.persistence( new File( diskPath ) ) )
					.build( true );
		}
		return manager;
	}

	void addRef() {
		refCount.incrementAndGet();
	}

	synchronized void release() {
		if ( refCount.decrementAndGet() <= 0 && manager != null ) {
			try {
				manager.close();
			}
			catch ( Exception e ) {
				// best effort
			}
			manager = null;
		}
	}
}
