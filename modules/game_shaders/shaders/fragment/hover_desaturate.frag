uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;
uniform float u_Opacity;
uniform vec4 u_Color;

void main()
{
    vec4 color = texture2D(u_Tex0, v_TexCoord) * u_Color;
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desaturated = mix(vec3(gray), color.rgb, 0.5);
    gl_FragColor = vec4(desaturated, color.a);
    gl_FragColor.a *= u_Opacity;
}
