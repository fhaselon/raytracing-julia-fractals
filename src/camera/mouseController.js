// src/camera/mouseController.js
// Mouse controls for the 3D camera (orbit + zoom).
// While dragging, temporarily reduces quality to keep interaction responsive.

export function attachMouseController(State) {

    let CameraMouseIsMoving = false;
    let CameraMousePosX = 0;
    let CameraMousePosY = 0;
    let CameraRotate = -4.65999;
    let CameraOffsetZ = 0;


    let oldQualInter = State.GLOBMaxInterInter;
    let oldQualNorm = State.GLOBMaxIterNorm;
    let oldQualJulia = State.GLOBMaxIterJulia;
    let oldSuperSampling = State.GLOBSuperSampling;

    const canvas = document.getElementById("gl-surface");

    if (!canvas) {
        console.error("Canvas with id 'gl-surface' not found.");
        return;
    }


    function zoomCamera(event) {
        event.preventDefault();
        let norm = Math.sqrt(State.GLOBCamLookFr[0] * State.GLOBCamLookFr[0] + State.GLOBCamLookFr[1] * State.GLOBCamLookFr[1] + State.GLOBCamLookFr[2] * State.GLOBCamLookFr[2]);
        if (event.deltaY >= 0) {


            let factor = event.deltaY * 0.01;
            let res = [
                (State.GLOBCamLookFr[0] / norm) * factor,
                (State.GLOBCamLookFr[1] / norm) * factor,
                (State.GLOBCamLookFr[2] / norm) * factor,
            ]

            State.GLOBCamLookFr = [
                State.GLOBCamLookFr[0] + res[0],
                State.GLOBCamLookFr[1] + res[1],
                State.GLOBCamLookFr[2] + res[2],
            ]

            return;
        } else {
            let difVec = [
                State.GLOBCamLookFr[0] - State.GLOBCamLookAt[0],
                State.GLOBCamLookFr[1] - State.GLOBCamLookAt[1],
                State.GLOBCamLookFr[2] - State.GLOBCamLookAt[2],
            ];
            let len = Math.sqrt(difVec[0] * difVec[0] + difVec[1] * difVec[1] + difVec[2] * difVec[2]);

            let factor = event.deltaY * 0.01;
            let res = [
                (State.GLOBCamLookFr[0] / norm) * factor,
                (State.GLOBCamLookFr[1] / norm) * factor,
                (State.GLOBCamLookFr[2] / norm) * factor,
            ]

            let resNew = [
                State.GLOBCamLookFr[0] + res[0],
                State.GLOBCamLookFr[1] + res[1],
                State.GLOBCamLookFr[2] + res[2],
            ]

            let difVec2 = [
                State.GLOBCamLookFr[0] - resNew[0],
                State.GLOBCamLookFr[1] - resNew[1],
                State.GLOBCamLookFr[2] - resNew[2],
            ];


            let lenNew = Math.sqrt(difVec2[0] * difVec2[0] + difVec2[1] * difVec2[1] + difVec2[2] * difVec2[2]);

            if (len > lenNew) {
                State.GLOBCamLookFr = resNew;
            }


            return;
        }


    }

    canvas.addEventListener("wheel", zoomCamera, {passive: false});

    canvas.addEventListener("mousedown", (e) => {

        CameraMouseIsMoving = true;
        CameraMousePosX = e.offsetX;
        CameraMousePosY = e.offsetY;

        oldQualInter = State.GLOBMaxInterInter;
        oldQualNorm = State.GLOBMaxIterNorm;
        oldQualJulia = State.GLOBMaxIterJulia;
        oldSuperSampling = State.GLOBSuperSampling;

        State.GLOBMaxInterInter = 5;
        State.GLOBMaxIterNorm = 5;
        State.GLOBMaxIterJulia = 150;
        State.GLOBSuperSampling = 1;

    })

    canvas.addEventListener("mousemove", (e) => {

        if (CameraMouseIsMoving && State.GLOBuse4D == false) {
            let radius = Math.sqrt(State.GLOBCamLookFr[0] * State.GLOBCamLookFr[0] + State.GLOBCamLookFr[1] * State.GLOBCamLookFr[1]);

            CameraOffsetZ = CameraOffsetZ + (CameraMousePosY - e.offsetY) * 0.01;
            if (CameraOffsetZ > 4.0) {
                CameraOffsetZ = 4.0;
            }
            if (CameraOffsetZ < -4.0) {
                CameraOffsetZ = -4.0;
            }
            CameraRotate = CameraRotate + (CameraMousePosX - e.offsetX) * 0.01;
            State.GLOBCamLookFr = [Math.cos(CameraRotate) * radius, Math.sin(CameraRotate) * radius, CameraOffsetZ];
            CameraMousePosX = e.offsetX;
            CameraMousePosY = e.offsetY;
        }
    })

    canvas.addEventListener("mouseup", (e) => {

        if (CameraMouseIsMoving) {
            CameraMouseIsMoving = false;
            CameraMousePosX = 0;
            CameraMousePosY = 0;

            State.GLOBMaxInterInter = oldQualInter;
            State.GLOBMaxIterNorm = oldQualNorm;
            State.GLOBMaxIterJulia = oldQualJulia;
            State.GLOBSuperSampling = oldSuperSampling;
        }
    })
}