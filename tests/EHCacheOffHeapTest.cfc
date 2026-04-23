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
			}
		};
	}

}
