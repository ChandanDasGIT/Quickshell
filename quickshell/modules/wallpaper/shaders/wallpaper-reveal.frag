#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 surfaceSize;
    vec2 revealCenter;
    float revealRadius;
    float edgeSoftness;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    // Current pixel coordinate on screen
    vec2 pixelCoord = qt_TexCoord0 * surfaceSize;

    // Distance from the circle's focal center
    float dist = distance(pixelCoord, revealCenter);

    // Smoothstep mask from inside the circle (1.0) to outside (0.0)
    float mask = 1.0 - smoothstep(revealRadius - edgeSoftness, revealRadius, dist);

    // Sample the incoming wallpaper and multiply by mask and layer opacity
    vec4 tex = texture(source, qt_TexCoord0);
    fragColor = tex * mask * qt_Opacity;
}
