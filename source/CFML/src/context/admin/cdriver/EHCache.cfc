<cfcomponent extends="Cache">

	<cfset fields=array(
		field("Eternal","eternal","false",true,"Sets whether elements are eternal. If eternal, timeouts are ignored and the element is never expired","checkbox","true"),
		field("Maximum elements in memory","maxelementsinmemory","10000",true,"Sets the maximum number of objects to be held in the heap tier. Ignored if Heap size (MB) is set.","text"),
		field("Heap size (MB)","heapSizeMB","0",true,"Size the heap tier in megabytes instead of entry count. 0 = use element count above. Better for caches with variable-size entries.","text"),
		field("Off-heap size (MB)","offheapSizeMB","0",true,"Off-heap (direct memory) tier size in megabytes. 0 = disabled. Sits between heap and disk with zero GC pressure. Requires serialization.","text"),
		field("Time to idle in seconds","timeToIdleSeconds","86400",true,"Sets the time to idle for an element before it expires. Is only used if the element is not eternal","time"),
		field("Time to live in seconds","timeToLiveSeconds","86400",true,"Sets the timeout to live for an element before it expires. Is only used if the element is not eternal","time"),

		field("Disk persistent","diskpersistent","true",true,"Whether the disk cache persists between restarts","checkbox","true"),
		field("Overflow to disk","overflowtodisk","true",true,"Whether elements overflow to a disk tier when the heap tier is full","checkbox","true"),
		field("Disk size (MB)","diskSizeMB","100",true,"Sets the maximum size of the disk tier in megabytes","text"),
		field("Track per-entry metadata","trackItemMetadata","true",true,"Tracks per-entry creation time and timespans. Disable for lower overhead when per-entry TTL/TTI is not needed","checkbox","true"),
		field("Report statistics in metadata","reportStatistics","false",true,"Include cache statistics (hit/miss/eviction counts) in cacheGetMetadata().custom. Adds a struct allocation per cache get.","checkbox","true"),
		field("Report per-tier statistics","reportTierStatistics","false",true,"Include per-tier statistics (OnHeap/OffHeap/Disk breakdown: hits, misses, mappings, bytes) under a nested 'tiers' struct. Requires Report statistics in metadata for per-entry exposure.","checkbox","true")
	)>


	<cffunction name="getClass" returntype="string">
		<cfreturn "{class}">
	</cffunction>
	<!---
	<cffunction name="getBundleName" returntype="string">
		<cfreturn "{bundlename}">
	</cffunction>
	<cffunction name="getBundleVersion" returntype="string">
		<cfreturn "{bundleversion}">
	</cffunction>
	--->

	<cffunction name="getLabel" returntype="string">
		<cfreturn "{label}">
	</cffunction>
	<cffunction name="getDescription" returntype="string" output="no">
		<cfreturn "{desc}">
	</cffunction>

</cfcomponent>
