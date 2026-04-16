<cfcomponent extends="Cache">

	<cfset fields=array(
		field("Eternal","eternal","false",true,"Sets whether elements are eternal. If eternal, timeouts are ignored and the element is never expired","checkbox","true"),
		field("Maximum elements in memory","maxelementsinmemory","10000",true,"Sets the maximum number of objects to be held in the heap tier","text"),
		field("Time to idle in seconds","timeToIdleSeconds","86400",true,"Sets the time to idle for an element before it expires. Is only used if the element is not eternal","time"),
		field("Time to live in seconds","timeToLiveSeconds","86400",true,"Sets the timeout to live for an element before it expires. Is only used if the element is not eternal","time"),

		field("Disk persistent","diskpersistent","true",true,"Whether the disk cache persists between restarts","checkbox","true"),
		field("Overflow to disk","overflowtodisk","true",true,"Whether elements overflow to a disk tier when the heap tier is full","checkbox","true"),
		field("Disk size (MB)","diskSizeMB","100",true,"Sets the maximum size of the disk tier in megabytes","text"),
		field("Track per-entry metadata","trackItemMetadata","true",true,"Tracks per-entry creation time and timespans. Disable for lower overhead when per-entry TTL/TTI is not needed","checkbox","true")
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
