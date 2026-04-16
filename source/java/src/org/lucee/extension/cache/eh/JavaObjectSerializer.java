package org.lucee.extension.cache.eh;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.io.ObjectStreamClass;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.ehcache.spi.serialization.Serializer;
import org.ehcache.spi.serialization.SerializerException;

import lucee.loader.engine.CFMLEngineFactory;

/**
 * EHCache 3 serializer using standard Java serialization, matching the approach
 * used by the redis, memcached, and dynamodb cache extensions.
 */
public class JavaObjectSerializer implements Serializer<Object> {

	private final ClassLoader classLoader;

	// Classloaders discovered during serialization — these can resolve classes
	// (like JDBC driver types) that the extension's own classloader can't see.
	private final Set<ClassLoader> knownClassLoaders = ConcurrentHashMap.newKeySet();

	public JavaObjectSerializer( ClassLoader classLoader ) {
		this.classLoader = classLoader;
	}

	@Override
	public ByteBuffer serialize( Object object ) throws SerializerException {
		try {
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			ObjectOutputStream oos = new ClassLoaderTrackingOutputStream( baos );
			oos.writeObject( object );
			oos.flush();
			return ByteBuffer.wrap( baos.toByteArray() );
		}
		catch ( IOException e ) {
			throw new SerializerException( e );
		}
	}

	@Override
	public Object read( ByteBuffer binary ) throws SerializerException, ClassNotFoundException {
		try {
			byte[] bytes = new byte[binary.remaining()];
			binary.get( bytes );
			ObjectInputStream ois = new ClassLoaderObjectInputStream( classLoader, new ByteArrayInputStream( bytes ) );
			return ois.readObject();
		}
		catch ( IOException e ) {
			throw new SerializerException( e );
		}
	}

	@Override
	public boolean equals( Object object, ByteBuffer binary ) throws SerializerException, ClassNotFoundException {
		return object.equals( read( binary ) );
	}

	/**
	 * ObjectOutputStream that records classloaders from serialized classes.
	 * When a value containing e.g. PGobject is serialized, we capture the PG
	 * driver's classloader so it's available for deserialization later.
	 */
	private class ClassLoaderTrackingOutputStream extends ObjectOutputStream {

		ClassLoaderTrackingOutputStream( OutputStream out ) throws IOException {
			super( out );
		}

		@Override
		protected void annotateClass( Class<?> cl ) throws IOException {
			ClassLoader loader = cl.getClassLoader();
			if ( loader != null && loader != classLoader ) {
				knownClassLoaders.add( loader );
			}
		}
	}

	/**
	 * ObjectInputStream that resolves classes against multiple classloaders:
	 * 1. Extension classloader (ehcache + Lucee + extension classes)
	 * 2. Lucee's ClassUtil (searches all loaded bundles)
	 * 3. Classloaders captured during serialization (JDBC drivers, etc.)
	 * 4. Default ObjectInputStream resolution
	 */
	private class ClassLoaderObjectInputStream extends ObjectInputStream {

		private final ClassLoader cl;

		ClassLoaderObjectInputStream( ClassLoader cl, InputStream in ) throws IOException {
			super( in );
			this.cl = cl;
		}

		@Override
		protected Class<?> resolveClass( ObjectStreamClass desc ) throws IOException, ClassNotFoundException {
			String name = desc.getName();

			// 1. Try extension classloader (handles ehcache + Lucee + extension classes)
			if ( cl != null ) {
				try {
					return Class.forName( name, false, cl );
				}
				catch ( ClassNotFoundException e ) {}
			}

			// 2. Try Lucee's ClassUtil which searches all loaded classloaders
			try {
				return CFMLEngineFactory.getInstance().getClassUtil().loadClass( name );
			}
			catch ( Exception e ) {}

			// 3. Try classloaders captured during serialization
			for ( ClassLoader known : knownClassLoaders ) {
				try {
					return Class.forName( name, false, known );
				}
				catch ( ClassNotFoundException e ) {}
			}

			// 4. Last resort
			return super.resolveClass( desc );
		}
	}
}
