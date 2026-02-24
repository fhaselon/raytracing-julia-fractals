export function updateInfoPanel(State) {
    document.getElementById("infoFps").innerHTML = Math.round(State._fps);
    document.getElementById("infoTime").innerHTML = Math.round(State._frameDtMs);
    document.getElementById("infoTimeCPU").innerHTML = Math.round(State._cpuFrameMs);

    const mu = State.GLOB_mu
        .map(v => v.toFixed(2))
        .join(", ");

    document.getElementById("infoMu").textContent = `μ = (${mu})`;
    document.getElementById("infoSuperSam").innerHTML = Math.round(State.GLOBSuperSampling);
    document.getElementById("infoMaxInterInter").innerHTML = Math.round(State.GLOBMaxInterInter);
    document.getElementById("infoIterNorm").innerHTML = Math.round(State.GLOBMaxIterNorm);
    document.getElementById("infoIterJulia").innerHTML = Math.round(State.GLOBMaxIterJulia);


}


