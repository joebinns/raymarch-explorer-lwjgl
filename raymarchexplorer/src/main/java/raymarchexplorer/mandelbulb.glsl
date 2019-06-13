#version 450
#extension GL_KHR_vulkan_glsl : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(binding = 0, rgba32f) uniform writeonly image2D img;

/*
mat4 _CameraToWorld;
mat4 _CameraInverseProjection;
vec3 _LightDirection;

float power;
float darkness;
float blackAndWhite;
vec3 colourAMix;
vec3 colourBMix;

float epsilon = 0.001f;
float maxDst = 200;
int maxStepCount = 250;
*/

///////////////////////////////////////

/*
mat4 _CameraToWorld;
mat4 _CameraInverseProjection;
vec3 _LightDirection;
*/

float power = 4;
float darkness = 75;
float blackAndWhite = 0;
vec3 colourAMix = vec3(0, 0, 1);
vec3 colourBMix = vec3(1, 0, 0);

float epsilon = 0.001f;
float maxDst = 200;
int maxStepCount = 250;

struct Ray {
    vec3 origin;
    vec3 direction;
};

Ray CreateRay(vec3 origin, vec3 direction) {
    Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    return ray;
}

Ray CreateCameraRay(vec2 uv) {
    //vec3 origin = _CameraToWorld * vec4(0,0,0,1).xyz;
    //vec3 origin = (_CameraToWorld * vec4(0,0,0,1)).xyz;
    vec3 origin = vec3(0.1, 0, -2.5);

    //vec3 direction = _CameraInverseProjection * vec4(uv,0,1).xyz;
    //vec3 direction = (_CameraInverseProjection * vec4(uv,0,1)).xyz;
    vec3 direction = vec3(0, 0, 1);

    //direction = _CameraToWorld * vec4(direction,0).xyz;
    //direction = (_CameraToWorld * vec4(direction,0)).xyz;

    direction = normalize(direction);
    return CreateRay(origin, direction);
}

// Mandelbulb distance estimation:
// http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
vec2 SceneInfo(vec3 position) {
    vec3 z = position;
	float dr = 1.0;
	float r = 0.0;
    int iterations = 0;

	for (int i = 0; i < 15 ; i++) {
        iterations = i;
		r = length(z);

		if (r>2) {
            break;
        }
        
		// convert to polar coordinates
		float theta = acos(z.z/r);
		float phi = atan(z.x, z.y);
		dr =  pow( r, power-1.0)*power*dr + 1.0;

		// scale and rotate the point
		float zr = pow( r,power);
		theta = theta*power;
		phi = phi*power;
		
		// convert back to cartesian coordinates
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=position;
	}
    float dst = 0.5*log(r)*r/dr;
	return vec2(iterations,dst*1);
}

vec3 EstimateNormal(vec3 p) {
    float x = SceneInfo(vec3(p.x+epsilon,p.y,p.z)).y - SceneInfo(vec3(p.x-epsilon,p.y,p.z)).y;
    float y = SceneInfo(vec3(p.x,p.y+epsilon,p.z)).y - SceneInfo(vec3(p.x,p.y-epsilon,p.z)).y;
    float z = SceneInfo(vec3(p.x,p.y,p.z+epsilon)).y - SceneInfo(vec3(p.x,p.y,p.z-epsilon)).y;
    return normalize(vec3(x,y,z));
}

float mod2(float x) {
  return x - 2.0 * floor(x / 2.0);  // bugs out if x == 2.0
}


void main(void)
{
    vec2 uv = gl_GlobalInvocationID.xy / imageSize(img);
       
    // Background gradient
    vec4 result = mix(vec4(51,3,20,1),vec4(16,6,28,1),uv.y)/255.0;
    
    // Raymarching:
    Ray ray = CreateCameraRay(uv * 2 - 1);
    float rayDst = 0;
    int marchSteps = 0;

    while (rayDst < maxDst && marchSteps < maxStepCount) {
        marchSteps ++;
        vec2 sceneInfo = SceneInfo(ray.origin);
        float dst = sceneInfo.y;
        
        // Ray has hit a surface
        if (dst <= epsilon) {
            float escapeIterations = sceneInfo.x;

            vec3 normal = EstimateNormal(ray.origin-ray.direction*epsilon*2);
            //float colourA = clamp(dot(normal*.5+.5,-_LightDirection), 0.0, 1.0);
            float colourA = clamp(dot(normal*.5+.5,-vec3(0.5,0.5,0)), 0.0, 1.0);
            float colourB = clamp(escapeIterations/16.0, 0.0, 1.0);
            vec3 colourMix = clamp(colourA * colourAMix + colourB * colourBMix, 0.0, 1.0);

            result = vec4(colourMix.xyz,1);
            break;
        }
        ray.origin += ray.direction * dst;
        rayDst += dst;
    }
    float rim = marchSteps/darkness;
    //Destination[id.xy] = mix(result, 1, blackAndWhite) * rim;
    vec4 to_write = mix(result, vec4(1,1,1,1), blackAndWhite) * rim;
    imageStore(img, ivec2(gl_GlobalInvocationID.xy), to_write);
}