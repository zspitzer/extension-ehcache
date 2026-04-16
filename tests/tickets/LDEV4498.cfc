component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	// LDEV-4498: Ordered struct loses ordering after cache round-trip
	// StructNew('ordered') cached via cachePut() came back as unordered in v2.
	// v3 should preserve LinkedHashMap ordering through Java serialization.

	public function beforeAll() {
		application action="update" name="LDEV-4498" caches={
			"testCache4498": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false"
				},
				default: ""
			},
			"testCache4498Disk": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "10",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "true",
					"diskpersistent": "false",
					"diskSizeMB": "10"
				},
				default: ""
			}
		};
		cacheClear( "", "testCache4498" );
		cacheClear( "", "testCache4498Disk" );
	}

	public function afterAll() {
		cacheClear( "", "testCache4498" );
		cacheClear( "", "testCache4498Disk" );
	}

	public function run( testResults, testBox ) {

		describe( "LDEV-4498: ordered struct key order preservation", function() {

			it( "preserves insertion order in heap cache", function() {
				var data = structNew( "ordered" );
				data[ "zulu" ] = 1;
				data[ "alpha" ] = 2;
				data[ "mike" ] = 3;
				cachePut( "ordered1", data, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache4498" );
				var result = cacheGet( "ordered1", "testCache4498" );
				var keys = structKeyArray( result );
				expect( keys[ 1 ] ).toBe( "zulu" );
				expect( keys[ 2 ] ).toBe( "alpha" );
				expect( keys[ 3 ] ).toBe( "mike" );
			});

			it( "preserves insertion order after disk round-trip", function() {
				var data = structNew( "ordered" );
				data[ "charlie" ] = 1;
				data[ "bravo" ] = 2;
				data[ "delta" ] = 3;
				data[ "alpha" ] = 4;
				cachePut( "ordered2", data, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache4498Disk" );
				// fill heap to encourage disk spill
				loop from="1" to="15" index="local.i" {
					cachePut( "pad_#i#", "x", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache4498Disk" );
				}
				var result = cacheGet( "ordered2", "testCache4498Disk" );
				expect( result ).notToBeNull();
				var keys = structKeyArray( result );
				expect( keys[ 1 ] ).toBe( "charlie" );
				expect( keys[ 2 ] ).toBe( "bravo" );
				expect( keys[ 3 ] ).toBe( "delta" );
				expect( keys[ 4 ] ).toBe( "alpha" );
			});

			it( "preserves order in nested ordered structs", function() {
				var outer = structNew( "ordered" );
				var inner = structNew( "ordered" );
				inner[ "second" ] = 2;
				inner[ "first" ] = 1;
				outer[ "child" ] = inner;
				outer[ "name" ] = "test";
				cachePut( "ordered3", outer, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache4498" );
				var result = cacheGet( "ordered3", "testCache4498" );
				var outerKeys = structKeyArray( result );
				expect( outerKeys[ 1 ] ).toBe( "child" );
				expect( outerKeys[ 2 ] ).toBe( "name" );
				var innerKeys = structKeyArray( result.child );
				expect( innerKeys[ 1 ] ).toBe( "second" );
				expect( innerKeys[ 2 ] ).toBe( "first" );
			});

		});

	}

}
