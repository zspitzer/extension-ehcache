component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	public function beforeAll() {
		createCache();
	}

	public function run( testResults, testBox ) {

		describe( "EHCache trackItemMetadata=false", function() {

			beforeEach( function() {
				cacheClear( "", "ehcacheNoMeta" );
			});

			it( "can put and get a value", function() {
				cachePut( "noMetaKey", "hello", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				var result = cacheGet( "noMetaKey", "ehcacheNoMeta" );
				expect( result ).toBe( "hello" );
			});

			it( "can remove an entry", function() {
				cachePut( "removeMe", "gone", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				expect( cacheIdExists( "removeMe", "ehcacheNoMeta" ) ).toBeTrue();
				cacheRemove( "removeMe", false, "ehcacheNoMeta" );
				expect( cacheIdExists( "removeMe", "ehcacheNoMeta" ) ).toBeFalse();
			});

			it( "can clear all entries", function() {
				cachePut( "clrA", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				cachePut( "clrB", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				expect( cacheCount( "ehcacheNoMeta" ) ).toBe( 2 );
				cacheClear( "", "ehcacheNoMeta" );
				expect( cacheCount( "ehcacheNoMeta" ) ).toBe( 0 );
			});

			it( "can list keys", function() {
				cachePut( "keyA", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				cachePut( "keyB", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				var ids = cacheGetAllIds( cacheName: "ehcacheNoMeta" );
				expect( ids ).toBeArray();
				expect( arrayLen( ids ) ).toBe( 2 );
			});

			it( "returns metadata struct even with tracking off", function() {
				cachePut( "metaKey", "metaVal", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				cacheGet( "metaKey", "ehcacheNoMeta" );
				var meta = cacheGetMetadata( "metaKey", "ehcacheNoMeta" );
				expect( meta ).toBeStruct();
				// should still have cache-level stats
				expect( meta ).toHaveKey( "cache_hitcount" );
				expect( meta ).toHaveKey( "cache_misscount" );
			});

			it( "expires entries via cache-level TTL", function() {
				// Uses the short-TTL cache to verify cache defaults still work
				cachePut( "ttlKey", "expires", createTimespan( 0, 0, 0, 2 ), createTimespan( 0, 0, 0, 2 ), "ehcacheNoMetaShortTTL" );
				expect( cacheGet( "ttlKey", "ehcacheNoMetaShortTTL" ) ).toBe( "expires" );
				sleep( 3000 );
				expect( cacheIdExists( "ttlKey", "ehcacheNoMetaShortTTL" ) ).toBeFalse();
			});

			it( "handles concurrent put and get", function() {
				// Pre-populate
				for ( var i = 1; i <= 100; i++ ) {
					cachePut( "conc_#i#", "val_#i#", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheNoMeta" );
				}

				var tName = "nometa_reader";
				thread name="#tName#" action="run" {
					thread.reads = 0;
					thread.errors = 0;
					for ( var j = 1; j <= 500; j++ ) {
						try {
							cacheGet( "conc_#randRange( 1, 100 )#", "ehcacheNoMeta" );
							thread.reads++;
						} catch ( any e ) {
							thread.errors++;
						}
					}
				}

				thread action="join" name="#tName#" timeout="10000";
				expect( cfthread[ tName ].status ).toBe( "COMPLETED" );
				expect( cfthread[ tName ].errors ).toBe( 0 );
			});

		});

	}

	private function createCache() {
		application action="update" name="ehcacheTrackMetadataTest" caches={
			"ehcacheNoMeta": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"trackItemMetadata": "false"
				},
				default: ""
			},
			"ehcacheNoMetaShortTTL": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"timeToIdleSeconds": "2",
					"timeToLiveSeconds": "2",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"trackItemMetadata": "false"
				},
				default: ""
			}
		};
	}

}
