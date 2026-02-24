import {loadText, createProgram} from "./shaders.js";


export async function createRenderer(canvas, State) {

    const gl = canvas.getContext('webgl');
    if (!gl) {
        alert('Cannot get WebGL context - browser does not support WebGL');
        return;
    }

    //  Load shader sources
    const vsSource = await loadText("src/shaders/julia.vs.glsl");
    const fsSource = await loadText("src/shaders/julia.fs.glsl");

    const program = createProgram(gl, vsSource, fsSource);
    gl.useProgram(program);


    // Uniform locations
    const uniforms = {
        viewportDimensions: gl.getUniformLocation(program, 'viewportDimensions'),

        mu: gl.getUniformLocation(program, 'mu'),
        shadow: gl.getUniformLocation(program, 'renderShadows'),
        camera: {
            aspectRatio: gl.getUniformLocation(program, 'aspect_ratio'),
            fov: gl.getUniformLocation(program, 'vfov'),
            from: gl.getUniformLocation(program, 'lookfrom'),
            at: gl.getUniformLocation(program, 'lookat'),
            up: gl.getUniformLocation(program, 'vup'),
        },
        iterations: {
            inter: gl.getUniformLocation(program, 'MaxInterInter'),
            norm: gl.getUniformLocation(program, 'MaxIterNorm'),
            julia: gl.getUniformLocation(program, 'MaxIterJulia'),
        },
        QuadCQuad: gl.getUniformLocation(program, 'QuadCQuad'),
        SuperSampling: gl.getUniformLocation(program, 'SuperSampling'),
        Light: gl.getUniformLocation(program, "light"),
        NormalType: gl.getUniformLocation(program, "normalType"),
        FractaleType: gl.getUniformLocation(program, "fractalType"),
        CutBool: gl.getUniformLocation(program, "CuttingPlane"),
        CutZVal: gl.getUniformLocation(program, "CuttingPlaneZ"),
        BGColor: gl.getUniformLocation(program, "BGType"),
        FRColor: gl.getUniformLocation(program, "PhongDiffuse"),
        Cam4D: {
            limbo: gl.getUniformLocation(program, "Ulimbo"),
            lookat: gl.getUniformLocation(program, "Ulookat4"),
            lookfrom: gl.getUniformLocation(program, "Ulookfrom4"),
            vup: gl.getUniformLocation(program, "Uvup4"),
            use4D: gl.getUniformLocation(program, "U4D"),

        },
        rOW: gl.getUniformLocation(program, "rOW"),
    };


    // Create buffers
    const vertexBuffer = gl.createBuffer();
    const vertices = [-1, 1, -1, -1, 1, -1,

        -1, 1, 1, 1, 1, -1];
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW);


    const vPosAttrib = gl.getAttribLocation(program, 'aPos');
    gl.vertexAttribPointer(vPosAttrib, 2, gl.FLOAT, false, 2 * Float32Array.BYTES_PER_ELEMENT, 0);
    gl.enableVertexAttribArray(vPosAttrib);


    function updateUniforms() {

        // --- viewport ---
        gl.uniform2f(uniforms.viewportDimensions, State.vpDimensions[0], State.vpDimensions[1]);

        // --- fractal constant ---
        gl.uniform4fv(uniforms.mu, State.GLOB_mu);

        // --- camera ---
        gl.uniform1f(uniforms.camera.aspectRatio, State.GLOBCamAR);
        gl.uniform1f(uniforms.camera.fov, State.GLOBCamFOV);

        gl.uniform3fv(uniforms.camera.from, State.GLOBCamLookFr);
        gl.uniform3fv(uniforms.camera.at, State.GLOBCamLookAt);
        gl.uniform3fv(uniforms.camera.up, State.GLOBCamLookUp);


        if (State.GLOBHighResFlag == 0) {
            // --- iterations ---
            gl.uniform1i(uniforms.iterations.inter, 5);
            gl.uniform1i(uniforms.iterations.norm, 5);
            gl.uniform1i(uniforms.iterations.julia, 150);
            // --- supersampling ---
            gl.uniform1i(uniforms.SuperSampling, 1);


        } else {
            // --- iterations ---
            gl.uniform1i(uniforms.iterations.inter, State.GLOBMaxInterInter);
            gl.uniform1i(uniforms.iterations.norm, State.GLOBMaxIterNorm);
            gl.uniform1i(uniforms.iterations.julia, State.GLOBMaxIterJulia);
            // --- supersampling ---
            gl.uniform1i(uniforms.SuperSampling, State.GLOBSuperSampling);
        }


        // --- fractal behavior ---
        gl.uniform1i(uniforms.QuadCQuad, State.GLOBQuadCQuad);
        gl.uniform1i(uniforms.FractaleType, State.GLOBFractalType);
        gl.uniform1f(uniforms.rOW, State.GLOBrOW);

        // --- shading ---
        gl.uniform3fv(uniforms.FRColor, State.GLOBFractColor);
        gl.uniform3fv(uniforms.Light, State.GLOBLightPosition);
        gl.uniform1i(uniforms.shadow, State.GLOBShadow);
        gl.uniform1i(uniforms.NormalType, State.GLOBNormalType);

        // --- background ---
        gl.uniform1i(uniforms.BGColor, State.GLOBBGColor);

        // --- cutting ---
        gl.uniform1i(uniforms.CutBool, State.GLOBCut);
        gl.uniform1f(uniforms.CutZVal, State.GLOBCutZ);


        // --- 4D camera disabled ---
        gl.uniform1i(uniforms.Cam4D.use4D, State.GLOBuse4D);

        gl.uniform4fv(uniforms.Cam4D.limbo, State.GLOB4d.limbo);
        gl.uniform4fv(uniforms.Cam4D.lookat, State.GLOB4d.lookat);
        gl.uniform4fv(uniforms.Cam4D.lookfrom, State.GLOB4d.lookfrom);
        gl.uniform4fv(uniforms.Cam4D.vup, State.GLOB4d.vup);


    }


    function resize() {
        canvas.width = State.vpDimensions[0];
        canvas.height = State.vpDimensions[1];
        gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    }

    function draw() {
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT);

        // update uniforms
        updateUniforms();


        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 6);
    }

    function init() {
        resize();
        window.addEventListener("resize", resize);
    }

    return {
        gl, init, draw, resize
    };
}