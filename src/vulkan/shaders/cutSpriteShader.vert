#version 450

layout(binding = 0) uniform UniformBufferObject {
    dvec2 translate;
    mat4 transformation;
} ubo;

layout(location = 0) in dvec2 inPosition;
layout(location = 1) in uint inSpriteIndex;
layout(location = 2) in uint inSize;
layout(location = 3) in float inCutAngle;
layout(location = 4) in float inAnimationPerCent;

layout(location = 0) out vec2 scale;
layout(location = 1) out uint spriteIndex;
layout(location = 2) out uint size;
layout(location = 3) out float cutAngle;
layout(location = 4) out float animationPerCent;

void main() {
    gl_Position = ubo.transformation * vec4(inPosition + ubo.translate, 0.9, 1);
    scale[0] = ubo.transformation[0][0];
    scale[1] = ubo.transformation[1][1];
    spriteIndex = inSpriteIndex;
    size = inSize;
    cutAngle = inCutAngle;
    animationPerCent = inAnimationPerCent;
}
