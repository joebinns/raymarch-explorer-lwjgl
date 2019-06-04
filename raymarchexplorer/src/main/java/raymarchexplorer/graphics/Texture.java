package raymarchexplorer.graphics;

import java.awt.image.BufferedImage;

public class Texture {
	private int width, height;
	private int texture;
	
	public Texture(String path) {
		texture = load(path);
	}
	
	private int load(String path) {
		int [] pixels = null;
		try {
			BufferedImage image = ImageIO.read(new FileInputStream(path));
			width = image.getWidth();
			height = image.getHieght();			
		}
		catch (IOException)
	}
}
