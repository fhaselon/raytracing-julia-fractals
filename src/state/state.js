export const State = {
    vpDimensions: [600, 600],
// constant quaternion c
    GLOB_mu: [-0.5, -0.5, -0.5, 0.0],

// bool: show shadow
    GLOBShadow: 0,

// camera aspect ratio
    GLOBCamAR: 1.0,

// camera field of view
    GLOBCamFOV: 90.0,

// camera position
    GLOBCamLookFr: [0.0, 3.0, 0.0],

// camera vector look at
    GLOBCamLookAt: [0.0, 0.0, 0.0],

// camera up vector
    GLOBCamLookUp: [0.0, 0.0, 1.0],

// light position (usually follows the camera position)
    GLOBLightPosition: [0.0, 3.0, 0.0],

// iteration depth of julia series
    GLOBMaxInterInter: 50,

// iteration depth of norm computation
    GLOBMaxIterNorm: 50,

// iteration depth of sphere tracing steps
    GLOBMaxIterJulia: 50,

// bool: use CQuats
    GLOBQuadCQuad: 1,

// amount of supersampling per pixel
    GLOBSuperSampling: 1,

// type of norm computation
    GLOBNormalType: 1,

// bool: compute cut
    GLOBCut: 0,

// position of cutting plane
    GLOBCutZ: 0.01,

// type of background coloring
    GLOBBGColor: 0,

// color of fractal
    GLOBFractColor: [0.25, 0.25, 0.45],

// type of fractal to compute (squared vs cubic)
    GLOBFractalType: 0,

// value for 4th component of quaternion c
    GLOBrOW: 0.0,

// 4D camera parameters
    GLOB4d: {
        limbo: [0, 0, 1, 0],
        lookat: [0.0, 0.0, 0.0, 0.0],
        lookfrom: [0.0, 3.0, 0.0, 0.0],
        vup: [0.0, 0.0, 1.0, 0.0]
    },

// bool: use 4D camera
    GLOBuse4D: 0,


// bool: run openGL loop
    GLOBRunGLLoop: true,

// bool: compute high resolution image
    GLOBHighResFlag: 0,

// cache for canvas size
    BackupvpDimensions: [300, 300],

// some presets for constant quaternion c
    PresetsMU: {
        0: [-0.5, -0.5, -0.5, 0.0],
        1: [0.2, 0.8, 0, 0],
        2: [-0.125, -0.256, 0.847, 0.0895],
        3: [-1, 0.2, 0, 0],
    },

    _frameDtMs: "none",      // frame to frame time
    _cpuFrameMs: "none",         // CPU time spent in JS this frame
    _fps: "none",
}





