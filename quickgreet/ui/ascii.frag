// Draws the animation layer's grid: each screen pixel finds its cell, reads that cell's glyph and level from the grid picture (one pixel per cell), and takes the glyph's coverage from the atlas, a row of every glyph in one cell-sized slot each. The level picks one of six colours; level zero is an empty cell.
// Shipped compiled, so the greeter needs nothing to build it. After a change, from the checkout, in PowerShell:
//   docker run --rm -v "${PWD}/quickgreet/ui:/ui" --entrypoint sh quickgreet-test -c "/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 -o /ui/ascii.frag.qsb /ui/ascii.frag"
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 cells;
    vec2 cellSize;
    vec2 area;
    float glyphs;
    vec4 color0;
    vec4 color1;
    vec4 color2;
    vec4 color3;
    vec4 color4;
    vec4 color5;
};

layout(binding = 1) uniform sampler2D grid;
layout(binding = 2) uniform sampler2D atlas;

void main()
{
    vec2 px = qt_TexCoord0 * area;
    vec2 cell = floor(px / cellSize);
    vec4 here = texture(grid, (cell + 0.5) / cells);
    float level = floor(here.g * 255.0 + 0.5);
    if (level < 0.5) {
        fragColor = vec4(0.0);
        return;
    }

    float glyph = floor(here.r * 255.0 + 0.5);
    vec2 within = (px - cell * cellSize) / cellSize;
    float ink = texture(atlas, vec2((glyph + within.x) / glyphs, within.y)).a;

    vec4 tint = level < 1.5 ? color0 : level < 2.5 ? color1 : level < 3.5 ? color2 : level < 4.5 ? color3 : level < 5.5 ? color4 : color5;
    fragColor = vec4(tint.rgb, 1.0) * tint.a * ink * qt_Opacity;
}
