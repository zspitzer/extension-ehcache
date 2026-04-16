component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	// LDEV-109: ehcache v2 created a non-daemon thread "ehcache.data" that prevented
	// graceful servlet shutdown. In v3, threads are still non-daemon but CacheManager.close()
	// terminates them. Our ManagedCacheManager.release() calls close() during Lucee shutdown.
	//
	// This test verifies the old v2 thread name is gone and documents the v3 thread behaviour.

	public function beforeAll() {
		application action="update" name="LDEV-109" caches={
			"testCache109": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "100",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "true",
					"diskpersistent": "false",
					"diskSizeMB": "10"
				},
				default: ""
			}
		};
		cachePut( "threadTest", "value", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache109" );
		cacheGet( "threadTest", "testCache109" );
	}

	public function afterAll() {
		cacheClear( "", "testCache109" );
	}

	public function run( testResults, testBox ) {

		describe( "LDEV-109: ehcache thread behaviour", function() {

			it( "does not create the v2 'ehcache.data' non-daemon thread", function() {
				var threads = createObject( "java", "java.lang.Thread" ).getAllStackTraces().keySet().toArray();
				loop array="#threads#" item="local.t" {
					if ( t.getName() == "ehcache.data" ) {
						fail( "Found v2-era 'ehcache.data' thread — LDEV-109 regression" );
					}
				}
			});

			it( "logs ehcache thread names for diagnostic purposes", function() {
				var threads = createObject( "java", "java.lang.Thread" ).getAllStackTraces().keySet().toArray();
				var ehcacheThreads = [];
				loop array="#threads#" item="local.t" {
					if ( findNoCase( "ehcache", t.getName() ) || findNoCase( "Ehcache", t.getName() ) ) {
						arrayAppend( ehcacheThreads, "name=#t.getName()# daemon=#t.isDaemon()#" );
					}
				}
				systemOutput( "LDEV-109 ehcache threads: #arrayToList( ehcacheThreads, '; ' )#", true );
				// just documenting — v3 threads are non-daemon but cleaned up by CacheManager.close()
				expect( true ).toBeTrue();
			});

		});

	}

}
