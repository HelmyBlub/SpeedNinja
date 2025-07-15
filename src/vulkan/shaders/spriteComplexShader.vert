#version 450

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec2 inTex;
layout(location = 2) in float inAlpha;
layout(location = 3) in uint inSpriteIndex;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out uint spriteIndex;
layout(location = 2) out float alpha;

void main() {
    gl_Position = vec4(inPosition, 1.0, 1.0);
    fragTexCoord = inTex;
    spriteIndex = inSpriteIndex;
    alpha = inAlpha;
}
