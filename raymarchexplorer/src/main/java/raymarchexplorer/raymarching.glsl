//http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/


#version 450
//#extension GL_KHR_vulkan_glsl : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(binding = 0, rgba32f) uniform writeonly image2D img;

// Variables
float EPSILON = 0.001;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
int MAX_MARCHING_STEPS = 250;

float Power = -5.0;

// Time
float uTime = 0.0;
uniform float timeValue;


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
    float Bailout = 2.0;
    float Iterations = 15.0;

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
		float zr = pow(r,Power);
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
 * Lighting contribution of a single point light source via Phong illumination.
 * 
 * The vec3 returned is the RGB color of the light's contribution.
 *
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 * lightPos: the position of the light
 * lightIntensity: color/intensity of the light
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongContribForLight(vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye,
                          vec3 lightPos, vec3 lightIntensity) {
    vec3 N = EstimateNormal(p);
    vec3 L = normalize(lightPos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));
    
    float dotLN = dot(L, N);
    float dotRV = dot(R, V);
    
    if (dotLN < 0.0) {
        // Light not visible from this point on the surface
        return vec3(0.0, 0.0, 0.0);
    } 
    
    if (dotRV < 0.0) {
        // Light reflection in opposite direction as viewer, apply only diffuse
        // component
        return lightIntensity * (k_d * dotLN);
    }
    return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
}


/**
 * Lighting via Phong illumination.
 * 
 * The vec3 returned is the RGB color of that point after lighting is applied.
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongIllumination(vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye) {
    const vec3 ambientLight = 0.5 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * k_a;
    
    vec3 light1Pos = vec3(4.0,
                          2.0,
                          4.0);
    vec3 light1Intensity = vec3(0.4, 0.4, 0.4);
    
    color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                  light1Pos,
                                  light1Intensity);
    
    vec3 light2Pos = vec3(2.0 * sin(0.37),
                          2.0 * cos(0.37),
                          2.0);
    vec3 light2Intensity = vec3(0.4, 0.4, 0.4);
    
    color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                  light2Pos,
                                  light2Intensity);    
    return color;
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
    // Time
    Power += cos((timeValue * 0.1)) * 10;

    vec3 colorPalette = vec3(0.5 * cos(timeValue) + 0.5, 0.5 * -cos(timeValue) + 0.5, 0.5 * cos(timeValue) + 0.5);




    //vec3 lightDirection = vec3(0.0, 0.0, 1.0);

	vec3 dir = rayDirection(-45.0, vec2(imageSize(img)), gl_GlobalInvocationID.xy);
    vec3 eye = vec3(0.0, 0.0, -5.0); //NEED TO MAKE THIS = POSITION
    vec2 marchResult = ShortestDistanceToSurface(eye, dir, MIN_DIST, MAX_DIST);
    float dist = marchResult.x;
    float escapeIterations = marchResult.y;

    // Ray didn't hit anything
    /*
    if (dist > MAX_DIST - EPSILON) {
        vec4 fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }
    */

    // The closest point on the surface to the eyepoint along the view ray  
    vec3 p = eye + dist * dir;
    
    vec3 K_a = vec3(0.5, 0.5, 0.5);
    vec3 K_d = vec3(1.00, 0.45, 0.25);
    vec3 K_s = vec3(0.45, 0.45, 0.45);

    float shininess = 10.0;
    

    //vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, eye);

    //vec3 normal = EstimateNormal(eye - dir * EPSILON * 2);
    //vec3 newVec = vec3(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5); 
    //vec3 color = clamp(vec3(dot(newVec, lightDirection)), 0.0 , 1.0);

    //vec3 colourMixA = clamp(vec3(escapeIterations/49.0, escapeIterations/49.0, escapeIterations/49.0), 0.0, 1.0);

    //float colourMixRatio = 0.5;
    //color = clamp(colourMixA * colourMixRatio + color * (1 - colourMixRatio), 0.0, 1.0);

    //color = (color);


    // NEW LIGHTING
    // http://blog.hvidtfeldts.net/index.php/2011/08/distance-estimated-3d-fractals-ii-lighting-and-coloring/
    // https://www.cs.cmu.edu/~kmcrane/Projects/QuaternionJulia/paper.pdf
    // PhongIllumination, Shadows
    // Phong
    vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, eye);

    // Shadows
    //  The shadow ray will start at the intersection point and go
    //  towards the point light. We initially move the ray origin
    //  a little bit along this direction so that we don’t mistakenly
    //  find an intersection with the same point again.
    //float3 L = normalize( light - rO );
    //rO += N*epsilon*2.0;
    //dist = intersectQJulia( rO, L, mu, maxIterations, epsilon );
    //  Again, if our estimate of the distance to the set is small, we say
    //  that there was a hit. In this case it means that the point is in
    //  shadow and should be given darker shading.
    //if( dist < epsilon )
    //{
    //    color.rgb *= 0.4; // (darkening the shaded value is not really correct, but looks good)
    //}

    float colorComp = (escapeIterations/16.0);
    if (colorComp, colorComp, colorComp != 0.0){
        color = (colorPalette * colorComp * 0.5) + (color * colorComp * 0.5);
    }
    else{
        color = (colorPalette * colorComp);
    }


    vec4 fragColor = vec4(color, 1.0);

    imageStore(img, ivec2(gl_GlobalInvocationID.xy), fragColor);
}