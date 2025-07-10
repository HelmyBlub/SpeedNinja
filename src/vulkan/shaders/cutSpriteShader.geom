#version 450

layout(points) in;
layout(triangle_strip, max_vertices = 8) out;

layout(location = 0) in vec2 scale[];
layout(location = 1) in uint inSpriteIndex[];
layout(location = 2) in uint inSize[];
layout(location = 3) in float inCutAngle[];
layout(location = 4) in float inAnimationPerCent[];

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out uint spriteIndex;

vec2 rotateAroundPoint(vec2 point, vec2 pivot, float angle){
    vec2 translated = point - pivot;

    float s = sin(angle);
    float c = cos(angle);
    mat2 rot = mat2(c, -s, s, c);
    vec2 rotated = rot * translated;

    return rotated + pivot;
}

void main(void)
{	
    vec4 center = gl_in[0].gl_Position;
    const float zoom = center[3];
    center[0] = center[0] / zoom;
    center[1] = center[1] / zoom;
    center[3] = 1;
    
    // top-left vertex
    gl_Position = center;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.0, 0.0);
    EmitVertex();

    // top-right vertex
    gl_Position = center;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(1.0, 0.0);
    EmitVertex();

    // bottom-left vertex
    gl_Position = center;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.0, 1.0);
    EmitVertex();

    // bottom-right vertex
    gl_Position = center;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(1.0, 1.0);
    EmitVertex();

    EndPrimitive();
}
