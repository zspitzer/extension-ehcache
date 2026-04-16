component extends="org.lucee.cfml.test.LuceeTestCase" labels="ehcache" {

	// LDEV-2911: ClassNotFoundException for org.postgresql.util.PGobject
	// In v2, ehcache's DiskStorageFactory couldn't see JDBC driver classes during
	// deserialization due to OSGi classloader isolation. v3 with Maven classloading
	// (start-bundles: false) shares one classloader, which should fix this.

	public function beforeAll() {
		if ( !noPostgres() ) {
			application action="update" name="LDEV-2911" datasource=server.getDatasource( "postgres" );
			application action="update" caches={
				"testCache2911": {
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
				"testCache2911Disk": {
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
			cacheClear( "", "testCache2911" );
			cacheClear( "", "testCache2911Disk" );
		}
	}

	public function afterAll() {
		if ( !noPostgres() ) {
			cacheClear( "", "testCache2911" );
			cacheClear( "", "testCache2911Disk" );
		}
	}

	private boolean function noPostgres() { return structCount( server.getDatasource( "postgres" ) ) == 0; }

	public function run( testResults, testBox ) {

		describe( "LDEV-2911: PGobject classloader visibility", function() {

			it( title: "caches a postgres jsonb value in heap", skip: noPostgres, body: function() {
				var res = queryExecute( "SELECT '{""key"": ""value""}'::jsonb AS data" );
				var val = res.data[ 1 ];
				cachePut( "pgJsonb", val, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache2911" );
				var cached = cacheGet( "pgJsonb", "testCache2911" );
				expect( cached ).notToBeNull();
			});

			it( title: "caches a query with jsonb column in heap", skip: noPostgres, body: function() {
				var res = queryExecute( "SELECT '{""name"": ""lucee""}'::jsonb AS data, 1 AS id" );
				cachePut( "pgQuery", res, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache2911" );
				var cached = cacheGet( "pgQuery", "testCache2911" );
				expect( isQuery( cached ) ).toBeTrue();
				expect( cached.recordCount ).toBe( 1 );
			});

			// Disk deserialization — JavaObjectSerializer falls back to ClassUtil.loadClass()
			it( title: "survives disk round-trip with jsonb query", skip: noPostgres, body: function() {
				cacheClear( "", "testCache2911Disk" );
				var res = queryExecute( "SELECT '{""key"": ""value""}'::jsonb AS data" );
				cachePut( "pgDiskRT", res, createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache2911Disk" );
				// fill heap to force disk spill
				loop from="1" to="15" index="local.i" {
					cachePut( "filler_#i#", "x", createTimespan( 0, 0, 5, 0 ), createTimespan( 0, 0, 5, 0 ), "testCache2911Disk" );
				}
				local.cached = cacheGet( "pgDiskRT", "testCache2911Disk" );
				expect( isNull( local.cached ) ).toBeFalse( "disk round-trip should return the cached value" );
				expect( isQuery( local.cached ) ).toBeTrue();
				expect( local.cached.recordCount ).toBe( 1 );
			});

		});

	}

}
