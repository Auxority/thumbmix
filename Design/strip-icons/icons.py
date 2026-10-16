"""Thumbmix's strip icons: one drawing per desk icon (`config/icon` 1-74), on a 24 x 24 grid.

Style: a 0.9 outline, plus a 28% tint over each icon's body, drawn as one layer so overlapping shapes don't stack.
Rules every drawing keeps (checked by measuring each icon's bounding box when it was drawn):
- a detail line ends on the outline it sits on, or stops 0.8 inside it; legs and stands meet their body;
- everything stays inside 1.5-22.5 and is centred on 12; whatever stands on the floor ends on y = 21.6;
- stands are one tripod (legs spread 5 from a hub at 17.4); mic bases are 6.4 wide;
- no two desk icons share a drawing: a shared glyph tells neither apart.

Keys: body (closed shapes, tinted and outlined), cuts (detail lines on the body), parts (thin parts around it),
tint/outline (when the outline differs from the tinted shape), rotate (degrees about the centre for all of the
above), fixed (drawn after, never rotated), shift (dx, dy for the whole drawing).
"""

ICONS = {
    1: dict(  # None
        parts='<rect x="4" y="4" width="16" height="16" rx="3" stroke-dasharray="2 1.68" stroke-dashoffset="3.36"/>',
    ),
    2: dict(  # Kick Back
        body='<circle cx="12" cy="10.5" r="8.5"/>',
        cuts='<circle cx="12" cy="10.5" r="6.6"/><circle cx="12" cy="10.5" r="1.7"/><path d="M12 12.2V19"/><path d="M7.33 5.83L5.99 4.49"/><path d="M16.67 5.83L18.01 4.49"/><path d="M16.67 15.17L18.01 16.51"/><path d="M7.33 15.17L5.99 16.51"/>',
        parts='<path d="M12 19v2.6M9.4 21.6h5.2"/><path d="M7.12 17.46L4.4 21.6M16.88 17.46L19.6 21.6"/>',
    ),
    3: dict(  # Kick Front
        body='<circle cx="12" cy="10.5" r="8.5"/>',
        cuts='<circle cx="12" cy="10.5" r="6.6"/><circle cx="14.6" cy="13" r="1.8"/><path d="M7.33 5.83L5.99 4.49"/><path d="M16.67 5.83L18.01 4.49"/><path d="M16.67 15.17L18.01 16.51"/><path d="M7.33 15.17L5.99 16.51"/>',
        parts='<path d="M7.12 17.46L4.4 21.6M16.88 17.46L19.6 21.6"/>',
    ),
    4: dict(  # Snare Top
        body='<path d="M4 10.2V15.6A8 2.6 0 0 0 20 15.6V10.2A8 2.6 0 0 1 4 10.2z"/><ellipse cx="12" cy="10.2" rx="8" ry="2.6"/>',
        cuts='<path d="M7.04 13.04V16.84"/><path d="M12 13.6V17.4"/><path d="M16.96 13.04V16.84"/>',
        parts='<path d="M6.4 2.6l4.6 6M17.6 2.6L13 8.6"/><path d="M8.4 17.92L6.4 21.6"/><path d="M15.6 17.92L17.6 21.6"/>',
    ),
    5: dict(  # Snare Bottom
        body='<path d="M4 5.6V11A8 2.6 0 0 0 20 11V5.6A8 2.6 0 0 1 4 5.6z"/><ellipse cx="12" cy="5.6" rx="8" ry="2.6"/>',
        cuts='<path d="M7.04 8.44V12.24"/><path d="M12 9V12.8"/><path d="M16.96 8.44V12.24"/>',
        parts='<path d="M6 14.42A8 2.6 0 0 0 18 14.42M6 15.82A8 2.6 0 0 0 18 15.82"/><path d="M6 13.82V16.42M18 13.82V16.42"/>',
        shift=(0, 1.6),
    ),
    6: dict(  # High Tom
        body='<path d="M6.8 7.4V12.2A5.2 1.8 0 0 0 17.2 12.2V7.4A5.2 1.8 0 0 1 6.8 7.4z"/><ellipse cx="12" cy="7.4" rx="5.2" ry="1.8"/>',
        cuts='<path d="M8.78 9.61V12.81"/><path d="M15.22 9.61V12.81"/><path d="M11.03 10.3v2.6M12.98 10.3v2.6M11.03 11.6h1.95"/>',
        parts='<path d="M12 14V19M9.6 21.6L12 19l2.4 2.6"/>',
    ),
    7: dict(  # Mid Tom
        body='<path d="M5.4 6V12.2A6.6 2.2 0 0 0 18.6 12.2V6A6.6 2.2 0 0 1 5.4 6z"/><ellipse cx="12" cy="6" rx="6.6" ry="2.2"/>',
        cuts='<path d="M7.91 8.53V13.13"/><path d="M16.09 8.53V13.13"/><path d="M10.88 12.8V9.8l1.12 1.65l1.12 -1.65V12.8"/>',
        parts='<path d="M12 14.4V19M9.6 21.6L12 19l2.4 2.6"/>',
    ),
    8: dict(  # Floor Tom
        body='<path d="M5 5V14.6A7 2.2 0 0 0 19 14.6V5A7 2.2 0 0 1 5 5z"/><ellipse cx="12" cy="5" rx="7" ry="2.2"/>',
        cuts='<path d="M7.66 7.53V15.53"/><path d="M16.34 7.53V15.53"/><path d="M13.35 10.2H10.65v3.6M10.65 12h2.16"/>',
        parts='<path d="M6.6 16L4.8 21.6"/><path d="M17.4 16L19.2 21.6"/><path d="M12 16.8V21.6"/>',
    ),
    9: dict(  # Hi-Hat
        body='<path d="M2 8.2c4.5-.7 7.4-1.3 8.2-2.8h3.6c.8 1.5 3.7 2.1 8.2 2.8c-5 .6-15 .6-20 0z"/><path d="M2 11.2c5-.6 15-.6 20 0c-4.5.7-7.4 1.3-8.2 2.8h-3.6c-.8-1.5-3.7-2.1-8.2-2.8z"/>',
        cuts='<path d="M10.6 7.6h2.8M10.6 11.8h2.8"/>',
        parts='<path d="M12 1.4v4M12 14v3.4"/><rect x="11" y="2.8" width="2" height="1.6" rx=".3"/><path d="M12 17.4l-5 4.2M12 17.4l5 4.2M12 17.4v4.2"/>',
    ),
    10: dict(  # Ride
        body='<ellipse cx="11.5" cy="9.2" rx="9.8" ry="3.7" transform="rotate(-10 11.5 9.2)"/>',
        cuts='<ellipse cx="11.5" cy="9.2" rx="6.6" ry="2.4" transform="rotate(-10 11.5 9.2)"/><ellipse cx="11.5" cy="9.2" rx="2.4" ry="1" transform="rotate(-10 11.5 9.2)"/>',
        parts='<path d="M11.5 12.95v4.45M11.5 17.4l-5 4.2M11.5 17.4l5 4.2M11.5 17.4v4.2"/>',
        shift=(0.5, 0),
    ),
    11: dict(  # Drum Kit
        body='<circle cx="12" cy="16.2" r="5.4"/><path d="M6 7.6V10.1A2.7 0.95 0 0 0 11.4 10.1V7.6A2.7 0.95 0 0 1 6 7.6z"/><ellipse cx="8.7" cy="7.6" rx="2.7" ry="0.95"/><path d="M12.6 7.6V10.1A2.7 0.95 0 0 0 18 10.1V7.6A2.7 0.95 0 0 1 12.6 7.6z"/><ellipse cx="15.3" cy="7.6" rx="2.7" ry="0.95"/><path transform="rotate(-8 4.4 4.4)" d="M1.9 4.4Q4.4 3.1 6.9 4.4Q4.4 4.95 1.9 4.4z"/><path transform="rotate(8 19.6 4.4)" d="M17.1 4.4Q19.6 3.1 22.1 4.4Q19.6 4.95 17.1 4.4z"/>',
        cuts='<circle cx="12" cy="16.2" r="3.9"/><path d="M8.7 9.35V10.25"/><path d="M15.3 9.35V10.25"/>',
        parts='<path d="M4.4 4.9V19.8M4.4 19.8l-1.8 1.8M4.4 19.8l1.8 1.8M19.6 4.9V19.8M19.6 19.8l-1.8 1.8M19.6 19.8l1.8 1.8"/><path d="M12 10.8V9.6"/>',
    ),
    12: dict(  # Cowbell
        body='<path d="M9 4.6h6l3.4 13.6H5.6z"/>',
        cuts='<path d="M6.2 15.8h11.6"/><path d="M12 5.4V15"/>',
        parts='<path d="M12 4.6V2.2M10 2.2h4"/>',
        shift=(0, 1.8),
    ),
    13: dict(  # Bongos
        body='<ellipse cx="7.4" cy="7.6" rx="4.6" ry="1.6"/><path d="M2.8 7.6l1.4 9.4A3.2 1 0 0 0 10.6 17L12 7.6A4.6 1.6 0 0 1 2.8 7.6z"/><ellipse cx="17.2" cy="9.4" rx="3.8" ry="1.3"/><path d="M13.4 9.4l1.2 7.2A2.6.8 0 0 0 19.8 16.6l1.2-7.2A3.8 1.3 0 0 1 13.4 9.4z"/>',
        cuts='<path d="M3.51 12.4Q7.4 13.4 11.29 12.4M13.97 12.8Q17.2 13.6 20.43 12.8"/>',
        parts='<path d="M10.96 14.6h3.31M7.4 18v3.6M17.2 17.4v4.2M5 21.6h4.8M14.8 21.6h4.8"/>',
    ),
    14: dict(  # Congas
        body='<path d="M7.8 3.8Q5.4 11.6 7.4 19.4A4.6 1.4 0 0 0 16.6 19.4Q18.6 11.6 16.2 3.8A4.2 1.5 0 0 0 7.8 3.8z"/><ellipse cx="12" cy="3.8" rx="4.2" ry="1.5"/>',
        cuts='<path d="M7.35 5.4A4.65 1.5 0 0 0 16.65 5.4"/><path d="M10.2 7.58V19.89"/><path d="M13.8 7.58V19.89"/>',
        parts='<path d="M8.6 20.34L7.6 21.6M15.4 20.34l1.2 1.26"/>',
    ),
    15: dict(  # Tambourine
        body='<path fill-rule="evenodd" d="M12 3.4a8.6 8.6 0 1 0 0 17.2a8.6 8.6 0 1 0 0-17.2zM12 6.2a5.8 5.8 0 1 1 0 11.6a5.8 5.8 0 1 1 0-11.6z"/>',
        cuts='<circle cx="19.2" cy="12" r="1"/><circle cx="15.6" cy="18.2" r="1"/><circle cx="8.4" cy="18.2" r="1"/><circle cx="4.8" cy="12" r="1"/><circle cx="8.4" cy="5.8" r="1"/><circle cx="15.6" cy="5.8" r="1"/>',
    ),
    16: dict(  # Vibraphone
        body='<rect x="2.6" y="3" width="2.4" height="10" rx="1"/><rect x="5.9" y="3" width="2.4" height="9.2" rx="1"/><rect x="9.2" y="3" width="2.4" height="8.4" rx="1"/><rect x="12.5" y="3" width="2.4" height="7.6" rx="1"/><rect x="15.8" y="3" width="2.4" height="6.8" rx="1"/><rect x="19.1" y="3" width="2.4" height="6" rx="1"/>',
        cuts='<path d="M2.6 5h18.9"/>',
        parts='<path d="M3.8 13v3.6M7.1 12.2v4.4M10.4 11.4v5.2M13.7 10.6v6M17 9.8v6.8M20.3 9v7.6"/><path d="M2.4 16.6h19.2M4 16.6v5M20 16.6v5"/>',
    ),
    17: dict(  # Electric Bass
        body='<path d="M11.1 5V14.2L9.9 13.1C9 12.2 7.2 12.4 7.2 14C7.2 15.2 8.2 15.8 8.2 16.8C8.2 17.8 6.6 18.4 6.6 20.2C6.6 21.8 8.8 22.4 12 22.4S17.2 21.8 17.2 20.2C17.2 18.6 15.8 18 15.8 17C15.8 15.8 16.8 15.4 16.8 14.4C16.8 13.2 15.6 12.8 14.6 13.8L12.9 15.2V5z"/><path d="M11.1 5V2L11.9 1.4H14.2L14.6 2.2L12.9 3.4V5z"/>',
        cuts='<rect x="10.2" y="17" width="3.6" height="1.2" rx=".4"/><path d="M10.4 20.4h3.2"/>',
        parts='<path d="M11.1 2.8H9.9M11.1 4.2H9.9"/>',
    ),
    18: dict(  # Acoustic Bass
        body='<path d="M12 11.8c-2.4 0-3.5 1-3.5 2.5c0 1.1 1 1.5 1 2.4s-1.7 1.3-1.7 2.9c0 1.9 1.9 2.8 4.2 2.8s4.2-.9 4.2-2.8c0-1.6-1.7-2-1.7-2.9s1-1.3 1-2.4c0-1.5-1.1-2.5-3.5-2.5z"/><rect x="11.2" y="5" width="1.6" height="8.6" rx=".3"/><path d="M10.3 1.4h3.4l-.4 3.6h-2.6z"/>',
        cuts='<circle cx="12" cy="16.2" r="1.4"/><path d="M10.8 19.6h2.4"/>',
        parts='<path d="M10.4 2.3h-1.2M13.6 2.3h1.2"/><path d="M10.59 4h-1.2M13.41 4h1.2"/>',
    ),
    19: dict(  # Contrabass
        body='<path d="M12 4.6c-1.8 0-2.8.8-3.5 2.2c-.6 1.3-1.3 2.2-1.3 3.6c0 1 .9 1.5.9 2.4s-2.2 1.7-2.2 4.4c0 2.7 2.5 4.6 6.1 4.6s6.1-1.9 6.1-4.6c0-2.7-2.2-3.5-2.2-4.4s.9-1.4.9-2.4c0-1.4-.7-2.3-1.3-3.6c-.7-1.4-1.7-2.2-3.5-2.2z"/>',
        cuts='<path d="M11.3 4.6v9.6M12.7 4.6v9.6"/><path d="M10.2 15h3.6"/><path d="M11.1 15.2l.9 3.8.9-3.8"/><path d="M9 13c-.4.7.4 1.6 0 2.5M15 13c-.4.7.4 1.6 0 2.5"/>',
        parts='<path d="M11.3 3.2v1.4M12.7 3.2v1.4"/><path d="M12 3.2c-.9 0-1.3-.4-1.3-.9s.5-.8 1.3-.8"/><path d="M11.3 3.9h-1.2M12.7 3.9h1.2"/><path d="M12 21.8v.8"/>',
        shift=(0, -0.3),
    ),
    20: dict(  # Les Paul Guitar
        body='<path d="M11.1 5V12.2C9.6 11.4 7.6 11.8 7.6 13.8C7.6 15 8.4 15.6 8.4 16.6C8.4 17.6 6.8 18.2 6.8 20C6.8 21.6 9 22.4 12 22.4S17.2 21.6 17.2 20C17.2 18.2 15.8 17.4 15.8 16.2C15.8 15.2 16.6 14.6 16.6 13.6C16.6 12.8 16 12.6 15.4 13.2L13.8 14.6H12.9V5z"/><path d="M10.3 1.4h3.4l-.4 3.6h-2.6z"/>',
        cuts='<rect x="10.4" y="15.6" width="3.2" height="1.2" rx=".4"/><rect x="10.4" y="18" width="3.2" height="1.2" rx=".4"/><path d="M10.6 20.6h2.8"/><circle cx="15.2" cy="19.2" r=".6" fill="currentColor" stroke="none"/><circle cx="14.6" cy="20.8" r=".6" fill="currentColor" stroke="none"/>',
        parts='<path d="M10.4 2.3h-1.2M13.6 2.3h1.2"/><path d="M10.59 4h-1.2M13.41 4h1.2"/>',
    ),
    21: dict(  # Ibanez Guitar
        body='<path d="M11.1 5V13.2L8.4 9.6L8 14.4C7.9 15.6 8.6 16.2 8.6 17C8.6 17.8 7 18.4 7 20.2C7 21.8 9.2 22.4 12 22.4S17 21.8 17 20C17 18.4 15.4 17.8 15.4 16.8C15.4 15.8 16.6 15.2 16.8 13.6L17 10.6L12.9 13.8V5z"/><path d="M11.1 5V2.4L14.8 1.2L12.9 5z"/>',
        cuts='<rect x="10.4" y="15" width="3.2" height="1.2" rx=".4"/><path d="M10.6 17.6h2.8"/><rect x="10.4" y="19" width="3.2" height="1.2" rx=".4"/><path d="M10.4 21.2h3.2"/>',
        parts='<path d="M11.1 3H9.9M11.1 4.4H9.9"/>',
    ),
    22: dict(  # Washburn Guitar
        body='<path d="M11.1 5V12.4C10.6 12 10 11.8 9.4 12C7.8 11.6 6.4 12.6 6.4 14.4V19C6.4 21 8.8 22.4 12 22.4S17.6 21 17.6 19V14.4C17.6 12.6 16.2 11.6 14.6 12C14 11.8 13.4 12 12.9 12.4V5z"/><path d="M10.3 1.4h3.4l-.4 3.6h-2.6z"/>',
        cuts='<path d="M8.4 15c-.5.8.5 1.8 0 2.8M15.6 15c-.5.8.5 1.8 0 2.8"/><rect x="10.4" y="14.6" width="3.2" height="1.2" rx=".4"/><rect x="10.4" y="17" width="3.2" height="1.2" rx=".4"/><path d="M10.4 19.8h3.2"/>',
        parts='<path d="M10.4 2.3h-1.2M13.6 2.3h1.2"/><path d="M10.59 4h-1.2M13.41 4h1.2"/>',
    ),
    23: dict(  # Acoustic Guitar
        body='<path d="M12 8c-3.3 0-4.8 1.4-4.8 3.4c0 1.5 1.2 2.1 1.2 3.2s-2.2 1.7-2.2 4c0 2.5 2.6 3.8 5.8 3.8s5.8-1.3 5.8-3.8c0-2.3-2.2-2.9-2.2-4s1.2-1.7 1.2-3.2c0-2-1.5-3.4-4.8-3.4z"/><rect x="11.2" y="4.2" width="1.6" height="6.4" rx=".3"/><path d="M10.6 1.4h2.8l-.4 2.8h-2z"/>',
        cuts='<circle cx="12" cy="13.4" r="1.8"/><path d="M10.4 18.6h3.2"/>',
        parts='<path d="M10.67 2.3h-1.1M10.83 3.4h-1.1M13.33 2.3h1.1M13.17 3.4h1.1"/>',
    ),
    24: dict(  # Bass Amp
        body='<rect x="5" y="2.6" width="14" height="4" rx=".8"/><rect x="5" y="7.4" width="14" height="14.2" rx="1.2"/>',
        cuts='<circle cx="12" cy="14.6" r="5"/><circle cx="12" cy="14.6" r="1.6"/><path d="M7.4 4.6h.1M9.4 4.6h.1M11.4 4.6h.1M16.6 4.6h.1"/>',
        parts='<path d="M10 2.6V1.6h4v1"/>',
    ),
    25: dict(  # Guitar Amp
        body='<rect x="2.5" y="6.6" width="19" height="13.6" rx="1.2"/>',
        cuts='<path d="M2.5 10h19"/><path d="M5 8.3h.1M7 8.3h.1M9 8.3h.1M11 8.3h.1M13 8.3h.1"/><circle cx="8" cy="15.1" r="3.3"/><circle cx="16" cy="15.1" r="3.3"/>',
        parts='<path d="M9 6.6V5h6v1.6"/><path d="M4.4 20.2v1.4M19.6 20.2v1.4"/>',
    ),
    26: dict(  # Amp Cabinet
        body='<rect x="3" y="3" width="18" height="17.6" rx="1.2"/>',
        cuts='<circle cx="7.8" cy="7.8" r="3.2"/><circle cx="16.2" cy="7.8" r="3.2"/><circle cx="7.8" cy="15.8" r="3.2"/><circle cx="16.2" cy="15.8" r="3.2"/>',
        parts='<path d="M5 20.6v1M19 20.6v1"/>',
    ),
    27: dict(  # Piano
        body='<rect x="4" y="10.6" width="17.6" height="3.6" rx=".4"/><path d="M21.6 10.6L5.8 4.2L5.2 5.2L19.4 10.6z"/>',
        parts='<path d="M13.6 10.6L12.4 7.94"/><path d="M5.4 14.2v7.4M20.2 14.2v7.4M12.8 14.2v4.8M11.2 19h3.2"/>',
        shift=(-0.8, 0),
    ),
    28: dict(  # Organ
        body='<path d="M3.4 14.6V8.3a1.3 1.3 0 0 1 2.6 0V14.6"/><path d="M7.2 14.6V5.7a1.3 1.3 0 0 1 2.6 0V14.6"/><path d="M10.7 14.6V3.3a1.3 1.3 0 0 1 2.6 0V14.6"/><path d="M14.2 14.6V5.7a1.3 1.3 0 0 1 2.6 0V14.6"/><path d="M18 14.6V8.3a1.3 1.3 0 0 1 2.6 0V14.6"/><rect x="2.4" y="14.6" width="19.2" height="7" rx="1.2"/>',
        cuts='<path d="M4 11.4h1.4M7.8 10.6h1.4M11.3 10h1.4M14.8 10.6h1.4M18.6 11.4h1.4"/><path d="M2.4 17.4h19.2M2.4 19.6h19.2"/>',
    ),
    29: dict(  # Harpsichord
        body='<path d="M4 21.6V7.4c0-1 .9-1.6 1.8-1.1L20 14v7.6z"/>',
        cuts='<path d="M4 18.4h16"/><path d="M6.2 19.4v1.8M8.4 19.4v1.8M10.6 19.4v1.8M12.8 19.4v1.8M15 19.4v1.8M17.2 19.4v1.8"/><path d="M7.6 8.58V17.6M10.4 10.09V17.6M13.2 11.61V17.6M16 13.13V17.6"/>',
        parts='<path d="M5 21.6v1.2M19 21.6v1.2"/>',
        shift=(0, -1.2),
    ),
    30: dict(  # Keyboard
        body='<rect x="2" y="6.6" width="20" height="6" rx="1.2"/>',
        cuts='<path d="M2 9h20"/><path d="M4.5 9v3.6M7 9v3.6M9.5 9v3.6M12 9v3.6M14.5 9v3.6M17 9v3.6M19.5 9v3.6"/>',
        parts='<path d="M5.4 12.6l13.2 9M18.6 12.6l-13.2 9"/>',
    ),
    31: dict(  # Synthesizer 1
        body='<rect x="2" y="6" width="20" height="12" rx="1.2"/>',
        cuts='<path d="M2 12.4h20"/><path d="M4.5 12.4V18M7 12.4V18M9.5 12.4V18M12 12.4V18M14.5 12.4V18M17 12.4V18M19.5 12.4V18"/><circle cx="5" cy="9.2" r="1.1"/><circle cx="8.2" cy="9.2" r="1.1"/><circle cx="11.4" cy="9.2" r="1.1"/><path d="M15 7.8v2.8M17.2 7.8v2.8M19.4 7.8v2.8"/>',
    ),
    32: dict(  # Synthesizer 2
        body='<rect x="3" y="2.6" width="18" height="18.8" rx="1.2"/>',
        cuts='<path d="M9 2.6v18.8M15 2.6v18.8"/><circle cx="6" cy="6" r="1.3"/><circle cx="6" cy="10.4" r="1.3"/><circle cx="12" cy="6" r="1.3"/><circle cx="18" cy="6" r="1.3"/><circle cx="18" cy="10.4" r="1.3"/><circle cx="6" cy="17.6" r=".6"/><circle cx="12" cy="13.6" r=".6"/><circle cx="18" cy="17.6" r=".6"/>',
        parts='<path d="M6 17.6c0 4.8 6 4.8 6-4M12 13.6c0 7.4 6 7.4 6 4"/>',
    ),
    33: dict(  # Synthesizer 3
        body='<rect x="2" y="7.4" width="20" height="10" rx="1.2"/>',
        cuts='<rect x="9.4" y="8.8" width="6" height="2.4" rx=".3"/><path d="M3.6 12.2v3.6M5.4 12.2v3.6"/><path d="M7.2 12.6h14.8"/><path d="M9.4 12.6v4.8M11.6 12.6v4.8M13.8 12.6v4.8M16 12.6v4.8M18.2 12.6v4.8M20.4 12.6v4.8"/><circle cx="18" cy="10" r=".9"/><circle cx="20.4" cy="10" r=".9"/>',
    ),
    34: dict(  # Keytar
        body='<rect x="1.6" y="9.4" width="14.6" height="5.2" rx="1.2"/><rect x="16.2" y="10.8" width="5.6" height="2.4" rx=".8"/>',
        cuts='<path d="M1.6 11.6h14.6"/><path d="M4 11.6v3M6.4 11.6v3M8.8 11.6v3M11.2 11.6v3M13.6 11.6v3"/><path d="M18 12h2.2"/>',
        rotate=-28,
        shift=(0.3, 0),
    ),
    35: dict(  # Trumpet
        body='<path d="M13.8 7.6c3.2 0 5.6-1.8 8.4-4.2v12c-2.8-2.4-5.2-4.2-8.4-4.2z"/><rect x="7.4" y="6" width="6.4" height="8.6" rx=".6"/>',
        cuts='<path d="M9.53 6v8.6M11.67 6v8.6"/><path d="M20.4 5v8.8"/>',
        parts='<path d="M1.6 7.9v2.6M1.6 9.2h5.8"/><path d="M7.4 13.6H5.2a1.9 1.9 0 0 0 0 3.8h8.6v-2.8"/><path d="M8.5 6V4.4M10.6 6V4.4M12.7 6V4.4M7.8 4.2h1.4M9.9 4.2h1.4M12 4.2h1.4"/>',
        shift=(0, 1.6),
    ),
    36: dict(  # Trombone
        body='<path d="M8.6 8C6 8 4 6.6 1.8 4.6v8.8C4 11.4 6 10 8.6 10z"/>',
        cuts='<path d="M3.4 6v6"/>',
        parts='<path d="M8.6 9h10.6a2.2 2.2 0 0 1 0 4.4"/><path d="M19.2 13.4H3.4a1.3 1.3 0 0 0 0 2.6H17"/><path d="M17 16h4.2M21.2 15v2"/><path d="M6.2 13.4V16M13.6 9v4.4"/>',
        shift=(0.4, 1.2),
    ),
    37: dict(  # Saxophone
        body='<path d="M8.3 5L7.4 16A5.2 5.2 0 0 0 17.8 16L18 11.8C18 9.8 19.6 8.4 21.4 7.4A4.82 1.3 -4.76 0 1 11.8 8.2C13 9 13.6 10 13.6 11.6L14 16A1.4 1.4 0 0 1 11.2 16L10.5 5z"/><ellipse cx="16.6" cy="7.8" rx="4.82" ry="1.3" transform="rotate(-4.76 16.6 7.8)"/><path d="M6 1.5L3.6 1.9a.55.55 0 0 0 0 1.1L6 3.1z"/>',
        cuts='<circle cx="9.38" cy="7.6" r=".7"/><circle cx="9.35" cy="10.2" r=".7"/><circle cx="9.33" cy="12.8" r=".7"/><circle cx="15.9" cy="14" r=".7"/>',
        parts='<path d="M9.4 5C9.4 3.2 8.2 2.3 6 2.3"/>',
        shift=(-0.3, 0),
    ),
    38: dict(  # Clarinet
        body='<rect x="10.9" y="4.4" width="2.2" height="14" rx=".5"/><path d="M10.9 18.4c0 1.8-1.6 2.6-1.6 3.8h5.4c0-1.2-1.6-2-1.6-3.8z"/>',
        cuts='<path d="M10.9 8.6h2.2M10.9 13.4h2.2"/><path d="M12 10.2v.1M12 11.6v.1M12 15v.1M12 16.6v.1"/>',
        parts='<path d="M11.4 4.4l.4-2.8h.6l.4 2.8"/>',
        rotate=35,
    ),
    39: dict(  # Violin
        body='<path d="M12 8.4c-2.5 0-3.6 1-3.6 2.6c0 1.1.8 1.5.8 2.4s-1.2 1.3-1.2 3.1c0 2 1.7 3.4 4 3.4s4-1.4 4-3.4c0-1.8-1.2-2.2-1.2-3.1s.8-1.3.8-2.4c0-1.6-1.1-2.6-3.6-2.6z"/>',
        cuts='<path d="M11.3 8.4v6.2M12.7 8.4v6.2"/><path d="M10.6 15h2.8"/><path d="M11.4 15.2l.6 3.2.6-3.2"/><path d="M9.7 13.2c-.3.5.3 1.2 0 1.9M14.3 13.2c-.3.5.3 1.2 0 1.9"/>',
        parts='<path d="M11.3 3.6v4.8M12.7 3.6v4.8"/><path d="M12 3.6c-1.1 0-1.6-.6-1.6-1.3S11 1 12 1"/>',
        rotate=40,
        shift=(-1, 0),
    ),
    40: dict(  # Cello
        body='<path d="M12 5.2c-3.3 0-4.8 1.3-4.8 3.3c0 1.4 1.3 2 1.3 3.2s-2 1.6-2 4.1c0 2.7 2.4 4.3 5.5 4.3s5.5-1.6 5.5-4.3c0-2.5-2-2.9-2-4.1s1.3-1.8 1.3-3.2c0-2-1.5-3.3-4.8-3.3z"/>',
        cuts='<path d="M11.3 5.2v8.4M12.7 5.2v8.4"/><path d="M10.4 14.4h3.2"/><path d="M11.2 14.6l.8 3.6.8-3.6"/><path d="M9.3 12.4c-.4.7.4 1.5 0 2.4M14.7 12.4c-.4.7.4 1.5 0 2.4"/>',
        parts='<path d="M11.3 3.4v1.8M12.7 3.4v1.8"/><path d="M12 3.4c-.9 0-1.3-.4-1.3-.9s.5-.8 1.3-.8"/><path d="M12 20.1v2"/>',
    ),
    41: dict(  # Male Vocal
        body='<circle cx="6" cy="6.4" r="3.4"/><path d="M3.8 9l1 11.4a1.2 1.2 0 0 0 2.4 0l1-11.4z"/>',
        cuts='<path d="M3 5.6h6M3.4 7.6h5.2M4.8 3.4c-.5 2-.5 4 0 6M7.2 3.4c.5 2 .5 4 0 6"/>',
        parts='<path d="M11.4 12L11.58 11.53L11.75 11.07L11.93 10.62L12.11 10.2L12.28 9.81L12.46 9.45L12.64 9.14L12.81 8.88L12.99 8.67L13.17 8.52L13.34 8.43L13.52 8.4L13.7 8.43L13.87 8.52L14.05 8.67L14.23 8.88L14.4 9.14L14.58 9.45L14.76 9.81L14.93 10.2L15.11 10.62L15.29 11.07L15.46 11.53L15.64 12L15.82 12.47L15.99 12.93L16.17 13.38L16.35 13.8L16.52 14.19L16.7 14.55L16.88 14.86L17.05 15.12L17.23 15.33L17.41 15.48L17.58 15.57L17.76 15.6L17.94 15.57L18.11 15.48L18.29 15.33L18.47 15.12L18.64 14.86L18.82 14.55L19 14.19L19.17 13.8L19.35 13.38L19.53 12.93L19.7 12.47L19.88 12L20.06 11.53L20.23 11.07L20.41 10.62L20.59 10.2L20.76 9.81L20.94 9.45L21.12 9.14L21.29 8.88L21.47 8.67L21.65 8.52L21.82 8.43L22 8.4"/>',
        shift=(-0.3, 0),
    ),
    42: dict(  # Female Vocal
        body='<circle cx="6" cy="6.4" r="3.4"/><path d="M3.8 9l1 11.4a1.2 1.2 0 0 0 2.4 0l1-11.4z"/>',
        cuts='<path d="M3 5.6h6M3.4 7.6h5.2M4.8 3.4c-.5 2-.5 4 0 6M7.2 3.4c.5 2 .5 4 0 6"/>',
        parts='<path d="M11.4 12L11.58 11.27L11.75 10.62L11.93 10.12L12.11 9.85L12.28 9.82L12.46 10.04L12.64 10.49L12.81 11.11L12.99 11.83L13.17 12.57L13.34 13.25L13.52 13.78L13.7 14.11L13.87 14.2L14.05 14.03L14.23 13.63L14.4 13.05L14.58 12.34L14.76 11.6L14.93 10.9L15.11 10.33L15.29 9.95L15.46 9.8L15.64 9.91L15.82 10.25L15.99 10.8L16.17 11.49L16.35 12.23L16.52 12.95L16.7 13.56L16.88 13.99L17.05 14.19L17.23 14.14L17.41 13.85L17.58 13.34L17.76 12.68L17.94 11.94L18.11 11.21L18.29 10.57L18.47 10.09L18.64 9.84L18.82 9.83L19 10.07L19.17 10.53L19.35 11.16L19.53 11.88L19.7 12.62L19.88 13.29L20.06 13.81L20.23 14.13L20.41 14.19L20.59 14.01L20.76 13.6L20.94 13L21.12 12.29L21.29 11.54L21.47 10.85L21.65 10.29L21.82 9.93L22 9.8"/>',
        shift=(-0.3, 0),
    ),
    43: dict(  # Choir
        body='<circle cx="4.6" cy="12.6" r="2"/><path d="M1.8 19.4C1.8 17.45 3.03 16.2 4.6 16.2s2.8 1.25 2.8 3.2z"/><circle cx="19.4" cy="12.6" r="2"/><path d="M16.6 19.4C16.6 17.45 17.83 16.2 19.4 16.2s2.8 1.25 2.8 3.2z"/><circle cx="12" cy="13" r="2.6"/><path d="M8.4 21.6C8.4 18.79 9.98 17 12 17s3.6 1.79 3.6 4.6z"/>',
    ),
    44: dict(  # Hand Sign
        body='<path d="M8 21.6C7 20.4 6.6 18.6 6.6 16.6V5.6a1.3 1.3 0 0 1 2.6 0V11.2a1.35 1.35 0 0 1 2.7 0a1.35 1.35 0 0 1 2.7 0V7.4a1.3 1.3 0 0 1 2.6 0V15.4C17.2 19 15.6 21 14 21.6z"/>',
        cuts='<path d="M6.6 12.4h5a1.3 1.3 0 0 1 0 2.6h-5"/>',
    ),
    45: dict(  # Talk A
        body='<path d="M4 4h16a1.5 1.5 0 0 1 1.5 1.5v9.4A1.5 1.5 0 0 1 20 16.4H10.2L5.6 20.6v-4.2H4a1.5 1.5 0 0 1-1.5-1.5V5.5A1.5 1.5 0 0 1 4 4z"/>',
        cuts='<path d="M9.4 13.6l2.6-6.6 2.6 6.6M10.4 11.2h3.2"/>',
    ),
    46: dict(  # Talk B
        body='<path d="M4 4h16a1.5 1.5 0 0 1 1.5 1.5v9.4A1.5 1.5 0 0 1 20 16.4H10.2L5.6 20.6v-4.2H4a1.5 1.5 0 0 1-1.5-1.5V5.5A1.5 1.5 0 0 1 4 4z"/>',
        cuts='<path d="M10.2 7h2.4a1.6 1.6 0 0 1 0 3.2h-2.4zM10.2 10.2h2.8a1.7 1.7 0 0 1 0 3.4h-2.8z"/>',
    ),
    47: dict(  # Large Diaphragm Mic
        body='<rect x="7.8" y="1.6" width="8.4" height="9.6" rx="4.2"/><rect x="9" y="11.8" width="6" height="4.4" rx=".8"/>',
        cuts='<path d="M10 2.91V9.89"/><path d="M12 2.4V10.4"/><path d="M14 2.91V9.89"/><path d="M8.6 6.4H15.4"/>',
        parts='<path d="M6.4 8.8v3.4a5.6 5.6 0 0 0 11.2 0V8.8"/><path d="M12 17.8v3.8M8.8 21.6h6.4"/>',
    ),
    48: dict(  # Condenser Mic Left
        body='<rect x="10.6" y="2.4" width="2.8" height="13.4" rx="1.2"/>',
        cuts='<path d="M10.6 5.4h2.8M10.6 12.4h2.8"/>',
        fixed='<path d="M14.18 15.11L13 16.8V21.6M9.8 21.6h6.4"/>',
        rotate=-35,
        shift=(1.2, 0),
    ),
    49: dict(  # Condenser Mic Right
        body='<rect x="10.6" y="2.4" width="2.8" height="13.4" rx="1.2"/>',
        cuts='<path d="M10.6 5.4h2.8M10.6 12.4h2.8"/>',
        fixed='<path d="M9.82 15.11L11 16.8V21.6M7.8 21.6h6.4"/>',
        rotate=35,
        shift=(-1.2, 0),
    ),
    50: dict(  # Handheld Mic
        body='<circle cx="12" cy="6.2" r="4"/><path d="M9.4 10.4l1.2 10.8a1.4 1.4 0 0 0 2.8 0l1.2-10.8z"/>',
        cuts='<path d="M8.4 5.2h7.2M8.8 7.6h6.4M10.4 2.6c-.6 2.4-.6 4.8 0 7.2M13.6 2.6c.6 2.4.6 4.8 0 7.2"/><path d="M9.6 12.6h4.8"/>',
        shift=(0, -0.6),
    ),
    51: dict(  # Wireless Mic
        body='<circle cx="12" cy="6.2" r="4"/><path d="M9.4 10.4l1 7.8h3.2l1-7.8z"/>',
        cuts='<path d="M8.4 5.2h7.2M8.8 7.6h6.4M10.4 2.6c-.6 2.4-.6 4.8 0 7.2M13.6 2.6c.6 2.4.6 4.8 0 7.2"/><path d="M10.4 15.4h3.2"/>',
        parts='<path d="M12 18.2v3.6"/><path d="M16.4 15.2a3.4 3.4 0 0 1 0 4.4M18.6 13.4a6.2 6.2 0 0 1 0 8"/>',
        shift=(-2, 0),
    ),
    52: dict(  # Podium Mic
        body='<path d="M4.6 10h14.8l-1.4 2H6z"/><path d="M6.6 12h10.8l-2 9.6H8.6z"/>',
        cuts='<path d="M8.11 15.4H15.89"/>',
        parts='<path d="M15.6 10c0-3.6-1.4-5.6-4.2-6.2"/><rect x="8.4" y="2" width="3.4" height="2.4" rx="1.2"/>',
    ),
    53: dict(  # Headset Mic
        body='<rect x="3.2" y="11" width="3.6" height="6" rx="1.4"/><rect x="17.2" y="11" width="3.6" height="6" rx="1.4"/>',
        parts='<path d="M5 11a7 7 0 0 1 14 0"/><path d="M5 17c0 2.8 2.2 4.4 5.4 4.6"/><rect x="10.4" y="20.4" width="2.8" height="2" rx="1"/>',
        shift=(0, -0.8),
    ),
    54: dict(  # XLR Jack
        body='<rect x="3" y="3" width="18" height="18" rx="3"/>',
        cuts='<circle cx="12" cy="12.4" r="6.2"/><circle cx="9.4" cy="11" r="1"/><circle cx="14.6" cy="11" r="1"/><circle cx="12" cy="15.4" r="1"/><path d="M11 6.2h2"/><circle cx="5.4" cy="5.4" r=".5"/><circle cx="18.6" cy="18.6" r=".5"/>',
    ),
    55: dict(  # TRS Plug
        body='<rect x="2" y="9.2" width="9.6" height="5.6" rx="1.2"/><path d="M11.6 10.6h8.6a1.4 1.4 0 0 1 0 2.8h-8.6z"/>',
        cuts='<path d="M4.6 10.4v3.2M6.4 10.4v3.2M8.2 10.4v3.2M15.4 10.6v2.8M18 10.6v2.8"/>',
        parts='<path d="M2 12H1.2"/>',
        shift=(0.6, 0),
    ),
    56: dict(  # TRS Plug Left
        body='<rect x="2" y="12.6" width="9.6" height="5.6" rx="1.2"/><path d="M11.6 14h8.6a1.4 1.4 0 0 1 0 2.8h-8.6z"/>',
        cuts='<path d="M4.6 13.8v3.2M6.4 13.8v3.2M8.2 13.8v3.2M15.4 14v2.8M18 14v2.8"/>',
        parts='<path d="M2 15.4H1.2"/><path d="M3.4 3.4v5h2.6"/>',
        shift=(0.6, 1.2),
    ),
    57: dict(  # TRS Plug Right
        body='<rect x="2" y="12.6" width="9.6" height="5.6" rx="1.2"/><path d="M11.6 14h8.6a1.4 1.4 0 0 1 0 2.8h-8.6z"/>',
        cuts='<path d="M4.6 13.8v3.2M6.4 13.8v3.2M8.2 13.8v3.2M15.4 14v2.8M18 14v2.8"/>',
        parts='<path d="M2 15.4H1.2"/><path d="M3.4 8.4v-5h1.9a1.45 1.45 0 0 1 0 2.9H3.4m1.9 0l1.6 2.1"/>',
        shift=(0.6, 1.2),
    ),
    58: dict(  # RCA Plug Left
        body='<rect x="2" y="12.6" width="8.6" height="5.6" rx="1.2"/><rect x="10.6" y="13.2" width="5.8" height="4.4" rx=".5"/>',
        cuts='<path d="M4.4 13.8v3.2M6.2 13.8v3.2M11.4 14.7h4.4M11.4 16.1h4.4"/>',
        parts='<path d="M16.4 15.4h4.8M2 15.4H1.2"/><path d="M3.4 3.4v5h2.6"/>',
        shift=(0.8, 1.2),
    ),
    59: dict(  # RCA Plug Right
        body='<rect x="2" y="12.6" width="8.6" height="5.6" rx="1.2"/><rect x="10.6" y="13.2" width="5.8" height="4.4" rx=".5"/>',
        cuts='<path d="M4.4 13.8v3.2M6.2 13.8v3.2M11.4 14.7h4.4M11.4 16.1h4.4"/>',
        parts='<path d="M16.4 15.4h4.8M2 15.4H1.2"/><path d="M3.4 8.4v-5h1.9a1.45 1.45 0 0 1 0 2.9H3.4m1.9 0l1.6 2.1"/>',
        shift=(0.8, 1.2),
    ),
    60: dict(  # Reel to Reel
        body='<circle cx="7" cy="7.2" r="4.4"/><circle cx="17" cy="7.2" r="4.4"/><rect x="2.4" y="13.4" width="19.2" height="8.2" rx="1.2"/><rect x="10.4" y="12.2" width="3.2" height="1.2" rx=".3"/>',
        cuts='<circle cx="7" cy="7.2" r="1.1"/><circle cx="17" cy="7.2" r="1.1"/><path d="M7 3.8v1.6M4.2 8.8l1.4-.8M9.8 8.8l-1.4-.8M17 3.8v1.6M14.2 8.8l1.4-.8M19.8 8.8l-1.4-.8"/><circle cx="5" cy="18.4" r=".7"/><circle cx="7.4" cy="18.4" r=".7"/><circle cx="9.8" cy="18.4" r=".7"/><path d="M14 18.4h5"/>',
        parts='<path d="M6.31 11.55L10.4 12.2M17.69 11.55L13.6 12.2"/>',
    ),
    61: dict(  # FX
        body='<path d="M10 2.8l1.7 5.5L17.2 10l-5.5 1.7L10 17.2l-1.7-5.5L2.8 10l5.5-1.7z"/><path d="M17.6 13.6l.9 2.7 2.7.9-2.7.9-.9 2.7-.9-2.7-2.7-.9 2.7-.9z"/>',
        parts='<path d="M18.6 3v3M17.1 4.5h3"/>',
    ),
    62: dict(  # Computer
        body='<rect x="4" y="4" width="16" height="11.6" rx="1.2"/><path d="M2 17.4h20l-1 2.6H3z"/>',
        cuts='<path d="M6.4 9.8h1.2l1-2.4 1.2 5 1.2-3.8 1 1.8 1-1.2 1.2 3.4 1.2-4.4 1 2.4h1.2"/>',
    ),
    63: dict(  # Monitor Wedge
        body='<path d="M5.4 6.6h13.2l2.6 10.8H2.8z"/><rect x="2.8" y="17.4" width="18.4" height="3.6" rx=".6"/>',
        cuts='<ellipse cx="12" cy="13" rx="4.2" ry="3"/><circle cx="12" cy="13" r=".9"/><rect x="10.4" y="7.8" width="3.2" height="1.4" rx=".3"/>',
        shift=(0, 0.6),
    ),
    64: dict(  # Left Speaker
        body='<rect x="8" y="2.5" width="12" height="19" rx="1.6"/>',
        cuts='<circle cx="14" cy="7.4" r="1.7"/><circle cx="14" cy="15" r="3.8"/><circle cx="14" cy="15" r="1.2"/>',
        parts='<path d="M3.8 9.5v5h2.6"/>',
        shift=(0.1, 0),
    ),
    65: dict(  # Right Speaker
        body='<rect x="4" y="2.5" width="12" height="19" rx="1.6"/>',
        cuts='<circle cx="10" cy="7.4" r="1.7"/><circle cx="10" cy="15" r="3.8"/><circle cx="10" cy="15" r="1.2"/>',
        parts='<path d="M17.6 14.5v-5h1.9a1.45 1.45 0 0 1 0 2.9H17.6m1.9 0l1.6 2.1"/>',
        shift=(-0.6, 0),
    ),
    66: dict(  # Speaker Array
        body='<rect transform="translate(5 3.4) rotate(0)" width="13.4" height="3.2" rx=".5"/><rect transform="translate(5 7.2) rotate(5)" width="13.4" height="3.2" rx=".5"/><rect transform="translate(4.67 10.99) rotate(12)" width="13.4" height="3.2" rx=".5"/><rect transform="translate(3.88 14.7) rotate(21)" width="13.4" height="3.2" rx=".5"/>',
        cuts='<path transform="translate(5 3.4) rotate(0)" d="M1.6 1.6H11.8"/><path transform="translate(5 7.2) rotate(5)" d="M1.6 1.6H11.8"/><path transform="translate(4.67 10.99) rotate(12)" d="M1.6 1.6H11.8"/><path transform="translate(3.88 14.7) rotate(21)" d="M1.6 1.6H11.8"/>',
        parts='<path d="M11.7 3.4V1.6M7.2 1.6h9"/>',
        shift=(1.4, -0.4),
    ),
    67: dict(  # Speaker on a Pole
        body='<rect x="6.6" y="2" width="10.8" height="11.4" rx="1.6"/>',
        cuts='<circle cx="12" cy="9.4" r="2.6"/><circle cx="12" cy="4.8" r=".9"/>',
        parts='<path d="M12 13.4V17.4M12 17.4l-5 4.2M12 17.4l5 4.2M12 17.4v4.2"/>',
    ),
    68: dict(  # Amp Rack
        body='<rect x="3" y="2.6" width="18" height="18.8" rx="1.2"/>',
        cuts='<path d="M3 8.8h18M3 15.2h18"/><path d="M5.2 4.4v2.6M18.8 4.4v2.6M5.2 10.6v2.8M18.8 10.6v2.8M5.2 17v2.6M18.8 17v2.6"/><circle cx="8.4" cy="5.7" r=".7"/><path d="M11 5.7h5.6"/><circle cx="8.4" cy="12" r=".7"/><path d="M11 12h5.6"/><circle cx="8.4" cy="18.3" r=".7"/><path d="M11 18.3h5.6"/>',
    ),
    69: dict(  # Controls
        body='<circle cx="7" cy="7" r="3.6"/><circle cx="17" cy="7" r="3.6"/><circle cx="7" cy="17" r="3.6"/><circle cx="17" cy="17" r="3.6"/>',
        cuts='<path d="M7 7L5 4.6M17 7l2.6-1M7 17l1.4 2.8M17 17h-3"/>',
    ),
    70: dict(  # Faders
        body='<rect x="3.8" y="12" width="4.4" height="3" rx=".7"/><rect x="9.8" y="5.4" width="4.4" height="3" rx=".7"/><rect x="15.8" y="15" width="4.4" height="3" rx=".7"/>',
        cuts='<path d="M4.4 13.5h3.2M10.4 6.9h3.2M16.4 16.5h3.2"/>',
        parts='<path d="M6 2.6V12M6 15v6.4M12 2.6v2.8M12 8.4v13M18 2.6V15M18 18v3.4"/>',
    ),
    71: dict(  # MixBus
        body='<circle cx="14.4" cy="12" r="3.2"/>',
        cuts='<path d="M14.4 10.4v3.2M12.8 12H16"/>',
        parts='<path d="M1.8 4.8c5.4 0 6.4 5.6 9.4 6.6M1.8 12h9.4M1.8 19.2c5.4 0 6.4-5.6 9.4-6.6"/><path d="M17.6 12h4.2M19.8 9.8L22 12l-2.2 2.2"/>',
    ),
    72: dict(  # Matrix
        parts='<path d="M2.6 5h18.8M2.6 9.7h18.8M2.6 14.3h18.8M2.6 19h18.8M5 2.6v18.8M9.7 2.6v18.8M14.3 2.6v18.8M19 2.6v18.8"/><circle cx="5" cy="5" r="1.7" fill="currentColor"/><circle cx="14.3" cy="9.7" r="1.7" fill="currentColor"/><circle cx="9.7" cy="14.3" r="1.7" fill="currentColor"/><circle cx="19" cy="19" r="1.7" fill="currentColor"/><circle cx="19" cy="5" r="1.7" fill="currentColor"/>',
    ),
    73: dict(  # Routing
        body='<rect x="2.4" y="4" width="4.4" height="4.4" rx="1"/><rect x="2.4" y="15.6" width="4.4" height="4.4" rx="1"/><rect x="17.2" y="4" width="4.4" height="4.4" rx="1"/><rect x="17.2" y="15.6" width="4.4" height="4.4" rx="1"/>',
        parts='<path d="M6.8 6.2c5.2 0 5.2 11.6 10.4 11.6M6.8 17.8c5.2 0 5.2-11.6 10.4-11.6"/>',
    ),
    74: dict(  # Smiley
        body='<circle cx="12" cy="12" r="9"/>',
        cuts='<path d="M9 9.4v1.4M15 9.4v1.4"/><path d="M8 14.2c2 2.6 6 2.6 8 0"/>',
    ),
}
