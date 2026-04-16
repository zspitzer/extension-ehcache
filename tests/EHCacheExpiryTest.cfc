component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	public function beforeAll() {
		createCache();
	}

	public function run( testResults, testBox ) {

		describe( "EHCache Expiry and Metadata", function() {

			beforeEach( function() {
				cacheClear( "", "ehcacheExpiry" );
			});

			it( "expires entries after TTL", function() {
				cachePut( "ttlKey", "expires soon", createTimespan( 0, 0, 0, 2 ), createTimespan( 0, 0, 0, 2 ), "ehcacheExpiry" );
				expect( cacheGet( "ttlKey", "ehcacheExpiry" ) ).toBe( "expires soon" );
				sleep( 3000 );
				expect( cacheIdExists( "ttlKey", "ehcacheExpiry" ) ).toBeFalse();
			});

			// config-level TTL is NOT applied when cachePut has no explicit timespan
			// this is a known ehcache 2 issue — see https://dev.lucee.org/t/1816
			it( title: "applies config-level TTL when cachePut has no explicit timespan", skip: true, body: function() {
				// ehcacheShortTTL has timeToLiveSeconds=2, timeToIdleSeconds=2
				cachePut( id: "configTTL", value: "should expire from config", cacheName: "ehcacheShortTTL" );
				expect( cacheGet( "configTTL", "ehcacheShortTTL" ) ).toBe( "should expire from config" );
				sleep( 3000 );
				expect( cacheIdExists( "configTTL", "ehcacheShortTTL" ) ).toBeFalse();
			});

			it( "keeps eternal entries alive without explicit TTL", function() {
				cachePut( id: "eternalKey", value: "forever", cacheName: "ehcacheEternal" );
				sleep( 3000 );
				expect( cacheIdExists( "eternalKey", "ehcacheEternal" ) ).toBeTrue();
				expect( cacheGet( "eternalKey", "ehcacheEternal" ) ).toBe( "forever" );
			});

			// ehcache 3 TTI: updateExpirationTime() only extends, never shortens.
			// TTI cannot shorten from the initial creation expiry (TTL or INFINITE).
			// These tests are skipped — see tti.md for details.

			it( title: "TTI resets on access keeping entry alive", skip: true, body: function() {
				cachePut( id: "ttiKey", value: "kept alive", idleTime: createTimespan( 0, 0, 0, 3 ), cacheName: "ehcacheTTIOnly" );
				sleep( 2000 );
				var val = cacheGet( "ttiKey", "ehcacheTTIOnly" );
				expect( val ).toBe( "kept alive" );
				sleep( 2000 );
				expect( cacheIdExists( "ttiKey", "ehcacheTTIOnly" ) ).toBeTrue();
			});

			it( title: "TTI expires when entry is not accessed", skip: true, body: function() {
				cachePut( id: "ttiExpire", value: "will idle out", idleTime: createTimespan( 0, 0, 0, 2 ), cacheName: "ehcacheTTIOnly" );
				expect( cacheGet( "ttiExpire", "ehcacheTTIOnly" ) ).toBe( "will idle out" );
				sleep( 3000 );
				expect( cacheIdExists( "ttiExpire", "ehcacheTTIOnly" ) ).toBeFalse();
			});

			it( "returns metadata with correct keys", function() {
				cachePut( "metaKey", "metaVal", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheExpiry" );
				// access it so we get a hit
				cacheGet( "metaKey", "ehcacheExpiry" );
				var meta = cacheGetMetadata( "metaKey", "ehcacheExpiry" );
				expect( meta ).toBeStruct();
				// entry-level keys (from CacheGetMetadata.java)
				expect( meta ).toHaveKey( "createdtime" );
				expect( meta ).toHaveKey( "hitcount" );
				expect( meta ).toHaveKey( "idletime" );
				// lasthit — ehcache v3 doesn't track per-entry last hit time, may be null/missing
				expect( meta ).toHaveKey( "lastupdated" );
				expect( meta ).toHaveKey( "size" );
				expect( meta ).toHaveKey( "timespan" );
				// cache-level keys
				expect( meta ).toHaveKey( "cache_hitcount" );
				expect( meta ).toHaveKey( "cache_misscount" );
				expect( meta ).toHaveKey( "custom" );
				// value assertions
				expect( isDate( meta.createdtime ) ).toBeTrue();
				// ehcache v3 doesn't track per-entry hit count (-1) or serialized size
				expect( meta.hitcount ).toBe( -1 );
				expect( meta.size ).toBeGTE( 0 );
			});

			it( "tracks count correctly", function() {
				expect( cacheCount( "ehcacheExpiry" ) ).toBe( 0 );
				cachePut( "cnt1", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheExpiry" );
				cachePut( "cnt2", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheExpiry" );
				expect( cacheCount( "ehcacheExpiry" ) ).toBe( 2 );
			});

			it( "isolates multiple caches", function() {
				cacheClear( "", "ehcacheEternal" );
				cachePut( "isoKey", "expiry", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheExpiry" );
				cachePut( "isoKey", "eternal", createTimespan( 0, 1, 0, 0 ), createTimespan( 0, 1, 0, 0 ), "ehcacheEternal" );
				expect( cacheGet( "isoKey", "ehcacheExpiry" ) ).toBe( "expiry" );
				expect( cacheGet( "isoKey", "ehcacheEternal" ) ).toBe( "eternal" );
				cacheClear( "", "ehcacheExpiry" );
				expect( cacheIdExists( "isoKey", "ehcacheExpiry" ) ).toBeFalse();
				expect( cacheGet( "isoKey", "ehcacheEternal" ) ).toBe( "eternal" );
			});

		});

	}

	private function createCache() {
		application action="update" name="ehcacheExpiryTest" caches={
			"ehcacheExpiry": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"memoryevictionpolicy": "LRU",
					"timeToIdleSeconds": "60",
					"timeToLiveSeconds": "60",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"maxelementsondisk": "0",
					"distributed": "off"
				},
				default: ""
			},
			"ehcacheEternal": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "true",
					"maxelementsinmemory": "1000",
					"memoryevictionpolicy": "LRU",
					"timeToIdleSeconds": "0",
					"timeToLiveSeconds": "0",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"maxelementsondisk": "0",
					"distributed": "off"
				},
				default: ""
			},
			// TTI-only cache: no TTL, not eternal — TTI can actually expire entries
			"ehcacheTTIOnly": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"timeToIdleSeconds": "0",
					"timeToLiveSeconds": "0",
					"overflowtodisk": "false",
					"diskpersistent": "false"
				},
				default: ""
			},
			// only used by the skipped config-level TTL test (known ehcache 2 bug)
			"ehcacheShortTTL": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"memoryevictionpolicy": "LRU",
					"timeToIdleSeconds": "2",
					"timeToLiveSeconds": "2",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"maxelementsondisk": "0",
					"distributed": "off"
				},
				default: ""
			}
		};
	}

}
