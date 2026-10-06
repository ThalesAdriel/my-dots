.pragma library

// The animation layer's effects, after sysc-greet's backgrounds (matrix, rain, fireworks, aquarium) and Homirr's spiral.
// Characters stay inside ASCII and Latin-1.

const LEVELS = 6;

function rnd(n) {
    return Math.floor(Math.random() * n);
}

function pickOne(list) {
    return list[rnd(list.length)];
}

function grid(cols, rows, cellWidth, cellHeight) {
    return {
        cols: cols,
        rows: rows,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        ch: new Array(cols * rows).fill(" "),
        lv: new Int8Array(cols * rows).fill(-1),
        frame: 0,
        s: {}
    };
}

function clear(g) {
    g.lv.fill(-1);
}

// Art drawn over whatever is under it, the way the aquarium layers its cast from the back forward.
function stamp(g, x, y, art, level) {
    const left = Math.floor(x);
    const top = Math.floor(y);
    for (let r = 0; r < art.length; r++) {
        const row = top + r;
        if (row < 0 || row >= g.rows)
            continue;
        const line = art[r];
        for (let c = 0; c < line.length; c++) {
            const col = left + c;
            if (col < 0 || col >= g.cols || line[c] === " ")
                continue;
            g.ch[row * g.cols + col] = line[c];
            g.lv[row * g.cols + col] = level;
        }
    }
}

// The brighter of two things drawn in one cell wins.
function put(g, x, y, ch, level) {
    x = Math.round(x);
    y = Math.round(y);
    if (x < 0 || y < 0 || x >= g.cols || y >= g.rows)
        return;
    const i = y * g.cols + x;
    const l = Math.max(0, Math.min(LEVELS - 1, level));
    if (l >= g.lv[i]) {
        g.ch[i] = ch;
        g.lv[i] = l;
    }
}

// Digits, capitals and a few marks.
const MATRIX = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:=*+-<>|\"'.^~";
const SPIRAL = ".,:oc0OS$$";
// The aquarium's cast, copied from sysc-greet's, which takes it from asciiquarium.
const FISH_ART = {
    tiny: {
        left: [["<°)))><"]],
        right: [["><(((('>"]]
    },
    small: {
        left: [["  _///_", " /o    \\/", " > ))_./\\", "    <"]],
        right: [["     |\\    o", "    |  \\    o", "|\\ /    .\\ o", "| |       (", "|/ \\     /", "    |  /", "     |/"]]
    },
    medium: {
        left: [["          ,,////,", "        _////////_", "      .' -,  / / /`'-._     _.-'|", "     / _  \\\\/ / / / /  ',.='_.'/", "    / (o)  ||/_/_/_/_/_/_.-'_.'", "  .'       ||\\ \\ \\ \\ \\ \\ '-._'.", " '.--.    //\\ \\ \\ \\ \\  .'\"-._ '.", "   `'-.\\ \\   \\ \\ \\__.-'\\)    '-.|", "       \\\\)`\"\"\"\"\"` ", "        `"], ["                ,      /", "             . ~ ~ . ,/{", "           .'@ ))ejm'~.~", "           = - ~``   "]],
        right: [["\\o    o", " \\     \\", "  )=====>", " /     /", "/o    o"]]
    },
    large: {
        left: [["                 __,", "               .-'_-'`", "             .' {`", "         .-'````'-.    .-'``'.", "       .'(0)       '._/ _.-.  `\\", "      }     '. ))    _<`    )`  |", "       `-.,\\'.\\_, -\\` \\`---; .' /", "            )  )       '-.  '--:", "           ( ' (          ) '.  \\", "            '.  )      .'(   /   )", "              )/      (   '.    /", "                       '._( ) .'", "                           ( (", "                            `-."], ["    o   o", "                  /^^^^^7", "    '  '     ,oO))))))))Oo,", "           ,'))))))))))))))), /{", "      '  ,'o  ))))))))))))))))={", "         >    ))))))))))))))))={", "         `,   ))))))\\\\\\)))))))={ ", "           ',))))))))\\/)))))' \\{", "             '*O))))))))O*'"]],
        right: [["    __,", "   / - \\", "  (  O  )======>", "   \\ - /", "    `-'"]]
    }
};

// How fast each size swims, in cells a frame.
const FISH_SIZES = {
    tiny: {
        speed: [0.09, 0.36],
        band: [2, 10]
    },
    small: {
        speed: [0.075, 0.3],
        band: [2, 10]
    },
    medium: {
        speed: [0.04, 0.12],
        band: [2, 10]
    },
    large: {
        speed: [0.03, 0.08],
        band: [5, 15]
    }
};

const DIVER = ["              _______ ______", "              |     / |    /", "   O          |    /  |   /", "              |   /   |  /", "o  O 0         \\  \\   \\  \\", "o               \\  \\   \\  \\", "   o            /  /   /  /", "    o     /\\_  /\\\\\\   /  /", "     O  /    /    /     /", "..       /    /    /\\=    /", " ))))))) = /====/    \\", "(((((((( /    /\\=  _ }", "|-----_|_+( /   \\}", "\\_<\\_//|  \\  \\ }", "  =Q=  |==)\\  \\", "\\----/     ) )", "         / /", "        /=/", "      \\|/", "      o}"];
const BOATS = [["     _", "    /|\\", "   /_|_\\", " ____|____", " \\_o_o_o_/"], ["                __/___            ", "          _____/______|           ", "  _______/_____\\_______\\_____     ", "  \\              < < <       |"]];
const ANCHOR = ["        _-_", "       |(_)|", "        |||", "        |||", "        |||", "        |||", "        |||", "  ^     |^|     ^", "< ^ >   <+>   < ^ >", " | |    |||    | |", "  \\ \\__/ | \\__/ /", "    \\,__.|.__,/", "        (_)"];
const MERMAID = ["                           .-\"\"-.", "                          (___/\\ \\", "        ,                 (|^ ^ ) )", "       /(                _)_\\=_/  (", " ,..__/ `\\          ____(_/_ ` \\   )", "  `\\    _/        _/---._/(_)_  `\\ (", "    '--\\ `-.__..-'    /.    (_), |  )", "        `._        ___\\_____.'_| |__/", "           `~----\"`   `-.........' "];

function artText() {
    const all = [DIVER, ANCHOR, MERMAID].concat(BOATS);
    for (const size of Object.keys(FISH_ART))
        all.push(...FISH_ART[size].left, ...FISH_ART[size].right);
    return all.map(art => art.join("")).join("");
}

// Rain in three depths, far to near.
const WIND = 0.15;
const RAINDROPS = [
    {
        speed: [0.4, 0.7],
        length: [1, 2],
        glyph: ".",
        level: 1
    },
    {
        speed: [0.8, 1.2],
        length: [2, 3],
        glyph: ":",
        level: 2
    },
    {
        speed: [1.4, 2.0],
        length: [3, 5],
        glyph: "|",
        level: 4
    }
];

// Where a near drop lands, frame by frame: [columns across, rows up, glyph, level].
const SPLASH = [[[0, 0, "o", 5]], [[-1, -1, "'", 4], [1, -1, "'", 4], [0, 0, ".", 3]], [[-2, 0, ".", 2], [2, 0, ".", 2]]];

// Every character any effect draws, one atlas slot each, the art's and the ones the code draws itself.
const charset = Array.from(new Set(Array.from(MATRIX + SPIRAL + artText() + "|.:'o*+·~^_()"))).join("");
const slot = {};
for (let i = 0; i < charset.length; i++)
    slot[charset[i]] = i;

// The cells that changed since the last call, into RGBA bytes.
// Every byte written is a call into the canvas, so only the ones that changed are.
function paint(g, data) {
    if (!g.shown) {
        g.shown = new Int16Array(g.cols * g.rows).fill(-1);
        for (let i = 3; i < data.length; i += 4)
            data[i] = 255;
    }
    const lv = g.lv;
    const ch = g.ch;
    const shown = g.shown;
    for (let i = 0, n = g.cols * g.rows; i < n; i++) {
        const l = lv[i];
        const key = l < 0 ? -1 : l * 256 + slot[ch[i]];
        const old = shown[i];
        if (key === old)
            continue;
        shown[i] = key;
        const o = i * 4;
        if (l < 0) {
            data[o + 1] = 0;
            continue;
        }
        if (old < 0 || (old & 255) !== (key & 255))
            data[o] = key & 255;
        if (old < 0 || old >> 8 !== l)
            data[o + 1] = l + 1;
    }
}

// One falling line of code per column, with its own speed and length.
function codeline(g, x, anywhere) {
    return {
        x: x,
        y: anywhere ? Math.random() * g.rows * 2 - g.rows : -Math.random() * g.rows,
        speed: 0.3 + Math.random() * 0.7,
        length: 6 + rnd(19)
    };
}

// A new drop somewhere above the screen, or anywhere on it for the first frame.
function raindrop(g, anywhere) {
    const r = Math.random();
    const layer = r < 0.5 ? 0 : r < 0.8 ? 1 : 2;
    const look = RAINDROPS[layer];
    return {
        layer: layer,
        speed: look.speed[0] + Math.random() * (look.speed[1] - look.speed[0]),
        length: look.length[0] + rnd(look.length[1] - look.length[0] + 1),
        x: Math.random() * (g.cols + g.rows * WIND) - g.rows * WIND,
        y: anywhere ? Math.random() * g.rows : -Math.random() * 10
    };
}

// A fish of a size, off the edge it swims in from, or already somewhere on screen for the first frame.
function swimmer(g, size, anywhere) {
    const dir = Math.random() < 0.5 ? 1 : -1;
    const arts = dir > 0 ? FISH_ART[size].right : FISH_ART[size].left;
    const art = pickOne(arts);
    const width = Math.max(...art.map(line => line.length));
    const kind = FISH_SIZES[size];
    const top = g.s.surface + kind.band[0];
    const bottom = Math.max(top + 1, g.rows - kind.band[1]);
    return {
        size: size,
        art: art,
        width: width,
        dir: dir,
        speed: kind.speed[0] + Math.random() * (kind.speed[1] - kind.speed[0]),
        x: anywhere ? rnd(g.cols) - width / 2 : dir > 0 ? -width : g.cols,
        y: top + rnd(bottom - top),
        phase: Math.random() * Math.PI * 2,
        level: 2 + rnd(4)
    };
}

function bubble(g) {
    const top = g.s.surface + 2;
    return {
        x: rnd(g.cols),
        y: top + rnd(Math.max(1, g.rows - 1 - top)),
        speed: 0.2 + Math.random() * 0.3,
        wobble: Math.random() * Math.PI * 2,
        amount: 0.3 + Math.random() * 0.3
    };
}

const effects = {
    // Digital rain.
    matrix: {
        fps: 24,
        init(g) {
            g.s.glyphs = Array.from({
                length: g.cols * g.rows
            }, () => pickOne(MATRIX));
            g.s.lines = [];
            for (let x = 0; x < g.cols; x++)
                g.s.lines.push(codeline(g, x, true));
        },
        step(g) {
            const s = g.s;
            clear(g);
            for (let i = 0, n = Math.ceil(g.cols * g.rows / 80); i < n; i++)
                s.glyphs[rnd(s.glyphs.length)] = pickOne(MATRIX);

            for (let c = 0; c < s.lines.length; c++) {
                const line = s.lines[c];
                const before = Math.floor(line.y);
                line.y += line.speed;
                const head = Math.floor(line.y);
                if (head - line.length > g.rows) {
                    s.lines[c] = codeline(g, line.x, false);
                    continue;
                }
                for (let y = Math.max(0, before + 1); y <= head && y < g.rows; y++)
                    s.glyphs[y * g.cols + line.x] = pickOne(MATRIX);

                for (let k = 0; k < line.length; k++) {
                    const y = head - k;
                    if (y < 0 || y >= g.rows)
                        continue;
                    const f = k / line.length;
                    const level = k === 0 ? 5 : k < 3 ? 4 : f < 0.35 ? 3 : f < 0.65 ? 2 : 1;
                    put(g, line.x, y, k === 0 ? pickOne(MATRIX) : s.glyphs[y * g.cols + line.x], level);
                }
            }
        }
    },

    // Rain in three depths, the far drops small, dim and slow and the near ones long, bright and fast, all leaning a little with the wind.
    rain: {
        fps: 24,
        init(g) {
            g.s.drops = [];
            g.s.splashes = [];
            for (let i = 0, n = Math.round(g.cols * 1.4); i < n; i++)
                g.s.drops.push(raindrop(g, true));
        },
        step(g) {
            const s = g.s;
            const ground = g.rows - 1;
            clear(g);

            for (let i = 0; i < s.drops.length; i++) {
                const d = s.drops[i];
                d.y += d.speed;
                d.x += d.speed * WIND;
                if (d.layer === 2 && d.y >= ground) {
                    s.splashes.push({
                        x: Math.round(d.x),
                        age: 0
                    });
                    s.drops[i] = raindrop(g, false);
                    continue;
                }
                if (d.y - d.length > g.rows) {
                    s.drops[i] = raindrop(g, false);
                    continue;
                }
                const look = RAINDROPS[d.layer];
                for (let k = 0; k < d.length; k++)
                    put(g, d.x - k * WIND, d.y - k, look.glyph, k === 0 ? look.level + 1 : look.level);
            }

            s.splashes = s.splashes.filter(p => {
                for (const f of SPLASH[p.age])
                    put(g, p.x + f[0], ground + f[1], f[2], f[3]);
                return ++p.age < SPLASH.length;
            });
        }
    },

    // A rocket up from the bottom, then a ring of sparks that slows, falls and fades.
    fireworks: {
        fps: 24,
        init(g) {
            g.s.rockets = [];
            g.s.sparks = [];
            g.s.wait = 0;
        },
        step(g) {
            const s = g.s;
            clear(g);

            if (--s.wait <= 0) {
                s.rockets.push({
                    x: 10 + rnd(Math.max(1, g.cols - 20)),
                    y: g.rows - 1,
                    top: Math.floor(g.rows / 5) + rnd(Math.max(1, Math.floor(g.rows / 3))),
                    level: 3 + rnd(3)
                });
                s.wait = 8 + rnd(25);
            }

            s.rockets = s.rockets.filter(r => {
                r.y -= 1;
                if (r.y <= r.top) {
                    const n = 24 + rnd(22);
                    const life = 18 + rnd(14);
                    for (let k = 0; k < n; k++) {
                        const angle = Math.PI * 2 * k / n + Math.random() * 0.2;
                        const speed = 0.6 + Math.random() * 0.8;
                        s.sparks.push({
                            x: r.x,
                            y: r.y,
                            vx: Math.cos(angle) * speed * 2,
                            vy: Math.sin(angle) * speed,
                            life: life,
                            max: life,
                            level: r.level
                        });
                    }
                    return false;
                }
                put(g, r.x, r.y, "|", 4);
                put(g, r.x, r.y + 1, ".", 2);
                return true;
            });

            s.sparks = s.sparks.filter(p => {
                p.x += p.vx;
                p.y += p.vy;
                p.vy += 0.035;
                p.vx *= 0.96;
                if (--p.life <= 0)
                    return false;
                const f = p.life / p.max;
                put(g, p.x, p.y, f > 0.7 ? "*" : f > 0.45 ? "+" : f > 0.2 ? "·" : ".", Math.ceil(f * p.level));
                return true;
            });
        }
    },

    // sysc-greet's aquarium.
    aquarium: {
        fps: 20,
        init(g) {
            const s = g.s;
            s.surface = Math.max(2, Math.floor(g.rows * 0.15));
            s.weeds = [];
            for (let i = 0, n = Math.floor(g.cols / 8); i < n; i++)
                s.weeds.push({
                    x: rnd(g.cols),
                    height: 3 + rnd(Math.max(1, Math.floor(g.rows / 3))),
                    phase: Math.random() * Math.PI * 2,
                    speed: 0.05 + Math.random() * 0.05,
                    amount: 1 + Math.random() * 0.5,
                    wavy: Math.random() < 0.5
                });
            s.fish = [];
            for (let i = 0; i < 12; i++)
                s.fish.push(swimmer(g, Math.random() < 0.7 ? "tiny" : "small", true));
            s.fish.push(swimmer(g, "medium", true), swimmer(g, "large", true));
            s.bubbles = [];
            for (let i = 0, n = 15 + rnd(10); i < n; i++)
                s.bubbles.push(bubble(g));
            s.diver = {
                x: rnd(Math.floor(g.cols * 0.6)),
                y: g.rows - DIVER.length - 2,
                phase: 0
            };
            const type = rnd(2);
            s.boat = {
                art: BOATS[type],
                x: rnd(g.cols),
                dir: type === 1 || Math.random() < 0.5 ? -1 : 1
            };
            s.mermaid = null;
            s.lastMedium = 0;
            s.lastLarge = 0;
            s.lastMermaid = -1000;
        },
        step(g) {
            const s = g.s;
            const frame = ++g.frame;
            const surface = s.surface;
            const floor = g.rows - 2;
            clear(g);

            for (let x = 0; x < g.cols; x++) {
                if ((Math.floor(frame / 2) + x) % 3 === 0)
                    put(g, x, surface, "~", 3);
                const sand = x + Math.floor(frame / 5);
                put(g, x, floor, sand % 7 === 0 ? "^" : sand % 5 === 0 ? "." : "_", 1);
                if ((x + floor + 1) % 3 === 0)
                    put(g, x, floor + 1, ".", 1);
            }

            for (const weed of s.weeds) {
                weed.phase += weed.speed;
                const sway = Math.trunc(Math.sin(weed.phase) * weed.amount);
                for (let h = 0; h < weed.height; h++) {
                    const y = g.rows - 3 - h;
                    if (y <= surface)
                        break;
                    put(g, weed.x + sway, y, weed.wavy ? ((h + weed.x) % 2 === 0 ? "(" : ")") : "|", 1 + Math.floor(h / weed.height * 3));
                }
            }

            stamp(g, Math.floor(g.cols / 2) - 5, g.rows - ANCHOR.length - 1, ANCHOR, 1);

            if (frame % 15 === 0 && s.bubbles.length < 40)
                s.bubbles.push(bubble(g));
            s.bubbles = s.bubbles.filter(b => {
                b.y -= b.speed;
                b.wobble += 0.1;
                b.x += Math.sin(b.wobble) * b.amount;
                if (b.y < surface)
                    return false;
                put(g, Math.floor(b.x), Math.floor(b.y), "o", 4);
                return true;
            });

            if (s.diver) {
                const diver = s.diver;
                diver.x += 0.03;
                diver.phase += 0.1;
                diver.y += Math.sin(diver.phase) * 0.05;
                if (diver.x > g.cols + 30)
                    diver.x = -30;
                stamp(g, diver.x, diver.y, DIVER, 2);
            }

            const boat = s.boat;
            boat.x += 0.04 * boat.dir;
            if (boat.dir > 0 && boat.x > g.cols + 15)
                boat.x = -15;
            else if (boat.dir < 0 && boat.x < -40)
                boat.x = g.cols + 15;
            stamp(g, boat.x, surface - boat.art.length, boat.art, 4);

            // A mermaid every two or three minutes, swimming low in the diver's place.
            if (!s.mermaid && frame - s.lastMermaid >= 2400 + rnd(1200)) {
                const dir = Math.random() < 0.5 ? 1 : -1;
                const low = g.rows - MERMAID.length - 15;
                s.mermaid = {
                    dir: dir,
                    x: dir > 0 ? -50 : g.cols + 50,
                    y: Math.max(surface + 1, low + rnd(11)),
                    speed: 0.02 + Math.random() * 0.03,
                    phase: 0
                };
                s.lastMermaid = frame;
                s.diver = null;
            }
            if (s.mermaid) {
                const mermaid = s.mermaid;
                mermaid.x += mermaid.speed * mermaid.dir;
                mermaid.phase += 0.1;
                mermaid.y += Math.sin(mermaid.phase) * 0.08;
                if ((mermaid.dir > 0 && mermaid.x > g.cols + 50) || (mermaid.dir < 0 && mermaid.x < -50)) {
                    s.mermaid = null;
                    s.diver = {
                        x: -20,
                        y: g.rows - DIVER.length - 2,
                        phase: 0
                    };
                } else {
                    stamp(g, mermaid.x, mermaid.y, MERMAID, 5);
                }
            }

            if (frame % 25 === 0 && s.fish.length < 30)
                s.fish.push(swimmer(g, Math.random() < 0.7 ? "tiny" : "small", false));
            const has = size => s.fish.some(f => f.size === size);
            if (!has("medium") && frame - s.lastMedium >= 300 + rnd(100)) {
                s.fish.push(swimmer(g, "medium", false));
                s.lastMedium = frame;
            }
            if (!has("large") && frame - s.lastLarge >= 700) {
                s.fish.push(swimmer(g, "large", false));
                s.lastLarge = frame;
            }
            s.fish = s.fish.filter(f => {
                f.x += f.speed * f.dir;
                f.phase += 0.2;
                f.y += Math.sin(f.phase) * 0.1;
                if ((f.dir > 0 && f.x > g.cols + 2) || (f.dir < 0 && f.x + f.width < -2))
                    return false;
                stamp(g, f.x, f.y, f.art, f.level);
                return true;
            });
        }
    },

    // Homirr's spiral.
    spiral: {
        fps: 20,
        // The angle and the distance never change, only the phase does.
        init(g) {
            const base = new Float64Array(g.cols * g.rows);
            for (let y = 0, i = 0; y < g.rows; y++) {
                const dy = (y - g.rows / 2) * g.cellHeight;
                for (let x = 0; x < g.cols; x++, i++) {
                    const dx = (x - g.cols / 2) * g.cellWidth;
                    base[i] = Math.atan2(dy, dx) * 3 + Math.hypot(dx, dy) * 0.035;
                }
            }
            g.s.base = base;
        },
        step(g) {
            const phase = ++g.frame * 0.06 * 2.2;
            const base = g.s.base;
            for (let i = 0; i < base.length; i++) {
                const v = Math.sin(base[i] - phase);
                if (v < 0.08) {
                    g.lv[i] = -1;
                    continue;
                }
                g.ch[i] = SPIRAL[Math.min(9, Math.round(v * 9))];
                g.lv[i] = Math.min(5, Math.floor(v * 6));
            }
        }
    }
};
