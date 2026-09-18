uniform sampler2D texture;
uniform float time;

void main() {
    vec4 color = texture2D(texture, gl_TexCoord[0].st);

    float pulse = (sin(time * 4.0) * 0.5 + 0.5); // puls 0..1
    vec3 glowColor = vec3(1.0, 1.0, 1.0);

    vec3 final = mix(color.rgb, glowColor, pulse * 0.7);
    gl_FragColor = vec4(final, color.a);
}