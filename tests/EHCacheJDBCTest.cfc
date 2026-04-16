component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	public function beforeAll() {
		if ( !noPostgres() ) {
			application action="update" name="ehcacheJDBCTest" datasource=server.getDatasource( "postgres" );
			createCache();
			cacheClear( "", "ehcacheJDBC" );
			cacheClear( "", "ehcacheJDBCDisk" );
		}
	}

	public function afterAll() {
		if ( !noPostgres() ) {
			cacheClear( "", "ehcacheJDBC" );
			cacheClear( "", "ehcacheJDBCDisk" );
		}
	}

	private boolean function noPostgres() { return structCount( server.getDatasource( "postgres" ) ) == 0; }

	public function run( testResults, testBox ) {

		describe( "EHCache JDBC Type Caching", function() {

			// LDEV-2911 regression — PGobject (jsonb) not found by ehcache classloader
			it( title: "caches a postgres jsonb value", skip: noPostgres, body: function() {
				var res = queryExecute( "SELECT '{""a"": ""test""}'::jsonb AS result" );
				var jsonbVal = res.result[ 1 ];
				cachePut( "pgJsonb", jsonbVal, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheJDBC" );
				var cached = cacheGet( "pgJsonb", "ehcacheJDBC" );
				expect( cached ).notToBeNull();
			});

			it( title: "caches a query with jsonb column", skip: noPostgres, body: function() {
				var res = queryExecute( "SELECT '{""name"": ""lucee""}'::jsonb AS data, 1 AS id" );
				cachePut( "pgQuery", res, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheJDBC" );
				var cached = cacheGet( "pgQuery", "ehcacheJDBC" );
				expect( isQuery( cached ) ).toBeTrue();
				expect( cached.recordCount ).toBe( 1 );
			});

			it( title: "caches a postgres array type", skip: noPostgres, body: function() {
				var res = queryExecute( "SELECT ARRAY[1,2,3] AS nums" );
				cachePut( "pgArray", res, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheJDBC" );
				var cached = cacheGet( "pgArray", "ehcacheJDBC" );
				expect( isQuery( cached ) ).toBeTrue();
				expect( cached.recordCount ).toBe( 1 );
			});

			// LDEV-2911 — disk deserialization needs PG driver on the deserializing classloader
			it( title: "survives disk round-trip with jsonb", skip: noPostgres, body: function() {
				cacheClear( "", "ehcacheJDBCDisk" );
				var res = queryExecute( "SELECT '{""key"": ""value""}'::jsonb AS data" );
				cachePut( "pgDiskRT", res, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheJDBCDisk" );
				// fill heap to force disk spill
				loop from="1" to="15" index="local.i" {
					cachePut( "filler_#i#", "x", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "ehcacheJDBCDisk" );
				}
				local.cached = cacheGet( "pgDiskRT", "ehcacheJDBCDisk" );
				expect( isNull( local.cached ) ).toBeFalse( "disk round-trip should return the cached value" );
				expect( isQuery( local.cached ) ).toBeTrue();
			});

		});

	}

	private function createCache() {
		application action="update" caches={
			"ehcacheJDBC": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "1000",
					"memoryevictionpolicy": "LRU",
					"timeToIdleSeconds": "300",
					"timeToLiveSeconds": "300",
					"overflowtodisk": "false",
					"diskpersistent": "false",
					"maxelementsondisk": "0",
					"distributed": "off"
				},
				default: ""
			},
			"ehcacheJDBCDisk": {
				class: "org.lucee.extension.cache.eh.EHCache",
				storage: false,
				custom: {
					"eternal": "false",
					"maxelementsinmemory": "10",
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
