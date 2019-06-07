package raymarchexplorer;

import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.system.MemoryUtil.*;

import java.io.IOException;

import org.lwjgl.glfw.GLFWVidMode;
import org.lwjgl.opengl.GL;

import raymarchexplorer.input.Input;


public class Main implements Runnable{

	private int width = 1280;
	private int height = 720;
	
	private Thread thread;
	private boolean running = false;
	
	private long window;
	
	public void start() {
		
		running = true;
		thread = new Thread(this, "Game");
		thread.start();
	}
	
	private void init() {
		//if (glfwInit() != GL_TRUE) {
		if (glfwInit() != true) {
			//TODO: handle it
			throw new IllegalStateException("Failed to initialise GLFW!");
		}
		
		glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);
		window = glfwCreateWindow(width, height, "RaymarchExplorer", NULL, NULL);
		
		if (window == NULL) {
			//TODO: handle
			return;
		}
		
		GLFWVidMode vidmode = glfwGetVideoMode(glfwGetPrimaryMonitor());
		glfwSetWindowPos(window, (vidmode.width() - width) / 2, (vidmode.height() - height) / 2);
		
		glfwSetKeyCallback(window, new Input());
		
		glfwMakeContextCurrent(window);
		glfwShowWindow(window);
		
		GL.createCapabilities();
		
		glClearColor(1.0f, 0f, 0f, 1.0f);
		glEnable(GL_DEPTH_TEST);
		System.out.println("OpenGl: " + glGetString(GL_VERSION));
	}
	
	public void run() {
		init();
		
		while (running) {
			update();
			render();
			
			if (glfwWindowShouldClose(window) == true) {
				running = false;
			}
		}
	}
	
	private void update() {
		glfwPollEvents();
		
		if (Input.keys[GLFW_KEY_SPACE]) {
			System.out.println("space");
		}
	}
	
	private void render() {
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glfwSwapBuffers(window);
	}
	
	public static void main(String[] args) {
		new Main().start();
	}

}
