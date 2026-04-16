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
package org.lucee.extension.cache.eh;

import java.util.Date;

import lucee.commons.io.cache.CacheEntry;
import lucee.runtime.type.Struct;

import org.lucee.extension.cache.eh.LuceeExpiryPolicy.EntryMeta;
import org.lucee.extension.cache.eh.util.CacheUtil;

public class EHCacheEntry implements CacheEntry {

	private final String key;
	private final Object value;
	private final EntryMeta meta;

	public EHCacheEntry( String key, Object value, EntryMeta meta ) {
		this.key = key;
		this.value = value;
		this.meta = meta;
	}

	@Override
	public Date created() {
		return meta != null ? new Date( meta.createdAt ) : null;
	}

	@Override
	public Date lastHit() {
		return null;
	}

	@Override
	public Date lastModified() {
		return meta != null ? new Date( meta.lastModified ) : created();
	}

	@Override
	public int hitCount() {
		return -1;
	}

	@Override
	public long idleTimeSpan() {
		return meta != null && meta.idleTimeMs != null ? meta.idleTimeMs : 0;
	}

	@Override
	public long liveTimeSpan() {
		return meta != null && meta.liveTimeMs != null ? meta.liveTimeMs : 0;
	}

	@Override
	public long size() {
		return 0;
	}

	@Override
	public String getKey() {
		return key;
	}

	@Override
	public Object getValue() {
		return value;
	}

	@Override
	public String toString() {
		return CacheUtil.toString( this );
	}

	@Override
	public Struct getCustomInfo() {
		return CacheUtil.getInfo( this );
	}
}
