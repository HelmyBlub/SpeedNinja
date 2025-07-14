#version 450

layout(points) in;
layout(triangle_strip, max_vertices = 12) out;

layout(location = 0) in vec2 scale[];
layout(location = 1) in uint inSpriteIndex[];
layout(location = 2) in uint inSize[];
layout(location = 3) in float inCutAngle[];
layout(location = 4) in float inAnimationPerCent[];
layout(location = 5) in float inForce[];

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

void emitVertex(vec2 localPos, vec2 spriteCenter, vec2 animationOffset, float halfSize, vec2 rotatePoint){
    const float angle = inAnimationPerCent[0] * 8;
    const vec2 rotateOffset = rotateAroundPoint(localPos, vec2(0,0), angle);
    vec2 finalPos = spriteCenter + (localPos + animationOffset) * scale[0];
    gl_Position = vec4(finalPos, 0.0, 1.0);
    spriteIndex = inSpriteIndex[0];
    fragTexCoord = localPos / halfSize / 2 + 0.5;
    alpha = 1 - inAnimationPerCent[0];
    EmitVertex();
}

void main(){
    vec4 center = gl_in[0].gl_Position;
    const float zoom = center[3];
    center[0] = center[0] / zoom;
    center[1] = center[1] / zoom;
    center[3] = 1;
    const float halfSize = inSize[0] / zoom / 2;
    const float force = inForce[0] * 0.8 + 0.2;

    vec2 centerXY = center.xy;
    vec2 normal = vec2(cos(inCutAngle[0]), sin(inCutAngle[0]));

    // Local quad corners
    vec2 corners[4] = vec2[](
        vec2(-halfSize, -halfSize),
        vec2(+halfSize, -halfSize),
        vec2(+halfSize, +halfSize),
        vec2(-halfSize, +halfSize)
    );

    // Corners' distances to cut line
    float d[4];
    for (int i = 0; i < 4; ++i) {
        d[i] = dot(corners[i], normal);
    }

    // Split lists for each side
    vec2 posP[6]; int cntP = 0;
    vec2 posN[6]; int cntN = 0;

    // Build polygon outline for each half
    for (int i = 0; i < 4; ++i) {
        int j = (i + 1) % 4;

        vec2 Pi = corners[i];
        vec2 Pj = corners[j];
        float di = d[i];
        float dj = d[j];

        // Add current vertex to its side
        if (di >= 0.0) posP[cntP++] = Pi;
        else           posN[cntN++] = Pi;

        // Check edge crossing
        if (di * dj < 0.0) {
            float t = di / (di - dj);
            vec2 Pm = Pi + t * (Pj - Pi);
            posP[cntP++] = Pm;
            posN[cntN++] = Pm;
        }
    }

    // Emit positive half (shift + normal)
    const int order[6] = int[](0,1,3,2,5,4);
    const float animationOffsetX = inAnimationPerCent[0] * 500 * force;
    const float PI = 3.14159265359;
    float animationSinValue = inAnimationPerCent[0] * PI / force;
    if(animationSinValue > PI) animationSinValue = 0;
    float forceY =  500 * force;
    float animationOffsetY = -forceY;
    vec2 offsetP = vec2(animationOffsetX, animationOffsetY);
    vec2 rotatePointP = centerXY + normal * halfSize / 2;
    for (int i = 0; i < cntP; ++i) {
        emitVertex(posP[order[i]], centerXY, offsetP, halfSize, rotatePointP);
    }
    EndPrimitive();

    // Emit negative half (shift - normal)
    vec2 offsetN = vec2(-animationOffsetX, 0);
    vec2 rotatePointN = centerXY - normal * halfSize / 2;
    for (int i = 0; i < cntN; ++i) {
        emitVertex(posN[order[i]], centerXY, offsetN, halfSize, rotatePointN);
    }
    EndPrimitive();
}