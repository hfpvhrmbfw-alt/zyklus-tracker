/* Illustrationen und Symbole als Inline-SVG. Gehört zur Oberfläche, kennt nur Stimmungs- und Phasen-IDs.
   Farben, die sich mit Hell/Dunkel ändern, kommen aus CSS-Variablen (--sparkle, --ink, --line). */

const svg = (vb, body, cls = '') => `<svg viewBox="${vb}" class="${cls}" aria-hidden="true" focusable="false">${body}</svg>`;

// ---------- Kleine Bausteine ----------
const face = (x, y, s = 1) =>
  `<g transform="translate(${x} ${y}) scale(${s})" fill="none" stroke="#5B3A1A" stroke-width="1.3" stroke-linecap="round">` +
  `<path d="M-3.5 -1.2 q1 -1 2 0M1.5 -1.2 q1 -1 2 0"/><path d="M-2 1.8 q2 1.8 4 0"/></g>`;
const sadFace = (x, y, s = 1) =>
  `<g transform="translate(${x} ${y}) scale(${s})" fill="none" stroke="#4B5563" stroke-width="1.3" stroke-linecap="round">` +
  `<path d="M-3.5 -1.6 q1 1 2 0M1.5 -1.6 q1 1 2 0"/><path d="M-2 2.6 q2 -1.6 4 0"/></g>`;
const rays = (cx, cy, r1, r2, n = 8) => Array.from({ length: n }, (_, i) => {
  const a = (i / n) * Math.PI * 2, c = Math.cos(a), s = Math.sin(a);
  return `<line x1="${(cx + c * r1).toFixed(1)}" y1="${(cy + s * r1).toFixed(1)}" x2="${(cx + c * r2).toFixed(1)}" y2="${(cy + s * r2).toFixed(1)}"/>`;
}).join('');
const sun = (cx, cy, r) =>
  `<g stroke="#F2A93B" stroke-width="2" stroke-linecap="round">${rays(cx, cy, r + 3, r + 7)}</g>` +
  `<circle cx="${cx}" cy="${cy}" r="${r}" fill="#F7C548"/>`;
const cloudPath = 'M9 30 q-7 0 -7 -6.5 q0 -6 6.5 -6.5 q1.5 -8 10 -8 q6 0 9 5 q2 -1.5 4.5 -1.5 q7 0 7.5 7 q5 1 5 5.5 q0 5 -6 5 Z';
const cloud = (dx, dy, s, fill = '#EEF1F4') =>
  `<path transform="translate(${dx} ${dy}) scale(${s})" d="${cloudPath}" fill="${fill}" stroke="#9AA4AF" stroke-width="${(1.4 / s).toFixed(2)}" stroke-linejoin="round"/>`;
const sparkles = pts => pts.map(([x, y, r, c]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${c || 'var(--sparkle)'}"/>`).join('');
const star = (x, y, r, fill = '#F7C548') => {
  const p = Array.from({ length: 10 }, (_, i) => {
    const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.45 : r;
    return `${(x + Math.cos(a) * rr).toFixed(1)},${(y + Math.sin(a) * rr).toFixed(1)}`;
  }).join(' ');
  return `<polygon points="${p}" fill="${fill}"/>`;
};
const leaf = (x, y, rot, len, fill) =>
  `<path transform="translate(${x} ${y}) rotate(${rot}) scale(${len / 26})" d="M0 0 C6 -8 20 -8 26 0 C20 8 6 8 0 0Z" fill="${fill}"/>`;

// ---------- Stimmung (Wochenleiste) ----------
export const MOOD_ICON = {
  gut: svg('0 0 40 40', sun(20, 20, 9) + face(20, 20.5)),
  ok: svg('0 0 40 40', sun(15, 15, 7) + cloud(6, 9, 0.62) + face(19.5, 26, 0.85)),
  schlecht: svg('0 0 40 40', cloud(1, 3, 0.85) +
    '<g stroke="#5B8DD6" stroke-width="2" stroke-linecap="round"><line x1="12" y1="33" x2="10.5" y2="37"/><line x1="20" y1="33" x2="18.5" y2="37"/><line x1="28" y1="33" x2="26.5" y2="37"/></g>' +
    sadFace(19.5, 22, 0.9)),
  abends: svg('0 0 40 40', '<path d="M24 6 a14 14 0 1 0 10 24 a11 11 0 1 1 -10 -24z" fill="#F4D77C"/>' +
    star(30, 8, 3.2) + star(35, 17, 2.2) + face(15, 22, 0.85)),
};
export const EMPTY_ICON = svg('0 0 40 40', '<circle cx="20" cy="20" r="8" fill="none" stroke="var(--line)" stroke-width="1.5" stroke-dasharray="2.5 3"/>');

// ---------- Szenen für die Zykluskarte (je Phase) ----------
const blob = fill => `<path d="M22 38 C12 14 50 4 80 14 C112 0 156 14 150 50 C160 86 122 112 82 102 C42 116 6 96 14 70 C17 58 26 50 22 38Z" fill="${fill}"/>`;
const SCENES = {
  lut: blob('#1F2A5C') +
    '<path d="M98 26 a20 20 0 1 0 16 34 a16 16 0 1 1 -16 -34z" fill="#F4D77C"/>' + face(88, 48, 1.2) +
    star(40, 34, 6) + star(62, 70, 4.5) + star(128, 78, 5) + star(52, 50, 2.5, '#FFFFFF') +
    sparkles([[30, 62, 1.6, '#fff'], [74, 28, 1.4, '#fff'], [140, 40, 1.6, '#fff'], [110, 92, 1.4, '#fff'], [88, 84, 1.2, '#F47A4B']]),
  men: blob('#F3B4A0') +
    '<path d="M80 22 C80 22 56 52 56 68 a24 24 0 0 0 48 0 C104 52 80 22 80 22Z" fill="#E0614A"/>' +
    '<path d="M68 62 q-2 8 4 14" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".7"/>' + face(80, 70, 1.4) +
    '<path d="M36 44 c0 0 -7 9 -7 13 a7 7 0 0 0 14 0 c0 -4 -7 -13 -7 -13Z" fill="#E0614A" opacity=".75"/>' +
    '<path d="M126 66 c0 0 -6 8 -6 11 a6 6 0 0 0 12 0 c0 -3 -6 -11 -6 -11Z" fill="#E0614A" opacity=".75"/>' +
    sparkles([[118, 32, 2, '#fff'], [44, 86, 1.6, '#fff'], [138, 50, 1.4, '#F47A4B'], [30, 34, 1.4, '#F47A4B']]),
  fol: blob('#BFD8C2') +
    '<path d="M66 82 h28 l-4 22 h-20 z" fill="#E07A52"/><rect x="62" y="76" width="36" height="8" rx="3" fill="#C9653F"/>' +
    '<path d="M80 76 C80 60 80 48 80 36" stroke="#3F7D58" stroke-width="3" fill="none" stroke-linecap="round"/>' +
    leaf(80, 52, -150, 30, '#5E9C6C') + leaf(80, 44, -35, 30, '#7DB487') + leaf(80, 64, -20, 22, '#5E9C6C') + leaf(80, 36, -100, 18, '#7DB487') +
    sparkles([[40, 40, 2, '#fff'], [122, 36, 1.8, '#F47A4B'], [130, 70, 1.6, '#fff'], [34, 74, 1.4, '#F47A4B'], [110, 92, 1.4, '#fff']]),
  ovu: blob('#F8D9A0') + sun(80, 58, 24) + face(80, 59, 1.9) +
    star(36, 40, 5, '#F47A4B') + star(130, 84, 4, '#F47A4B') +
    sparkles([[124, 30, 2, '#fff'], [40, 84, 1.8, '#fff'], [140, 52, 1.4, '#fff'], [28, 62, 1.4, '#F47A4B']]),
  none: blob('#D9CBB3') +
    '<path d="M80 102 C80 80 76 60 70 40" stroke="#3F7D58" stroke-width="3" fill="none" stroke-linecap="round"/>' +
    leaf(76, 76, -160, 30, '#5E9C6C') + leaf(78, 66, -20, 28, '#7DB487') + leaf(72, 50, -150, 24, '#7DB487') + leaf(72, 44, -60, 20, '#5E9C6C') +
    sparkles([[44, 40, 2, '#fff'], [120, 40, 1.8, '#F47A4B'], [128, 76, 1.6, '#fff'], [40, 80, 1.4, '#F47A4B']]),
};
export const scene = phase => svg('0 0 164 120', SCENES[phase] || SCENES.none, 'scene');

// ---------- Kleine Bilder für die Ausblick-Karten ----------
export const CARD_ART = {
  drop: svg('0 0 60 60', '<path d="M30 8 C30 8 14 28 14 38 a16 16 0 0 0 32 0 C46 28 30 8 30 8Z" fill="#E0614A"/>' +
    '<path d="M22 36 q-1 6 3 10" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" opacity=".7"/>' +
    sparkles([[50, 14, 1.6], [8, 22, 1.4, '#F47A4B'], [52, 46, 1.2]])),
  flower: svg('0 0 60 60', '<path d="M30 58 V34" stroke="#3F7D58" stroke-width="2.5" stroke-linecap="round"/>' + leaf(30, 50, -150, 16, '#5E9C6C') + leaf(30, 46, -30, 16, '#7DB487') +
    [0, 72, 144, 216, 288].map(a => `<ellipse cx="30" cy="16" rx="6" ry="9" fill="#F4A3A0" transform="rotate(${a} 30 26)"/>`).join('') +
    '<circle cx="30" cy="26" r="6" fill="#F7C548"/>' + sparkles([[8, 12, 1.6], [52, 40, 1.4, '#F47A4B'], [50, 8, 1.2]])),
  leaf: svg('0 0 60 60', '<path d="M10 52 C20 40 32 30 50 10" stroke="#3F7D58" stroke-width="2.5" fill="none" stroke-linecap="round"/>' +
    leaf(18, 43, -100, 18, '#5E9C6C') + leaf(24, 37, 10, 18, '#7DB487') + leaf(32, 29, -110, 18, '#7DB487') + leaf(38, 23, 0, 18, '#5E9C6C') + leaf(46, 15, -90, 14, '#5E9C6C') +
    sparkles([[50, 44, 1.6], [10, 20, 1.4, '#F47A4B'], [30, 52, 1.2]])),
  moon: svg('0 0 60 60', '<path d="M34 10 a20 20 0 1 0 16 32 a16 16 0 1 1 -16 -32z" fill="#F4D77C"/>' + star(14, 14, 4) + star(50, 12, 3) +
    sparkles([[10, 44, 1.4], [48, 52, 1.6, '#F47A4B']])),
};

// ---------- Symbole (Leiste unten, Kopfzeile) ----------
const line = d => svg('0 0 24 24', `<g fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${d}</g>`, 'ico');
export const ICON = {
  home: line('<path d="M4 11 12 4l8 7v8.5a.5.5 0 0 1-.5.5H15v-6H9v6H4.5a.5.5 0 0 1-.5-.5Z"/>'),
  cal: line('<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/><circle cx="12" cy="15" r="1.2" fill="currentColor"/>'),
  chart: line('<path d="M4 20h16"/><rect x="5.5" y="11" width="3" height="6" rx="1"/><rect x="10.5" y="6" width="3" height="11" rx="1"/><rect x="15.5" y="9" width="3" height="8" rx="1"/>'),
  data: line('<path d="M6 3.5h8l4 4V20a.5.5 0 0 1-.5.5h-11.5a.5.5 0 0 1-.5-.5V4a.5.5 0 0 1 .5-.5Z"/><path d="M14 3.5V8h4M9 13h6M9 16.5h6"/>'),
  gear: line('<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2.2"/><circle cx="9" cy="17" r="2.2"/>'),
  sun: line('<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>'),
  moon: line('<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10Z"/>'),
  auto: line('<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v17a8.5 8.5 0 0 0 0-17Z" fill="currentColor"/>'),
};
