package org.lucee.extension.cache.eh;

import java.io.File;
import java.util.concurrent.atomic.AtomicInteger;

import org.ehcache.CacheManager;
import org.ehcache.Status;
import org.ehcache.config.builders.CacheManagerBuilder;
import org.ehcache.core.internal.statistics.DefaultStatisticsService;
import org.ehcache.core.spi.service.StatisticsService;

/**
 * Reference-counted CacheManager wrapper, one per config directory.
 */
class ManagedCacheManager {

	private final String diskPath;
	private volatile CacheManager manager;
	private volatile StatisticsService statisticsService;
	private final AtomicInteger refCount = new AtomicInteger( 0 );

	ManagedCacheManager( String diskPath ) {
		this.diskPath = diskPath;
	}

	CacheManager getOrCreate() {
		CacheManager m = manager;
		if ( m != null && m.getStatus() == Status.AVAILABLE ) return m;
		return createOrRebuild();
	}

	private synchronized CacheManager createOrRebuild() {
		if ( manager == null || manager.getStatus() != Status.AVAILABLE ) {
			statisticsService = new DefaultStatisticsService();
			manager = CacheManagerBuilder.newCacheManagerBuilder()
					.using( statisticsService )
					.with( CacheManagerBuilder.persistence( new File( diskPath ) ) )
					.build( true );
		}
		return manager;
	}

	StatisticsService getStatisticsService() {
		return statisticsService;
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
