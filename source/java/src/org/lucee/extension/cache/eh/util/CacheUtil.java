/**
 *
 * Copyright (c) 2014, the Railo Company Ltd. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 **/
package org.lucee.extension.cache.eh.util;

import java.io.IOException;

import lucee.commons.io.cache.Cache;
import lucee.commons.io.cache.CacheEntry;
import lucee.commons.io.cache.CacheFilter;
import lucee.loader.engine.CFMLEngineFactory;
import lucee.runtime.type.Collection.Key;
import lucee.runtime.type.Struct;
import lucee.runtime.type.dt.TimeSpan;

public class CacheUtil {

	// Pre-built Keys for struct writes — avoids string-to-Key conversion on every setEL
	private static final Key KEY_KEY;
	private static final Key KEY_CREATED;
	private static final Key KEY_LAST_HIT;
	private static final Key KEY_LAST_MODIFIED;
	private static final Key KEY_HIT_COUNT;
	private static final Key KEY_MISS_COUNT;
	private static final Key KEY_SIZE;
	private static final Key KEY_IDLE_TIME_SPAN;
	private static final Key KEY_LIVE_TIME_SPAN;
	static {
		lucee.runtime.util.Creation cu = CFMLEngineFactory.getInstance().getCreationUtil();
		KEY_KEY = cu.createKey("key");
		KEY_CREATED = cu.createKey("created");
		KEY_LAST_HIT = cu.createKey("last_hit");
		KEY_LAST_MODIFIED = cu.createKey("last_modified");
		KEY_HIT_COUNT = cu.createKey("hit_count");
		KEY_MISS_COUNT = cu.createKey("miss_count");
		KEY_SIZE = cu.createKey("size");
		KEY_IDLE_TIME_SPAN = cu.createKey("idle_time_span");
		KEY_LIVE_TIME_SPAN = cu.createKey("live_time_span");
	}

	public static Struct getInfo(CacheEntry ce) {
		Struct info=CFMLEngineFactory.getInstance().getCreationUtil().createStruct();
		info.setEL(KEY_KEY, ce.getKey());
		info.setEL(KEY_CREATED, ce.created());
		info.setEL(KEY_LAST_HIT, ce.lastHit());
		info.setEL(KEY_LAST_MODIFIED, ce.lastModified());

		info.setEL(KEY_HIT_COUNT, Double.valueOf(ce.hitCount()));
		info.setEL(KEY_SIZE, Double.valueOf(ce.size()));


		info.setEL(KEY_IDLE_TIME_SPAN, toTimespan(ce.idleTimeSpan()));
		info.setEL(KEY_LIVE_TIME_SPAN, toTimespan(ce.liveTimeSpan()));


		return info;
	}


	public static Struct getInfo(Cache c) {
		Struct info=CFMLEngineFactory.getInstance().getCreationUtil().createStruct();
		try{
			long value = c.hitCount();
			if(value>=0)info.setEL(KEY_HIT_COUNT, Double.valueOf(value));
		}
		catch(IOException ioe){
			// simply ignore
		}

		try{
			long value = c.missCount();
			if(value>=0)info.setEL(KEY_MISS_COUNT, Double.valueOf(value));
		}
		catch(IOException ioe){
			// simply ignore
		}

		return info;
	}


	public static Object toTimespan(long timespan) {
		if(timespan==0)return "";

		TimeSpan ts = CFMLEngineFactory.getInstance().getCastUtil().toTimespan(timespan);

		if(ts==null)return "";
		return ts;
	}


	public static String toString(CacheEntry ce) {

		return "created:	"+ce.created()
		+"\nlast-hit:	"+ce.lastHit()
		+"\nlast-modified:	"+ce.lastModified()

		+"\nidle-time:	"+ce.idleTimeSpan()
		+"\nlive-time	:"+ce.liveTimeSpan()

		+"\nhit-count:	"+ce.hitCount()
		+"\nsize:		"+ce.size();
	}

	public static boolean allowAll(CacheFilter filter) {
			if(filter==null)return true;

			String p = filter.toPattern();
			if(p==null)p="";
			else p=p.trim();

			return p.equals("*") || p.equals("");
	}
}
