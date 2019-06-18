//http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/


#version 450
#extension GL_KHR_vulkan_glsl : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(binding = 0, rgba32f) uniform writeonly image2D img;

//Variables
float EPSILON = 0.001f;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
int MAX_MARCHING_STEPS = 250;

/**
 * Signed distance function for a sphere centered at the origin with radius 1.0;
 */
float sphereSDF(vec3 samplePoint) {
    return length(samplePoint) - 1.0;
}


/**
 * Signed distance function describing the scene.
 * 
 * Absolute value of the return value indicates the distance to the surface.
 * Sign indicates whether the point is inside or outside the surface,
 * negative indicating inside.
 */
 /*
float SceneSDF(vec3 samplePoint) {
    return sphereSDF(samplePoint);
}
*/

vec2 SceneSDF(vec3 pos) {
    float Bailout = 2f;
    float Iterations = 50f;
    float Power = 3f;

	vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
    int iterations = 0;
	for (int i = 0; i < Iterations; i++) {
        iterations = i;

		r = length(z);
		if (r>Bailout) break;
		
		// convert to polar coordinates
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr =  pow( r, Power-1.0)*Power*dr + 1.0;
		
		// scale and rotate the point
		float zr = pow( r,Power);
		theta = theta*Power;
		phi = phi*Power;
		
		// convert back to cartesian coordinates
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=pos;
	}
    float dst = 0.5*log(r)*r/dr;
	return vec2(iterations, dst);
}


vec3 EstimateNormal(vec3 p) {
    float x = SceneSDF(vec3(p.x+EPSILON,p.y,p.z)).y - SceneSDF(vec3(p.x-EPSILON,p.y,p.z)).y;
    float y = SceneSDF(vec3(p.x,p.y+EPSILON,p.z)).y - SceneSDF(vec3(p.x,p.y-EPSILON,p.z)).y;
    float z = SceneSDF(vec3(p.x,p.y,p.z+EPSILON)).y - SceneSDF(vec3(p.x,p.y,p.z-EPSILON)).y;
    return normalize(vec3(x,y,z));
}


/**
 * Return the shortest distance from the eyepoint to the scene surface along
 * the marching direction. If no part of the surface is found between start and end,
 * return end.
 * 
 * eye: the eye point, acting as the origin of the ray
 * marchingDirection: the normalized direction to march in
 * start: the starting distance away from the eye
 * end: the max distance away from the eye to march before giving up
 */
vec2 ShortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        vec2 sceneInfo = SceneSDF(eye + depth * marchingDirection);
        float dist = sceneInfo.y;
        float escapeIterations = sceneInfo.x;

        if (dist < EPSILON) {
			return vec2(depth, escapeIterations);
        }

        depth += dist;

        if (depth >= end) {
            return vec2(end, 0);
        }
    }
    return vec2(end, 0);
}

/**
 * Return the normalized direction to march in from the eye point for a single pixel.
 * 
 * fieldOfView: vertical field of view in degrees
 * size: resolution of the output image
 * fragCoord: the x,y coordinate of the pixel in the output image
 */
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

void main(void)
{
	vec3 dir = rayDirection(45.0, vec2(imageSize(img)), gl_GlobalInvocationID.xy);
    vec3 eye = vec3(0.0, 0.0, 5.0);
    vec2 marchResult = ShortestDistanceToSurface(eye, dir, MIN_DIST, MAX_DIST);
    float dist = marchResult.x;
    float escapeIterations = marchResult.y;

    // Ray didn't hit anything
    if (dist > MAX_DIST - EPSILON) {
        vec4 fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // Ray has hit a surface
    //vec3 normal = EstimateNormal(eye - dir * EPSILON * 2);  
    //vec3 colourMix = clamp(normal, 0.0, 1.0);

    //vec3 colourMix = normal;
    //vec3 colourMix = clamp(vec3(escapeIterations, escapeIterations, escapeIterations), 0.0, 1.0);
    vec3 colourMix = vec3(escapeIterations/50f, 0, escapeIterations/50f *0.5f);

    vec4 fragColor = vec4(colourMix, 1.0);

    imageStore(img, ivec2(gl_GlobalInvocationID.xy), fragColor);
}