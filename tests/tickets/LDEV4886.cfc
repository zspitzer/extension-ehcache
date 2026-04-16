component extends = "org.lucee.cfml.test.LuceeTestCase" labels="ehcache" skip=true {

	// This test verified the ehcache v2 Java API directly.
	// Skipped: ehcache v3 uses a completely different API (org.ehcache.*).
	// The functionality is now tested through the Lucee cache BIFs in the other test files.

	public any function test() {
		// ehcache v3 programmatic API test placeholder
		// CacheManager and Cache creation is handled by EHCache.init() via Lucee's cache framework
	}

}
