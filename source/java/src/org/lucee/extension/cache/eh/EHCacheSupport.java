/**
 *
 * Copyright (c) 2014, the Railo Company Ltd. All rights reserved.
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
 **/
package org.lucee.extension.cache.eh;

import java.util.ArrayList;
import java.util.List;

import lucee.commons.io.cache.Cache;
import lucee.commons.io.cache.CacheEntry;
import lucee.commons.io.cache.CachePro;
import lucee.runtime.config.Config;

import org.lucee.extension.cache.CacheSupport;
import org.lucee.extension.cache.eh.LuceeExpiryPolicy.EntryMeta;
import lucee.loader.engine.CFMLEngineFactory;
import lucee.commons.io.log.Log;

public abstract class EHCacheSupport extends CacheSupport implements Cache {

	protected LuceeExpiryPolicy expiryPolicy;
	protected boolean trackItemMetadata = true;
	protected Log logger;

	protected Log getLogger() {
		return getLogger( null );
	}

	protected Log getLogger( Config config ) {
		return ( config == null ? CFMLEngineFactory.getInstance().getThreadConfig() : config ).getLog( "application" );
	}

	@Override
	public boolean contains( String key ) {
		return getCache().containsKey( key );
	}

	@Override
	public List<String> keys() {
		List<String> keys = new ArrayList<>();
		for ( org.ehcache.Cache.Entry<String, Object> entry : getCache() ) {
			keys.add( entry.getKey() );
		}
		return keys;
	}

	@Override
	public void put( String key, Object value, Long idleTime, Long liveTime ) {
		// Register expiry info BEFORE cache.put() so getExpiryForCreation() can find it
		if ( trackItemMetadata ) {
			expiryPolicy.setEntryExpiry( key, idleTime, liveTime );
		}

		try {
			getCache().put( key, value );
		}
		catch ( Exception e ) {
			// Clean up metadata if the put failed (e.g. serialization failure on disk tier)
			if ( trackItemMetadata ) {
				expiryPolicy.removeEntryExpiry( key );
			}
			throw new RuntimeException( "cache [" + key + "]: failed to store value of type [" + value.getClass().getName() + "]", e );
		}
	}

	@Override
	public CachePro decouple() {
		// is already decoupled by default
		return this;
	}

	@Override
	public CacheEntry getQuiet( String key, CacheEntry defaultValue ) {
		try {
			Object value = getCache().get( key );
			if ( value == null ) return defaultValue;
			EntryMeta meta = expiryPolicy.getEntryMeta( key );
			return new EHCacheEntry( key, value, meta );
		}
		catch ( Throwable t ) {
			if ( t instanceof ThreadDeath ) throw (ThreadDeath) t;
			return defaultValue;
		}
	}

	// getQuiet(String key) is inherited from CacheSupport — it delegates to
	// getQuiet(key, null) and throws CacheException when the result is null.

	protected abstract org.ehcache.Cache<String, Object> getCache();
}
