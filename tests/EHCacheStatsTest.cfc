component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	public function beforeAll() {
		createCaches();
	}

	public function run( testResults, testBox ) {

		describe( "EHCache Statistics", function() {

			beforeEach( function() {
				cacheClear( "", "ehcacheStats" );
			});

			it( "returns all expected stat keys", function() {
				cachePut( "k1", "v1", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );
				cacheGet( "k1", "ehcacheStats" );

				var meta = cacheGetMetadata( "k1", "ehcacheStats" );
				var custom = meta.custom;
				expect( custom ).toHaveKey( "hit_count" );
				expect( custom ).toHaveKey( "miss_count" );
				expect( custom ).toHaveKey( "get_count" );
				expect( custom ).toHaveKey( "put_count" );
				expect( custom ).toHaveKey( "remove_count" );
				expect( custom ).toHaveKey( "eviction_count" );
				expect( custom ).toHaveKey( "expiration_count" );
				expect( custom ).toHaveKey( "hit_percentage" );
				expect( custom ).toHaveKey( "miss_percentage" );
			});

			it( "tracks hits and misses", function() {
				cachePut( "h1", "val", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );

				// generate some hits
				cacheGet( "h1", "ehcacheStats" );
				cacheGet( "h1", "ehcacheStats" );
				cacheGet( "h1", "ehcacheStats" );

				// generate a miss
				try { cacheGet( "noSuchKey_#createUUID()#", "ehcacheStats" ); } catch( any e ) {}

				var meta = cacheGetMetadata( "h1", "ehcacheStats" );
				var custom = meta.custom;
				expect( custom.hit_count ).toBeGTE( 3 );
				expect( custom.miss_count ).toBeGTE( 1 );
				expect( custom.get_count ).toBeGTE( 4 );
			});

			it( "tracks put count", function() {
				cachePut( "p1", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );
				cachePut( "p2", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );
				cachePut( "p3", "c", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );

				var meta = cacheGetMetadata( "p1", "ehcacheStats" );
				expect( meta.custom.put_count ).toBeGTE( 3 );
			});

			it( "tracks remove count", function() {
				cachePut( "r1", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );
				cachePut( "r2", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );
				cacheRemove( "r1", false, "ehcacheStats" );

				var meta = cacheGetMetadata( "r2", "ehcacheStats" );
				expect( meta.custom.remove_count ).toBeGTE( 1 );
			});

			it( "tracks eviction count when heap overflows", function() {
				// ehcacheStatsSmall has maxelementsinmemory=50, no disk
				cacheClear( "", "ehcacheStatsSmall" );
				loop from="1" to="100" index="local.i" {
					cachePut( "ev_#i#", repeatString( "x", 100 ), createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStatsSmall" );
				}

				// need at least one entry to get metadata from
				cachePut( "ev_probe", "probe", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStatsSmall" );
				var meta = cacheGetMetadata( "ev_probe", "ehcacheStatsSmall" );
				expect( meta.custom.eviction_count ).toBeGTE( 1 );
			});

			it( "tracks expiration count", function() {
				cachePut( "exp1", "dies soon", createTimespan( 0, 0, 0, 2 ), createTimespan( 0, 0, 0, 2 ), "ehcacheStats" );
				sleep( 3000 );
				// access triggers lazy expiration in ehcache
				try { cacheGet( "exp1", "ehcacheStats" ); } catch( any e ) {}

				// put something so we can read metadata
				cachePut( "exp_probe", "probe", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );
				var meta = cacheGetMetadata( "exp_probe", "ehcacheStats" );
				expect( meta.custom.expiration_count ).toBeGTE( 1 );
			});

			it( "reports sane hit percentage", function() {
				cachePut( "pct1", "val", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );

				// 3 hits
				cacheGet( "pct1", "ehcacheStats" );
				cacheGet( "pct1", "ehcacheStats" );
				cacheGet( "pct1", "ehcacheStats" );

				// 1 miss
				try { cacheGet( "noSuchKey_#createUUID()#", "ehcacheStats" ); } catch( any e ) {}

				var meta = cacheGetMetadata( "pct1", "ehcacheStats" );
				expect( meta.custom.hit_percentage ).toBeGTE( 0 );
				expect( meta.custom.hit_percentage ).toBeLTE( 100 );
				expect( meta.custom.miss_percentage ).toBeGTE( 0 );
				expect( meta.custom.miss_percentage ).toBeLTE( 100 );
			});

			it( "exposes per-tier statistics when reportTierStatistics is enabled", function() {
				cachePut( "t1", "val", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheTiered" );
				cacheGet( "t1", "ehcacheTiered" );

				var meta = cacheGetMetadata( "t1", "ehcacheTiered" );
				expect( meta.custom ).toHaveKey( "tiers" );
				expect( meta.custom.tiers ).toHaveKey( "OnHeap" );

				var onheap = meta.custom.tiers.OnHeap;
				expect( onheap ).toHaveKey( "hits" );
				expect( onheap ).toHaveKey( "misses" );
				expect( onheap ).toHaveKey( "puts" );
				expect( onheap ).toHaveKey( "removals" );
				expect( onheap ).toHaveKey( "evictions" );
				expect( onheap ).toHaveKey( "expirations" );
				expect( onheap ).toHaveKey( "mappings" );
			});

			it( "does not expose tiers when reportTierStatistics is off", function() {
				// ehcacheStats has reportStatistics=true but no reportTierStatistics
				cachePut( "nt1", "val", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheStats" );
				var meta = cacheGetMetadata( "nt1", "ehcacheStats" );
				expect( meta.custom ).notToHaveKey( "tiers" );
			});

			it( "OnHeap mappings reflects current entry count", function() {
				cacheClear( "", "ehcacheTiered" );
				cachePut( "m1", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheTiered" );
				cachePut( "m2", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheTiered" );
				cachePut( "m3", "c", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheTiered" );

				var meta = cacheGetMetadata( "m1", "ehcacheTiered" );
				expect( meta.custom.tiers.OnHeap.mappings ).toBeGTE( 3 );
			});

			it( "exposes Disk tier when overflowToDisk is enabled", function() {
				cachePut( "d1", "val", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheTieredDisk" );
				var meta = cacheGetMetadata( "d1", "ehcacheTieredDisk" );
				expect( meta.custom.tiers ).toHaveKey( "Disk" );
				expect( meta.custom.tiers.Disk ).toHaveKey( "mappings" );
			});

		});

	}

	private function createCaches() {
		application action="update" name="ehcacheStatsTest" caches={
			"ehcacheStats": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"reportStatistics": "true"
				},
				default: ""
			},
			"ehcacheStatsSmall": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "50",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"reportStatistics": "true"
				},
				default: ""
			},
			"ehcacheTiered": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"reportStatistics": "true",
					"reportTierStatistics": "true"
				},
				default: ""
			},
			"ehcacheTieredDisk": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "100",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "true",
					"diskpersistent": "false",
					"diskSizeMB": "10",
					"reportStatistics": "true",
					"reportTierStatistics": "true"
				},
				default: ""
			}
		};
	}

}
