component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	public function beforeAll() {
		createCache();
	}

	public function run( testResults, testBox ) {

		describe( "EHCache Basic Operations", function() {

			beforeEach( function() {
				cacheClear( "", "ehcacheBasic" );
			});

			it( "can put and get a value", function() {
				cachePut( "basicKey", "hello world", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				var result = cacheGet( "basicKey", "ehcacheBasic" );
				expect( result ).toBe( "hello world" );
			});

			it( "returns false for a cache miss", function() {
				expect( cacheIdExists( "nonExistentKey_#createUUID()#", "ehcacheBasic" ) ).toBeFalse();
			});

			it( "reports contains correctly", function() {
				cachePut( "existsKey", "value", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				expect( cacheIdExists( "existsKey", "ehcacheBasic" ) ).toBeTrue();
				expect( cacheIdExists( "doesNotExist_#createUUID()#", "ehcacheBasic" ) ).toBeFalse();
			});

			it( "can remove an entry", function() {
				cachePut( "removeMe", "gone soon", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				expect( cacheIdExists( "removeMe", "ehcacheBasic" ) ).toBeTrue();
				cacheRemove( "removeMe", false, "ehcacheBasic" );
				expect( cacheIdExists( "removeMe", "ehcacheBasic" ) ).toBeFalse();
			});

			it( "can clear all entries", function() {
				cachePut( "clearA", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				cachePut( "clearB", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				cachePut( "clearC", "c", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				expect( cacheCount( "ehcacheBasic" ) ).toBe( 3 );
				cacheClear( "", "ehcacheBasic" );
				expect( cacheCount( "ehcacheBasic" ) ).toBe( 0 );
			});

			it( "can list keys", function() {
				cachePut( "keyA", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				cachePut( "keyB", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				cachePut( "keyC", "c", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				var ids = cacheGetAllIds( cacheName: "ehcacheBasic" );
				expect( ids ).toBeArray();
				expect( arrayLen( ids ) ).toBe( 3 );
			});

			it( "can get all values", function() {
				cachePut( "valA", "alpha", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				cachePut( "valB", "bravo", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				var all = cacheGetAll( cacheName: "ehcacheBasic" );
				expect( all ).toBeStruct();
				expect( structCount( all ) ).toBe( 2 );
			});

			it( "can overwrite an existing entry", function() {
				cachePut( "overwrite", "first", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				expect( cacheGet( "overwrite", "ehcacheBasic" ) ).toBe( "first" );
				cachePut( "overwrite", "second", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				expect( cacheGet( "overwrite", "ehcacheBasic" ) ).toBe( "second" );
			});

			it( "reports count correctly", function() {
				expect( cacheCount( "ehcacheBasic" ) ).toBe( 0 );
				cachePut( "countA", "a", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				cachePut( "countB", "b", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheBasic" );
				expect( cacheCount( "ehcacheBasic" ) ).toBe( 2 );
			});

		});

	}

	private function createCache() {
		application action="update" name="ehcacheBasicTest" caches={
			"ehcacheBasic": {
				class: "org.lucee.extension.cache.eh.EHCache",
				maven: "org.lucee:ehcache-extension:#server.system.environment.EXTENSION_VERSION ?: '3.0.0.0-SNAPSHOT'#",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"memoryevictionpolicy": "LRU",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "true",
					"diskpersistent": "false",
					"maxelementsondisk": "10000",
					"distributed": "off"
				},
				default: ""
			}
		};
	}

}
