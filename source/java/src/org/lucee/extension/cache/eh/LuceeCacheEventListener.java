package org.lucee.extension.cache.eh;

import org.ehcache.event.CacheEvent;
import org.ehcache.event.CacheEventListener;

/**
 * Listens for cache events and cleans up the metadata sidecar in LuceeExpiryPolicy.
 */
public class LuceeCacheEventListener implements CacheEventListener<String, Object> {

	private final LuceeExpiryPolicy expiryPolicy;

	public LuceeCacheEventListener( LuceeExpiryPolicy expiryPolicy ) {
		this.expiryPolicy = expiryPolicy;
	}

	@Override
	public void onEvent( CacheEvent<? extends String, ? extends Object> event ) {
		switch ( event.getType() ) {
			case EXPIRED:
			case EVICTED:
			case REMOVED:
				expiryPolicy.removeEntryExpiry( event.getKey() );
				break;
			default:
				break;
		}
	}
}
