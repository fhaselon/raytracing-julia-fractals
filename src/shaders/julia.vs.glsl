/* -------------------------------------------------------------------------
    Fullscreen quad vertex shader.
   -------------------------------------------------------------------------
    Positions are provided in clip space.
    Fragment shader performs ray marching.
 ------------------------------------------------------------------------- */

precision highp float;

attribute vec2 aPos;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
}