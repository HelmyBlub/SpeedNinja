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
layout(location = 2) out float alpha;

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
    const vec2 size = scale[0] * inSize[0] / zoom / 2;
    const vec2 offset = vec2(inAnimationPerCent[0], 0);
    center -= vec4(offset, 0, 0);
    const float tempAlpha = 1 - inAnimationPerCent[0];
    //first
    // top-left vertex
    gl_Position = center + vec4(-size, 0, 0);
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.0, 0.0);
    alpha = tempAlpha;
    EmitVertex();

    // top-right vertex
    gl_Position = center + vec4(0, -size.y, 0, 0);;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.5, 0.0);
    alpha = tempAlpha;
    EmitVertex();

    // bottom-left vertex
    gl_Position = center + vec4(-size.x, size.y, 0, 0);;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.0, 1);
    alpha = tempAlpha;
    EmitVertex();

    // bottom-right vertex
    gl_Position = center + vec4(0, size.y, 0, 0);;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.5, 1);
    alpha = tempAlpha;
    EmitVertex();

    //second
    center += vec4(offset * 2, 0, 0);    
    // top-left vertex
    gl_Position = center + vec4(0, -size.y, 0, 0);
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.5, 0.0);
    alpha = tempAlpha;
    EmitVertex();

    // top-right vertex
    gl_Position = center + vec4(size.x, -size.y, 0, 0);;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(1.0, 0.0);
    alpha = tempAlpha;
    EmitVertex();

    // bottom-left vertex
    gl_Position = center + vec4(0, size.y, 0, 0);;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(0.5, 1.0);
    alpha = tempAlpha;
    EmitVertex();

    // bottom-right vertex
    gl_Position = center + vec4(size, 0, 0);;
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = vec2(1.0, 1.0);
    alpha = tempAlpha;
    EmitVertex();

    EndPrimitive();
}
