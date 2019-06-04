package raymarchexplorer.graphics;

import raymarchexplorer.utils.ShaderUtils;
import static org.lwjgl.opengl.GL20.*;

import static org.lwjgl.BufferUtils.*;

import java.nio.FloatBuffer;
import java.util.HashMap;
import java.util.Map;

import org.joml.*;
import org.lwjgl.BufferUtils;

public class Shader {
	private final int ID;
	private Map<String, Integer> locationCache = new HashMap<String, Integer>();
	
	public Shader(String vertex, String fragment) {
		ID = ShaderUtils.load(vertex, fragment);
	}
	
	public int getUniform(String name) {
		if (locationCache.containsKey(name)) {
			return locationCache.get(name);
		}
		
		int result = glGetUniformLocation(ID, name);		
		if (result == -1) {
			System.err.println("Could not find uniform variable '" + name + "'");
		}
		else {
			locationCache.put(name, result);
		}
		
		return result;
	}
	
	public void setUniform1i(String name, int value) {
		glUniform1i(getUniform(name), value);
	}
	
	public void setUniform1f(String name, int value) {
		glUniform1f(getUniform(name), value);
	}
	
	public void setUniform2f(String name, Vector2f vector) {
		glUniform2f(getUniform(name), vector.x, vector.y);
	}
	
	public void setUniform3f(String name, Vector3f vector) {
		glUniform3f(getUniform(name), vector.x, vector.y, vector.z);
	}
	
	public void setUniformMat4f(String name, Matrix4f matrix) {	//https://github.com/JOML-CI/JOML/wiki/JOML-and-modern-OpenGL
		FloatBuffer fb = BufferUtils.createFloatBuffer(16);	//4*4 = 16 (as it's a 4(?)-dimensional matrix)
		matrix.get(fb);
		
		glUniformMatrix4fv(getUniform(name), false, fb);
	}
	

	
	public void enable() {
		glUseProgram(ID);
	}
	
	public void disable() {
		glUseProgram(0);
	}
}
