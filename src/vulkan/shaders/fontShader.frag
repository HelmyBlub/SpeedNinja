#version 450
layout(location = 0) in vec2 fragTexCoord;
layout(location = 1) in vec4 inColor;

layout(location = 0) out vec4 outColor;

layout(binding = 2) uniform sampler2D texSampler;

void main() {
    vec4 tempOutColor = texture(texSampler, fragTexCoord);
    if(tempOutColor[3] > 0){
        tempOutColor.rgb = mix(vec3(0.0), inColor.rgb, tempOutColor[0]);
    }
    outColor = tempOutColor;
    if(outColor.a > inColor.a) outColor.a = inColor.a;
}
