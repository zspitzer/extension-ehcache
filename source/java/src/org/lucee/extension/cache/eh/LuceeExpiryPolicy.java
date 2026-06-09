package org.lucee.extension.cache.eh;

import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

import org.ehcache.expiry.ExpiryPolicy;

/**
 * Custom ExpiryPolicy that supports per-entry TTL/TTI, falling back to cache-level defaults.
 * The entryMeta map also serves as a metadata sidecar for EHCacheEntry.
 */
public class LuceeExpiryPolicy implements ExpiryPolicy<String, Object> {

	private final boolean eternal;
	private final Duration defaultTTL;
	private final Duration defaultTTI; // null = no idle timeout

	private final ConcurrentHashMap<String, EntryMeta> entryMeta = new ConcurrentHashMap<>();

	/**
	 * Metadata tracked per cache entry.
	 */
	public static class EntryMeta {
		private final long createdAt;
		private final Long idleTimeMs;   // null = use cache default
		private final Long liveTimeMs;   // null = use cache default

		public EntryMeta( Long idleTimeMs, Long liveTimeMs ) {
			this.createdAt = System.currentTimeMillis();
			this.idleTimeMs = idleTimeMs;
			this.liveTimeMs = liveTimeMs;
		}

		public long getCreatedAt()  { return createdAt; }
		public Long getIdleTimeMs() { return idleTimeMs; }
		public Long getLiveTimeMs() { return liveTimeMs; }
	}

	public LuceeExpiryPolicy( boolean eternal, long timeToLiveSeconds, long timeToIdleSeconds ) {
		this.eternal = eternal;
		this.defaultTTL = timeToLiveSeconds > 0 ? Duration.ofSeconds( timeToLiveSeconds ) : INFINITE;
		this.defaultTTI = timeToIdleSeconds > 0 ? Duration.ofSeconds( timeToIdleSeconds ) : null;
	}

	/**
	 * Register per-entry expiry info before calling cache.put().
	 * Also creates the metadata record used by EHCacheEntry.
	 */
	public void setEntryExpiry( String key, Long idleTimeMs, Long liveTimeMs ) {
		entryMeta.put( key, new EntryMeta( idleTimeMs, liveTimeMs ) );
	}

	/**
	 * Get metadata for a key, or null if not tracked.
	 */
	public EntryMeta getEntryMeta( String key ) {
		return entryMeta.get( key );
	}

	/**
	 * Return the number of tracked entries.
	 */
	public int metaSize() {
		return entryMeta.size();
	}

	/**
	 * Remove metadata for a key (called by the event listener on EXPIRED/EVICTED/REMOVED).
	 */
	public void removeEntryExpiry( String key ) {
		entryMeta.remove( key );
	}

	/**
	 * Clear all metadata (called on cache.clear()).
	 */
	public void clearAll() {
		entryMeta.clear();
	}

	@Override
	public Duration getExpiryForCreation( String key, Object value ) {
		if ( eternal ) return INFINITE;

		EntryMeta meta = entryMeta.get( key );
		if ( meta != null && meta.getLiveTimeMs() != null ) {
			return Duration.ofMillis( meta.getLiveTimeMs() );
		}
		return defaultTTL;
	}

	@Override
	public Duration getExpiryForAccess( String key, Supplier<? extends Object> value ) {
		if ( eternal ) return null; // don't change expiry

		EntryMeta meta = entryMeta.get( key );
		Duration tti = null;

		if ( meta != null && meta.getIdleTimeMs() != null ) {
			tti = Duration.ofMillis( meta.getIdleTimeMs() );
		}
		else if ( defaultTTI != null ) {
			tti = defaultTTI;
		}

		if ( tti == null ) return null; // no TTI configured, don't change expiry

		// If there's also a TTL, cap the TTI at the remaining TTL to prevent
		// idle access from extending an entry past its absolute time-to-live
		Long ttlMs = ( meta != null && meta.getLiveTimeMs() != null ) ? meta.getLiveTimeMs() : null;
		if ( ttlMs == null && defaultTTL != null && !defaultTTL.equals( INFINITE ) ) {
			ttlMs = defaultTTL.toMillis();
		}

		if ( ttlMs != null && meta != null ) {
			long elapsed = System.currentTimeMillis() - meta.getCreatedAt();
			long remainingMs = ttlMs - elapsed;
			if ( remainingMs <= 0 ) return Duration.ZERO;
			Duration remaining = Duration.ofMillis( remainingMs );
			return tti.compareTo( remaining ) < 0 ? tti : remaining;
		}

		return tti;
	}

	@Override
	public Duration getExpiryForUpdate( String key, Supplier<? extends Object> oldValue, Object newValue ) {
		return getExpiryForCreation( key, newValue );
	}
}
