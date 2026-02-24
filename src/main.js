import {createRenderer} from "./renderer/renderer.js";
import {attachMouseController} from "./camera/mouseController.js";
import {bindUI} from "./ui/ui.js";
import {updateInfoPanel} from "./ui/overlay.js";
import {State} from "./state/state.js";


const canvas = document.getElementById("gl-surface");

function perFrameUI(State) {
    const $ = (id) => document.getElementById(id);

    // animation of mu
    if ($("ShowAnimation")?.checked) {
        if ($("ani_ch_r")?.checked) State.GLOB_mu[0] += 0.001;
        if ($("ani_ch_i")?.checked) State.GLOB_mu[1] += 0.001;
        if ($("ani_ch_j")?.checked) State.GLOB_mu[2] += 0.001;
        if ($("ani_ch_k")?.checked) State.GLOB_mu[3] += 0.001;
    }

    // light follows camera
    if ($("LightFolCam")?.checked) {
        State.GLOBLightPosition = State.GLOBCamLookFr;
    }

}


async function start() {
    const renderer = await createRenderer(canvas, State);
    renderer.init();
    attachMouseController(State);
    bindUI({State, renderer, canvas})


    let lastFrameTs = 0;

    function loop(ts) {

        if (State.GLOBRunGLLoop) {


            // ts is the high-precision timestamp from requestAnimationFrame
            const frameDt = lastFrameTs ? (ts - lastFrameTs) : 0;
            lastFrameTs = ts;

            const t0 = performance.now();

            perFrameUI(State);
            renderer.draw();
            const cpuMs = performance.now() - t0;

            // store values for overlay
            State._frameDtMs = frameDt;        // frame-to-frame time
            State._cpuFrameMs = cpuMs;         // CPU time spent in JS this frame
            State._fps = frameDt ? (1000 / frameDt) : 0;


            requestAnimationFrame(loop);
            updateInfoPanel(State);
        }
    }

    loop();
}

start();