component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	public function beforeAll() {
		createCaches();
	}

	public function run( testResults, testBox ) {

		describe( "EHCache Off-Heap Tier", function() {

			beforeEach( function() {
				cacheClear( "", "ehcacheOffheap" );
			});

			it( "stores and retrieves from off-heap", function() {
				// heap is 100 entries, offheap is 32MB — put more than 100 to force off-heap usage
				loop from="1" to="200" index="local.i" {
					cachePut( "oh_#i#", "value_#i#", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheOffheap" );
				}
				// all 200 should be retrievable (100 heap + rest in offheap)
				loop from="1" to="200" index="local.i" {
					expect( cacheGet( "oh_#i#", "ehcacheOffheap" ) ).toBe( "value_#i#" );
				}
				expect( cacheCount( "ehcacheOffheap" ) ).toBe( 200 );
			});

			it( "round-trips complex values through off-heap serialization", function() {
				// fill heap so complex values get serialized to off-heap
				loop from="1" to="100" index="local.i" {
					cachePut( "filler_#i#", "x", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheOffheap" );
				}
				var data = {
					users: [ { name: "Alice", tags: [ "admin", "dev" ] } ],
					meta: { count: 1, active: true }
				};
				cachePut( "ohComplex", data, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheOffheap" );
				var result = cacheGet( "ohComplex", "ehcacheOffheap" );
				expect( result.users[ 1 ].name ).toBe( "Alice" );
				expect( result.meta.active ).toBeTrue();
			});

			it( "preserves ordered struct through off-heap", function() {
				loop from="1" to="100" index="local.i" {
					cachePut( "pad_#i#", "x", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheOffheap" );
				}
				var data = structNew( "ordered" );
				data[ "second" ] = 2;
				data[ "first" ] = 1;
				data[ "third" ] = 3;
				cachePut( "ohOrdered", data, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheOffheap" );
				var result = cacheGet( "ohOrdered", "ehcacheOffheap" );
				var keys = structKeyArray( result );
				expect( keys[ 1 ] ).toBe( "second" );
				expect( keys[ 2 ] ).toBe( "first" );
				expect( keys[ 3 ] ).toBe( "third" );
			});

			it( "clears all tiers", function() {
				loop from="1" to="200" index="local.i" {
					cachePut( "clr_#i#", "v", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheOffheap" );
				}
				cacheClear( "", "ehcacheOffheap" );
				expect( cacheCount( "ehcacheOffheap" ) ).toBe( 0 );
			});

		});

		describe( "EHCache Byte-Sized Heap", function() {

			beforeEach( function() {
				cacheClear( "", "ehcacheHeapMB" );
			});

			it( "stores and retrieves with MB-based heap", function() {
				cachePut( "hm_str", "hello", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheHeapMB" );
				expect( cacheGet( "hm_str", "ehcacheHeapMB" ) ).toBe( "hello" );
			});

			it( "caches complex values with MB-based heap", function() {
				var data = { name: "Zac", items: [ 1, 2, 3 ] };
				cachePut( "hm_struct", data, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheHeapMB" );
				var result = cacheGet( "hm_struct", "ehcacheHeapMB" );
				expect( result.name ).toBe( "Zac" );
				expect( result.items[ 2 ] ).toBe( 2 );
			});

			it( "evicts when heap MB limit is reached", function() {
				// heapSizeMB=1, so stuffing in lots of large-ish values should evict
				loop from="1" to="500" index="local.i" {
					cachePut( "hm_big_#i#", repeatString( "x", 10000 ), createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheHeapMB" );
				}
				// count should be less than 500 if eviction kicked in (1MB heap can't hold 500 * 10KB)
				expect( cacheCount( "ehcacheHeapMB" ) ).toBeLT( 500 );
				// but non-zero — entries are still there
				expect( cacheCount( "ehcacheHeapMB" ) ).toBeGT( 0 );
			});

		});

	}

	private function createCaches() {
		application action="update" name="ehcacheOffHeapTest" caches={
			"ehcacheOffheap": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "100",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"offheapSizeMB": "32"
				},
				default: ""
			},
			"ehcacheHeapMB": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"heapSizeMB": "1",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false"
				},
				default: ""
			}
		};
	}

}
