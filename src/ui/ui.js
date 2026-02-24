// src/ui/ui.js
// Wires HTML controls to State. Renderer reads State each frame.

export function bindUI({State, renderer, canvas}) {

    const $ = (id) => document.getElementById(id);

    const toF = (v) => parseFloat(v);
    const toI = (v) => parseInt(v, 10);

    function resizeFromUI() {

        const size = toI($("canvSizeRange").value);
        State.GLOBCamAR = toF($("canvAspectRange").value);
        State.GLOBCamFOV = toF($("CamFOV").value);
        State.vpDimensions = [Math.round(size * State.GLOBCamAR), size];
        renderer.resize()

    }

    function updateMuFromInputs() {
        State.GLOB_mu = [
            toF($("mu1").value),
            toF($("mu2").value),
            toF($("mu3").value),
            toF($("mu4").value),
        ];
    }

    function updateMuPreset() {
        const tmpID = $("MUPreSLSL").value;
        const newMU = State.PresetsMU[tmpID] || State.PresetsMU[0];
        $("mu1").value = newMU[0];
        $("mu2").value = newMU[1];
        $("mu3").value = newMU[2];
        $("mu4").value = newMU[3];
        updateMuFromInputs();
    }

    function updateIterationSettings() {
        State.GLOBMaxInterInter = toI($("InputIterInter").value);
        State.GLOBMaxIterNorm = toI($("InputIterNorm").value);
        State.GLOBMaxIterJulia = toI($("InputIterJulia").value);
        State.GLOBQuadCQuad = toI($("QautCquatSL").value);
    }

    function update4dCamFromInputs() {
        State.GLOB4d.limbo = [toF($("4dLIMX").value), toF($("4dLIMY").value), toF($("4dLIMZ").value), toF($("4dLIMW").value)];
        State.GLOB4d.lookfrom = [toF($("4dLFX").value), toF($("4dLFY").value), toF($("4dLFZ").value), toF($("4dLFW").value)];
        State.GLOB4d.lookat = [toF($("4dLAX").value), toF($("4dLAY").value), toF($("4dLAZ").value), toF($("4dLAW").value)];
        State.GLOB4d.vup = [toF($("4dUPX").value), toF($("4dUPY").value), toF($("4dUPZ").value), toF($("4dUPW").value)];
    }

    function downloadCanvasPNG() {
        const link = document.createElement("a");
        link.download = "render.png";
        link.href = canvas.toDataURL("image/png");
        link.click();
    }


    $("canvSizeRange")?.addEventListener("mouseup", () => {
        const size = toI($("canvSizeRange").value);
        State.vpDimensions = [Math.round(size * State.GLOBCamAR), size];
        renderer.resize();
    });

    $("BTNupdateCamSettings")?.addEventListener("click", () => {
        State.GLOBSuperSampling = toI($("SuperSamplingIP").value);
        resizeFromUI();
    });


    $("BTNCreateHR")?.addEventListener("click", () => {
        State.BackupvpDimensions = State.vpDimensions.slice();
        State.vpDimensions = [toI($("HRWidth").value), toI($("HRHeight").value)];
        if (renderer?.resize) renderer.resize(State.vpDimensions[0], State.vpDimensions[1]);
        else {
            canvas.width = State.vpDimensions[0];
            canvas.height = State.vpDimensions[1];
        }
        State.GLOBHighResFlag = 1;
    });


    $("BTNupdateSettings")?.addEventListener("click", updateMuFromInputs);
    $("MUPreSL")?.addEventListener("click", updateMuPreset);


    $("BTNupdateIterationSettings")?.addEventListener("click", updateIterationSettings);


    function setSlider(id, val) {
        const el = $(id);
        if (!el) return;
        el.value = val;
        if (typeof el.oninput === "function") el.oninput();
    }

    $("4dCamCB")?.addEventListener("click", () => {

        setSlider("4dLAX", 0.0);
        setSlider("4dLAY", 0.0);
        setSlider("4dLAZ", 0.0);
        setSlider("4dLAW", State.GLOBrOW);

        setSlider("4dLFX", State.GLOBCamLookFr[0]);
        setSlider("4dLFY", State.GLOBCamLookFr[1]);
        setSlider("4dLFZ", State.GLOBCamLookFr[2]);
        setSlider("4dLFW", State.GLOBrOW);

        setSlider("4dUPX", State.GLOBCamLookUp[0]);
        setSlider("4dUPY", State.GLOBCamLookUp[1]);
        setSlider("4dUPZ", -1 * State.GLOBCamLookUp[2]);
        setSlider("4dUPW", 0.0);

        setSlider("4dLIMX", 0.0);
        setSlider("4dLIMY", 0.0);
        setSlider("4dLIMZ", 0.0);
        setSlider("4dLIMW", 1.0);


        State.GLOBuse4D = $("4dCamCB").checked ? 1 : 0;
        update4dCamFromInputs();
    });


    $("shadowsCB")?.addEventListener("change", (e) => (State.GLOBShadow = e.target.checked ? 1 : 0));
    $("ItersCB")?.addEventListener("change", (e) =>
        State.GLOBHighResFlag = e.target.checked ? 1 : 0
    );
    $("NormCalcSL")?.addEventListener("change", (e) => (State.GLOBNormalType = toI(e.target.value)));
    $("FractalSL")?.addEventListener("change", (e) => (State.GLOBFractalType = toI(e.target.value)));
    $("rOWSL")?.addEventListener("input", (e) => (State.GLOBrOW = toF(e.target.value)));

    $("CutZCB")?.addEventListener("change", (e) => (State.GLOBCut = e.target.checked ? 1 : 0));
    $("CutZRange")?.addEventListener("input", (e) => (State.GLOBCutZ = toF(e.target.value)));


    const bgSelect = document.getElementById("BGColorSL");
    bgSelect?.addEventListener("change", (e) => {

        State.GLOBBGColor = parseInt(e.currentTarget.value, 10);
        console.log("BGColorSL ->", State.GLOBBGColor);
    });
    console.log(bgSelect)

    const updateFrColor = () => {
        State.GLOBFractColor = [toF($("FRCSliderR").value), toF($("FRCSliderG").value), toF($("FRCSliderB").value)];
    };
    $("FRCSliderR")?.addEventListener("input", updateFrColor);
    $("FRCSliderG")?.addEventListener("input", updateFrColor);
    $("FRCSliderB")?.addEventListener("input", updateFrColor);


    ["4dLIMX", "4dLIMY", "4dLIMZ", "4dLIMW", "4dLFX", "4dLFY", "4dLFZ", "4dLFW", "4dLAX", "4dLAY", "4dLAZ", "4dLAW", "4dUPX", "4dUPY", "4dUPZ", "4dUPW"]
        .forEach((id) => $(id)?.addEventListener("input", update4dCamFromInputs));


    $("downImg")?.addEventListener("change", (e) => {
        State.__downloadEachFrame = e.target.checked;
    });


    updateMuFromInputs();
    updateIterationSettings();
    updateFrColor();
    update4dCamFromInputs();


    const hqCheckbox = document.getElementById("ItersCB");
    const updateBtn = document.getElementById("BTNupdateIterationSettings");

    updateBtn?.addEventListener("click", () => {
        if (!hqCheckbox.checked) {
            hqCheckbox.click();
        }
    });


    return {downloadCanvasPNG};
}