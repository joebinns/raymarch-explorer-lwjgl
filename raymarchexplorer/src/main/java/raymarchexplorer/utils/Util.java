package raymarchexplorer.utils;

import java.io.DataInputStream;
import java.io.IOException;
import java.io.InputStream;

public class Util {

	public static CharSequence getCode(InputStream is) throws IOException {
		final DataInputStream dataStream = new DataInputStream(is);
		byte[] shaderCode = new byte[dataStream.available()];
		dataStream.readFully(shaderCode);
		return new String(shaderCode);
	}

	/**
	 * http://bits.stephan-brumme.com/roundUpToNextPowerOfTwo.html
	 */
	public static int nextPowerOfTwo(int x) {
		x--;
		x |= x >> 1; // handle 2 bit numbers
		x |= x >> 2; // handle 4 bit numbers
		x |= x >> 4; // handle 8 bit numbers
		x |= x >> 8; // handle 16 bit numbers
		x |= x >> 16; // handle 32 bit numbers
		x++;
		return x;
	}

}
