/* ---------------------------------------------------------------------------------
    FRAGMENT SHADER for sphere tracing squared and cubic quaternion Julia sets
   ---------------------------------------------------------------------------------

    Real-time ray-marched rendering of squared and cubic quaternion Julia sets.
    Supports both 3D slicing and full 4D camera navigation.

    Rendering technique:
        - Distance estimation based on:
            Inigo Quilez (2001)
        - Adaptive normal estimation (multiple methods)
        - Sphere tracing for implicit surface intersection
        - Optional supersampling and shadow approximation
        - Phong illumination model

    Features:
        - Squared and cubic Julia variants
        - 3D and 4D camera modes
        - Distance-based background rendering
        - Configurable iteration depth and precision

    Notes:
        - Designed for WebGL (GLSL ES 1.00)
        - Loop bounds are fixed for compatibility with WebGL compilers
        - Numerical stability depends on iteration limits and epsilon settings

 --------------------------------------------------------------------------------- */

#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

// -------------------------------------------------------------------------
// Uniforms (as provided by the application)
// -------------------------------------------------------------------------

// --- Render / output
uniform vec2 viewportDimensions;    // canvas size in pixels
uniform int SuperSampling;          // samples per pixel (<= MaxSuperSampling)
uniform bool renderShadows;         // shadow toggle
uniform int BGType;                 // background mode


// --- Fractal parameters
uniform vec4 mu;                    // quaternion constant c
uniform int fractalType;            // 0: squared, 1: cubic
uniform bool QuadCQuad;             // toggle CQuad vs Quads
uniform float rOW;                  // 4th component override (3D camera mode)

// --- Iteration / quality
uniform int MaxInterInter;          // max iteration depth of Julia series
uniform int MaxIterNorm;            // max iterations for normal estimation
uniform int MaxIterJulia;           // max steps for sphere tracing / marching

// --- Shading
uniform vec3 PhongDiffuse;          // base surface color
uniform vec3 light;                 // directional light (world space)
uniform int normalType;             // normal estimation mode

// --- 3D camera
uniform vec3 lookfrom;              // 3D camera position
uniform vec3 lookat;                // 3D camera lookat
uniform vec3  vup;                  // 3D camera up vector
uniform float vfov;                 // camera field of view
uniform float aspect_ratio;         // aspect ratio of image



// --- 4D camera
uniform vec4 Ulimbo;                // 4D camera limbo vector
uniform vec4 Ulookat4;              // 4D camera look at
uniform vec4 Ulookfrom4;            // 4D camera position
uniform vec4 Uvup4;                 // 4D camera up vector
uniform bool U4D;                   // toggle to use 4D camera


// --- Cutting plane
uniform bool CuttingPlane;          // toggle to compute cutting plane
uniform float CuttingPlaneZ;        // position of cutting plane on z-axis



// -------------------------------------------------------------------------
// Constants
// -------------------------------------------------------------------------

const int MaxSuperSampling = 10;    // fixed upper bound for super sampling
const int MAXITERATIONS = 1024;     // fixed upper bound for WebGL loop unrolling
const float epsilon = 0.0001;       // threshold for isosurface

const float RADIUS = 3.0;           // radius of boundingsphere
const float JULIA_ESC = 4.0;        // escape threshold of fractale
const float MIN = 1e-4;             // min for finite differences



// -----------------------------------------------------------------------------
// Quaternion multiplication
// -----------------------------------------------------------------------------
vec4 multQuat( vec4 q1, vec4 q2 )
{
    vec4 r;
    if(QuadCQuad){
        // Standard Quaternion - Implementation according to Crane (2005)
        r.x = q1.x*q2.x - dot( q1.yzw, q2.yzw );
        r.yzw = q1.x*q2.yzw + q2.x*q1.yzw + cross( q1.yzw, q2.yzw );
    }else{
        // Alternative algebra variant (C-Quaternion formulation)
        r.x = q1.x * q2.x - q1.y * q2.y + q1.z * q2.z + q1.w * q2.w;
        r.y = q1.y * q2.x + q1.x * q2.y + q1.w * q2.z + q1.z * q2.w;
        r.z = q1.z * q2.x + q1.x * q2.z - q1.w * q2.y - q1.y * q2.w;
        r.w = q1.w * q2.x + q1.x * q2.w - q1.z * q2.y - q1.y * q2.z;

    }
    return r;
}

// -----------------------------------------------------------------------------
// Computes q^2 using optimized identity
// Avoids full multiplication for efficiency.
// -----------------------------------------------------------------------------
vec4 squarQuat( vec4 q )
{
    vec4 r;
    if(QuadCQuad){
        // Standard Quaternion - Implementation according to and optimized after Crane (2005)
        r.x = q.x*q.x - dot( q.yzw, q.yzw );
        r.yzw = 2.0* q.x*q.yzw;
    }else{
        // Alternative algebra variant (C-Quaternion formulation)
        r.x = q.x*q.x - q.y*q.y + q.z*q.z +q.w*q.w;
        r.y = 2.0 * q.x*q.y + 2.0 * q.w*q.z;
        r.z = 2.0 * q.x*q.z - 2.0 * q.w*q.y;
        r.w = 2.0 * q.x*q.w - 2.0 * q.y*q.z;

    }
    return r;
}

// -----------------------------------------------------------------------------
// Computes q^3 using optimized formulation by Inigo Quilez (2001).
// Avoids repeated multiplications.
// -----------------------------------------------------------------------------
vec4 cubeQuat( vec4 a )
{
    // Standard Quaternion
    vec4 res = a*( 4.0*a.x*a.x - dot(a,a)*vec4(3.0,1.0,1.0,1.0) );
    return res;
}

// -----------------------------------------------------------------------------
// Squared quaternion magnitude |q|^2
// -----------------------------------------------------------------------------
float qlength2( vec4 q )
{
    return dot(q,q);
}


// -----------------------------------------------------------------------------
// Iterates squared Julia series for a given point q and a constant mu
// Also accumulates derivative for distance estimation.
// -----------------------------------------------------------------------------
void iterateJuliaSq( inout vec4 q, inout vec4 qp, vec4 mu)
{
    // Iterates a point and checks if it escapes, parallel computes derivative for distance function
    for( int i = 0; i < MAXITERATIONS ; i++ )
    {
        if(i > MaxInterInter){
            break;
        }

        // derivative
        qp = 2.0 * multQuat(q, qp);

        // series iteration
        q = squarQuat(q) + mu;

        // Escape condition
        if( dot( q, q ) > JULIA_ESC ) {
            break;
        }
    }
}

// -----------------------------------------------------------------------------
// Iterates cubic Julia series for a given point q and a constant mu
// Also accumulates derivative for distance estimation.
// -----------------------------------------------------------------------------
void iterateJuliaCub( inout vec4 q, inout float qp, vec4 mu)
{
    // Iterates a point and checks if it escapes, parallel computes derivative for distance function
    for( int i = 0; i < MAXITERATIONS ; i++ )
    {
        if(i > MaxInterInter){
            break;
        }

        // derivative, according to Quilez (2001)
        qp = qp * 9.0*qlength2(squarQuat(q));

        // series iteration
        q = cubeQuat(q) + mu;

        // Escape condition
        if( dot( q, q ) > JULIA_ESC ) {
            break;
        }
    }
}


// -----------------------------------------------------------------------------
// Distance estimator (lower bound) for 3D slice of quaternion Julia set.
// Embeds 3D point into 4D via fixed slice coordinate rOW.
// -----------------------------------------------------------------------------
float getDistance(vec3 rO, vec4 mu){

    // transform 3D Location to Quaternion (equal to Slice at rOW)
    vec4 z = vec4(rO, rOW);

    float distance = 99.0;

    if(fractalType == 1){
        // ---------------------------------------------------------
        // Cubic Julia
        // Distance estimate after Quilez (2001)
        // ---------------------------------------------------------

        // initiate derivative
        float zp = 1.0;

        // iterate this point until we can guess if the sequence diverges or converges.
        iterateJuliaCub(z,zp,mu);

        // compute distance
        float normZ = dot(z,z);
        // distance according to Quilez (2001)
        distance = 0.25 * log(normZ) * sqrt(normZ/zp );

    }else{
        // ---------------------------------------------------------
        // Squared Julia
        // ---------------------------------------------------------

        // initiate derivative with real part of Quat = 1
        vec4 zp = vec4(1, 0, 0, 0);

        // iterate this point until we can guess if the sequence diverges or converges.
        iterateJuliaSq(z, zp, mu);

        // compute distance
        float normZ = length( z );
        // lower bound on distance to surface
        distance = 0.5 * normZ * log(normZ) / length(zp);

    }

    return distance;
}


// -----------------------------------------------------------------------------
// Distance estimator (lower bound) of a given point (4D) to a quaternion Julia set.
// -----------------------------------------------------------------------------
float getDistance4(vec4 rO, vec4 mu){

    vec4 z = rO;

    float distance = 99.0;

    if(fractalType == 1){
        // ---------------------------------------------------------
        // Cubic Julia
        // Distance estimate after Quilez (2001)
        // ---------------------------------------------------------

        // initiate derivative
        float zp = 1.0;
        // iterate this point until we can guess if the sequence diverges or converges.
        iterateJuliaCub(z,zp,mu);

        // compute distance
        float normZ = dot(z,z);
        // distance according to Quilez (2001)
        distance = 0.25 * log(normZ) * sqrt(normZ/zp );

    }else{
        // ---------------------------------------------------------
        // Squared Julia
        // ---------------------------------------------------------

        // initiate derivative with real part of Quat = 1
        vec4 zp = vec4(1, 0, 0, 0);

        // iterate this point until we can guess if the sequence diverges or converges.
        iterateJuliaSq( z, zp, mu);

        // compute distance
        float normZ = length( z );
        // lower bound on distance to surface
        distance = 0.5 * normZ * log(normZ) / length(zp);

    }

    return distance;
}


// -----------------------------------------------------------------------------
// Normal estimation for 3D camera mode
// Several techniques are provided (select via `version`):
//
// 0: Implementation according to Crane (2005), robust but slower
// 1: Implementation according to Quilez (2001)
// 2: Implementation according to da Silva et al. (2021)
// -----------------------------------------------------------------------------
vec3 estimateNorm(int version, vec3 p, vec4 c ){
    vec3 res;

    if (version == 0)
    {
        // -------------------------------------------------------------------------
        // Implementation according to Crane (2005)
        // -------------------------------------------------------------------------
        vec3 N;
        vec4 qP = vec4( p, 0 );
        float gradX, gradY, gradZ;
        vec4 gx1 = qP - vec4( MIN, 0, 0, 0 );
        vec4 gx2 = qP + vec4( MIN, 0, 0, 0 );
        vec4 gy1 = qP - vec4( 0, MIN, 0, 0 );
        vec4 gy2 = qP + vec4( 0, MIN, 0, 0 );
        vec4 gz1 = qP - vec4( 0, 0, MIN, 0 );
        vec4 gz2 = qP + vec4( 0, 0, MIN, 0 );

        vec4 qq = vec4(1.0,0,0,0);


        for(int i=0; i<MAXITERATIONS; i++)
        {
            if(i > MaxIterNorm){
                break;
            }
            if(fractalType == 0){
                gx1 = squarQuat( gx1 ) + c;
                gx2 = squarQuat( gx2 ) + c;
                gy1 = squarQuat( gy1 ) + c;
                gy2 = squarQuat( gy2 ) + c;
                gz1 = squarQuat( gz1 ) + c;
                gz2 = squarQuat( gz2 ) + c;
            }
            if(fractalType == 1){
                gx1 = cubeQuat( gx1 ) + c;
                gx2 = cubeQuat( gx2 ) + c;
                gy1 = cubeQuat( gy1 ) + c;
                gy2 = cubeQuat( gy2 ) + c;
                gz1 = cubeQuat( gz1 ) + c;
                gz2 = cubeQuat( gz2 ) + c;
            }

        }
        gradX = length(gx2) - length(gx1);
        gradY = length(gy2) - length(gy1);
        gradZ = length(gz2) - length(gz1);
        N = normalize(vec3( gradX, gradY, gradZ ));
        res =  N;
    }
    if (version == 1)
    {
        // -------------------------------------------------------------------------
        // Implementation according to Quilez (2001)
        // -------------------------------------------------------------------------
        vec4 q = vec4(p,rOW);
        mat4 J = mat4(1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0);

        for(int i=0; i<MAXITERATIONS; i++)
        {
            if(i > MaxIterNorm){
                break;
            }

            J = J*mat4(q.x, -q.y, -q.z, -q.w,
            q.y,  q.x,  0.0,  0.0,
            q.z,  0.0,  q.x,  0.0,
            q.w,  0.0,  0.0,  q.x);
            q = squarQuat(q) + c;
            if(qlength2(q)>4.0) break;

        }
        res = normalize( (J*q).xyz );
    };
    if (version == 2)
    {
        // -------------------------------------------------------------------------
        // Implementation according to da Silva et al. (2021)
        // -------------------------------------------------------------------------
        float prec = 0.01;
        vec2 v = vec2(prec*MIN,-1.0*MIN*prec);
        vec3 v1 = p + v.xyy;
        vec3 v2 = p + v.yyx;
        vec3 v3 = p + v.yxy;
        vec3 v4 = p + v.xxx;

        res = normalize(v.xyy * getDistance(v1,c) + v.yyx* getDistance(v2,c) + v.yxy* getDistance(v3,c) + v.xxx * getDistance(v4,c) );
    };
    return res;
}

// -----------------------------------------------------------------------------
// Normal estimation for 4D camera mode
//
// Implementation according to Quilez (2001), adapted to 4D
// Only works for squared Julia sets
// -----------------------------------------------------------------------------
vec4 estimateNorm4(int version, vec4 p, vec4 c ){
    vec4 res;

    vec4 q = p;
    mat4 J = mat4(1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0);

    for(int i=0; i<MAXITERATIONS; i++)
    {
        if(i > MaxIterNorm){
            break;
        }

        if(fractalType == 0){
            J = J*mat4(q.x, -q.y, -q.z, -q.w,
            q.y,  q.x,  0.0,  0.0,
            q.z,  0.0,  q.x,  0.0,
            q.w,  0.0,  0.0,  q.x);
            q = squarQuat(q) + c;
            if(qlength2(q)>4.0) break;
        }

    }
    res=normalize( (J*q) );

    return res;
}


// -----------------------------------------------------------------------------
// Sphere tracing for quaternion Julia set (3D slice).
// rO : ray origin (modified in place)
// rD : normalized ray direction
// mu : Julia constant
// epsilon : surface hit threshold
//
// Returns last distance estimate.
// -----------------------------------------------------------------------------
float SphereTraceJulia( inout vec3 rO, inout vec3 rD, vec4 mu, float epsilon )
{
    // Distance to closest point in Julia set or last Point tested
    float distance;

    for( int i = 0; i < MAXITERATIONS ; i++ )
    {
        if (i > MaxIterJulia){
            break;
        }

        // Evaluate distance estimator
        distance = getDistance(rO, mu);

        // Move ray for distance
        rO += rD * distance;

        // If ray is close enough or ray left bounding sphere: break loop.
        if (distance < epsilon)
        {
            break;
        }
        if (dot(rO, rO) > RADIUS )
        {
            break;
        }
    }
    // Return the distance for this ray
    return distance;
}

// -----------------------------------------------------------------------------
// Sphere tracing for quaternion Julia set (4D).
// rO : ray origin (modified in place)
// rD : normalized ray direction
// mu : Julia constant
// epsilon : surface hit threshold
//
// Returns last distance estimate.
// -----------------------------------------------------------------------------
float SphereTraceJulia4( inout vec4 rO, inout vec4 rD, vec4 mu, float epsilon )
{
    // Distance to closest point in Julia set or last Point tested
    float distance;

    for( int i = 0; i < MAXITERATIONS ; i++ )
    {
        if (i > MaxIterJulia){
            break;
        }
        // Evaluate distance estimator
        distance = getDistance4(rO, mu);

        // Move ray for distance
        rO += rD * distance;

        // If ray is close enough or ray left bounding sphere: break loop.
        if (distance < epsilon)
        {
            break;
        }
        if (dot(rO, rO) > RADIUS )
        {
            break;
        }
    }

    // Return the distance for this ray
    return distance;
}



// -----------------------------------------------------------------------------
// 4D Phong shading.
// Same principle as 3D version, but using 4D light and normal vectors.
// Final color still mapped to RGB space.
// -----------------------------------------------------------------------------
vec3 Phong4( vec4 light, vec4 eye, vec4 pt, vec4 N )
{
    // -------------------------------------------------------------------------
    // Diffuse term
    // Multiplied by 2.5 as artistic intensity boost.
    // Lower bound of 0.6 prevents fully dark surfaces.
    // -------------------------------------------------------------------------
    vec3 diffuse = max(0.6, dot(normalize(light), N)*2.5)* PhongDiffuse;

    // Slight normal-based coloring for additional surface variation
    diffuse += abs( N.xyz )*0.3; // some additional coloring

    // -------------------------------------------------------------------------
    // Specular term
    // High exponent (50.0) creates sharp highlights.
    // -------------------------------------------------------------------------
    vec4 reflectVec = normalize(reflect(-normalize(light), N));
    float specularFac = pow(max(0.0, dot(normalize(eye), reflectVec)), 50.0);
    vec3 specular = specularFac * vec3(1.0);

    // -------------------------------------------------------------------------
    // Ambient term
    // Currently scaled to zero in final mix but kept for flexibility.
    // -------------------------------------------------------------------------
    vec3 ambient = vec3(0.1);

    // Final weighted combination
    vec3 color = (ambient * 0.0 + diffuse * 1.0 + specular * 0.45) * 0.75;

    return color;
}

// -----------------------------------------------------------------------------
// Classic Phong shading model (directional light).
// Computes diffuse + specular lighting for a surface point.
//
// light : directional light vector (world space)
// eye   : view direction
// pt    : surface point (currently unused, kept for extensibility)
// N     : surface normal (must be normalized)
// -----------------------------------------------------------------------------
vec3 Phong( vec3 light, vec3 eye, vec3 pt, vec3 N )
{

    // -------------------------------------------------------------------------
    // Diffuse term
    // Multiplied by 2.5 as artistic intensity boost.
    // Lower bound of 0.6 prevents fully dark surfaces.
    // -------------------------------------------------------------------------
    vec3 diffuse = max(0.6, dot(normalize(light), N)*2.5)* PhongDiffuse;

    // Slight normal-based coloring for additional surface variation
    diffuse += abs( N.xyz )*0.3; // some additional coloring

    // -------------------------------------------------------------------------
    // Specular term
    // High exponent (50.0) creates sharp highlights.
    // -------------------------------------------------------------------------
    vec3 reflectVec = normalize(reflect(-normalize(light), N));
    float specularFac = pow(max(0.0, dot(normalize(eye), reflectVec)), 50.0);
    vec3 specular = specularFac * vec3(1.0);

    // -------------------------------------------------------------------------
    // Ambient term
    // Currently scaled to zero in final mix but kept for flexibility.
    // -------------------------------------------------------------------------
    vec3 ambient = vec3(0.1);

    // Final weighted combination
    vec3 color = (ambient * 0.0 + diffuse * 1.0 + specular * 0.45) * 0.75;

    return color;
}

// -----------------------------------------------------------------------------
// Ray–sphere intersection (3D)
// Returns the nearest positive t along the ray: r(t) = rO + t * rD.
// Returns -9999.0 if there is no intersection in front of the ray origin.
//
// Assumes rD is normalized.
// -----------------------------------------------------------------------------
float intersectSphere( vec3 rO, vec3 rD )
{
    vec3 sC = vec3(0.0,0.0,0.0);
    float sRad = 2.0;
    float t = dot(sC-rO, rD);
    vec3 p = rO + rD*t;
    float y = length(sC-p);
    if(y<= sRad){
        float x = sqrt(sRad*sRad - y*y);
        float t1 = t-x;
        float t2 = t+x;
        return min( t1, t2 );
    }else{
        return -9999.0;
    }
}

// -----------------------------------------------------------------------------
// Ray–sphere intersection (4D)
// Returns the nearest positive t along the ray: r(t) = rO + t * rD.
// Returns -9999.0 if there is no intersection in front of the ray origin.
//
// Assumes rD is normalized.
// -----------------------------------------------------------------------------
float intersectSphere4( vec4 rO, vec4 rD )
{
    vec4 sC = vec4(0.0,0.0,0.0,0.0);
    float sRad = RADIUS;
    float t = dot(sC-rO, rD);
    vec4 p = rO + rD*t;
    float y = length(sC-p);
    if(y<= sRad){
        float x = sqrt(sRad*sRad - y*y);
        float t1 = t-x;
        float t2 = t+x;
        return min( t1, t2 );
    }else{
        return -9999.0;
    }
}

// -----------------------------------------------------------------------------
// Ray–plane intersection
// -----------------------------------------------------------------------------
float intersectPlane( vec3 rO, vec3 rD )
{
    vec3 n = vec3(0.0,0.0,1.0);
    vec3 d = vec3(0.0,0.0,CuttingPlaneZ);
    float de = dot(n, rD);
    float t = dot((d - rO), n) / de;
    return t;
}

// -----------------------------------------------------------------------------
// 4D "cross product" (Odegaard and Wennergren, 2007).
// Returns a vector orthogonal to the three input vectors a, b, c.
// Used for constructing a 4D basis.
// -----------------------------------------------------------------------------
vec4 cross4D(vec4 a, vec4 b, vec4 c){

    float res1 = a.y*(b.w*c.z - b.z*c.w) + b.y*(a.z*c.w - a.w*c.z) + c.y*(a.w*b.z - a.z*b.w);

    vec4 res = vec4(
        a.y*(b.w*c.z - b.z*c.w) + b.y*(a.z*c.w - a.w*c.z) + c.y*(a.w*b.z - a.z*b.w),
        a.x*(b.z*c.w - b.w*c.z) + b.x*(a.w*c.z - a.z*c.w) + c.x*(a.z*b.w - a.w*b.z),
        a.x*(b.w*c.y - b.y*c.w) + b.x*(a.y*c.w - a.w*c.y) + c.x*(a.w*b.y - a.y*b.w),
        a.x*(b.y*c.z - b.z*c.y) + b.x*(a.z*c.y - a.y*c.z) + c.x*(a.y*b.z - a.z*b.y)
    );
    return res;

}


// -----------------------------------------------------------------------------
// Main Function
// -----------------------------------------------------------------------------
void main()
{

    // -------------------------------------------------------------------------
    // Compute background color
    // -------------------------------------------------------------------------
    vec4 backgroundColor;

    // Radial gradient background
    if(BGType == 0){
        vec2 backdif = (gl_FragCoord.xy - (viewportDimensions / 2.0) )/viewportDimensions;
        float bdl = length(backdif);
        bdl = bdl + 0.3;
        backgroundColor = vec4( 1.-bdl, 1.-bdl, 1.-bdl, 1 );
    }

    // White background
    if(BGType == 1){
        backgroundColor = vec4( 1.0,1.0,1.0, 1.0 );
    }

    // Black background
    if(BGType == 2){
        backgroundColor = vec4( 0,0,0, 1.0 );
    }

    // Distance function (start with black)
    if(BGType == 3){
        backgroundColor = vec4( 0,0,0, 1.0 );
    }



    // -------------------------------------------------------------------------
    // Compute camera ray
    // -------------------------------------------------------------------------
    float theta = radians(vfov);
    float h = tan(theta/2.0);
    float viewport_height = 2.0 * h;
    float viewport_width = aspect_ratio * viewport_height;


    // -------------------------------------------------------------------------
    // Control flow -> Use 4D Camera
    // -------------------------------------------------------------------------
    if(U4D){

        vec4 limbo = Ulimbo;
        vec4 lookat4 = Ulookat4;
        vec4 lookfrom4 = Ulookfrom4;
        vec4 vup4 = Uvup4;


        vec4 w4 = normalize(lookfrom4 - lookat4);
        vec4 u4 = normalize(cross4D(vup4,w4,limbo));
        vec4 v4 = normalize(cross4D(u4,w4,limbo));

        vec4 horizontal4 = viewport_width * u4;
        vec4 vertical4 = viewport_height * v4;
        vec4 lower_left_corner4 = lookfrom4 - horizontal4/2.0 - vertical4/2.0 - w4;


        vec3 colFrac = vec3(0.0,0.0,0.0);

        // -------------------------------------------------------------------------
        // Supersampling
        // -------------------------------------------------------------------------
        for( int i=0; i<MaxSuperSampling; i++ ){
            if(i >= SuperSampling){
                break;
            }
            for( int j=0; j<MaxSuperSampling; j++ ){
                if (j >= SuperSampling){
                    break;
                }

                float s = (gl_FragCoord.x + (float(i)*1.0/float(SuperSampling))) / viewportDimensions[0];
                float t = (gl_FragCoord.y+ (float(j)*1.0/float(SuperSampling))) / viewportDimensions[1];

                // ray direction
                vec4 rD4 = lower_left_corner4 + s*horizontal4 + t*vertical4 - lookfrom4;
                rD4 = normalize(rD4);

                vec4 rO4 = lookfrom4;

                // check for intersection with bounding sphere
                float tt4 = intersectSphere4(rO4, rD4);

                rO4 += tt4* rD4;

                float dist = 0.0;

                // Not part of the background
                if (tt4 != -9999.0){

                    // -------------------------------------------------------------------------
                    // Search for intersection with julia set
                    // -------------------------------------------------------------------------

                    if (dist == 0.0){
                        dist = SphereTraceJulia4(rO4, rD4, mu, epsilon);
                    }
                    // If distance smaller threshold: it intersects Julia at rO -> color pixel.
                    if (dist < epsilon)
                    {
                        vec4 N = estimateNorm4(normalType, rO4, mu);
                        colFrac += Phong4(lookfrom4, lookfrom4, rO4, N);

                    } else {
                        // not part of Julia set -> background color
                        colFrac += backgroundColor.xyz;
                    }

                }else{
                    // not part of Julia set -> background color
                    colFrac += backgroundColor.xyz;
                }
            }
        }

        // average supersampling color
        colFrac /= float(SuperSampling*SuperSampling);
        gl_FragColor = vec4(colFrac,1.0);

    }else{
        // -------------------------------------------------------------------------
        // Control flow -> Use 3D Camera
        // -------------------------------------------------------------------------

        vec3 w = normalize(lookfrom - lookat);
        vec3 u = normalize(cross(vup, w));
        vec3 v = cross(w, u);
        vec3 horizontal = viewport_width * u;
        vec3 vertical = viewport_height * v;
        vec3 lower_left_corner = lookfrom - horizontal/2.0 - vertical/2.0 - w;

        // store Fraction of Color
        vec3 colFrac = vec3(0.0,0.0,0.0);

        // -------------------------------------------------------------------------
        // Supersampling
        // -------------------------------------------------------------------------
        for( int i=0; i<MaxSuperSampling; i++ ){
            if(i >= SuperSampling){
                break;
            }
            for( int j=0; j<MaxSuperSampling; j++ ){
                if (j >= SuperSampling){
                    break;
                }

                float s = (gl_FragCoord.x + (float(i)*1.0/float(SuperSampling))) / viewportDimensions[0];
                float t = (gl_FragCoord.y+ (float(j)*1.0/float(SuperSampling))) / viewportDimensions[1];

                // ray direction
                vec3 rD = lower_left_corner + s*horizontal + t*vertical - lookfrom;
                rD = normalize(rD);

                vec3 rO = lookfrom;


                // check for intersection with bounding sphere
                float tt = intersectSphere(rO, rD);//

                rO += tt* rD;

                float dist;


                // Not part of the background
                if (tt != -9999.0){
                    // ray above plane?
                    if(CuttingPlane){
                        if (rO.z >= CuttingPlaneZ){
                            float t  = intersectPlane(rO, rD);
                            vec3 tmp = rO+ t * rD;
                            if (tmp.x*tmp.x + tmp.y*tmp.y + tmp.z*tmp.z <= 4.0){
                                rO = rO + rD * t;
                            } else {
                                dist = 100.0;
                            }
                        }
                    }

                    // -------------------------------------------------------------------------
                    // Search for intersection with julia set
                    // -------------------------------------------------------------------------
                    if (dist != 100.0){
                        dist = SphereTraceJulia(rO, rD, mu, epsilon);
                    }

                    // If distance smaller threshold: it intersects Julia at rO -> color pixel.
                    if (dist < epsilon)
                    {
                        vec3 N = estimateNorm(normalType, rO, mu);

                        colFrac += Phong(light, lookfrom, rO, N);
                        if (renderShadows == true)
                        {
                            // simple shading
                            vec3 diff = normalize(light - rO);
                            rO += N*epsilon*2.0;
                            dist = SphereTraceJulia(rO, diff, mu, epsilon);
                            if (dist < epsilon){
                                colFrac.rgb *= 0.6;
                            }
                        }
                    } else {
                        if(BGType == 3){
                            // color regarding distance function
                            colFrac += vec3(dist);
                        }else{
                            // background color
                            colFrac += backgroundColor.xyz;
                        }
                    }
                }else{
                    // not part of julia set -> background color
                    colFrac += backgroundColor.xyz;
                }
            }
        }

        // average supersampling color
        colFrac /= float(SuperSampling*SuperSampling);
        gl_FragColor = vec4(colFrac,1.0);
    }
}

