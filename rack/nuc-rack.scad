// Mini rack for an ASUS NUC 14 Pro slim + one 120 mm fan (Noctua NF-A12x25 5V)
//
// Three printed parts, no supports, no hardware:
//   body      - print standing on its rear face
//   fan-panel - print front face down, clicks into the front over the fan and intake
//   nuc-panel - print front face down, clicks into the front over the NUC
//
// Airflow: fan sits under the NUC and blows up into a plenum. The NUC stands on
// a frame with a large opening, so the air hits its underside, then escapes
// through the slots beside it, up both sides of the NUC (past its side vents),
// over the lid and out through the top grille.
//
// Coordinates: X = width (centred), Y = depth (0 = rear, D = front), Z = up.

part = "assembly"; // assembly | exploded | section | print | body | fan-panel | nuc-panel

/* [NUC] */
nuc_w = 117;
nuc_d = 112;
nuc_h = 37;             // including rubber feet
nuc_side_clear = 0.75;  // per side
nuc_h_slack = 1.5;
nuc_top_gap = 5;        // air gap above the lid

/* [Fan] */
fan = 120;
fan_t = 25;             // bare frame; 27 with the anti-vibration pads, which have to come off
fan_clear = 0.3;        // per side; fits the bare frame, the rubber pads would jam
fan_hole_pitch = 105;
fan_hole_d = 4.4;
top_fan_holes = false;  // screw holes in the top grille for a second 120 mm fan

/* [Rack] */
wall = 2.4;
side_gap = 10;          // air channel between NUC side and wall
floor_t = 2.4;
top_t = 2.4;
tunnel_h = 10;          // intake tunnel under the fan
ledge_t = 2;
ledge_w = 4.5;
filter_slot = 2.8;      // slide-in slot for a flat 120 mm dust filter, 2 mm thick
plenum_h = 10;
rail_t = 3;
seat_side = 4;          // how far the seat reaches under the NUC along its sides
seat_bar = 11;          // depth of the bar across the front; the one at the rear mirrors it
seat_corner = 24;       // corner cut of the opening, leaves a pad under each foot (9 mm in from the NUC's edges)
corner_r = 3;
hex_af = 4;             // mesh hole size, across flats
hex_web = 1.2;          // material between the holes
ear_hole = 4.5;
ear_hole_pitch = 9;
louvre_n = 6;           // angled exhaust vents in each side wall, 0 for none
louvre_h = 2.5;         // slot height, also used for the intake slots
louvre_pitch = 5.5;
vent_margin = 13;       // solid wall left at the front and rear of the side vents
vent_cols = 3;          // side vents are split into this many columns
vent_pillar = 5;        // solid wall between the columns

/* [Front panels] */
panel_t = 3;
panel_clear = 0.25;
panel_frame = 5.5;      // solid border around the mesh
bump = 0.8;             // snap bump height
snap_preload = 0.2;     // how far the snap fingers stay bent once a panel is seated
panel_stop = 2;         // lip behind the top and bottom edge of the panels

/* [Hidden] */
e = 0.01;
$fn = 48;

in_w = nuc_w + 2 * side_gap;
out_w = in_w + 2 * wall;
pocket = fan + 2 * fan_clear;
D = wall + pocket + panel_t;
snap_w = panel_t / 2 - 0.4;  // half width of the snap bumps
snap_shift = (panel_clear + snap_preload) * snap_w / bump;  // the grooves sit this far behind the bumps
ear_t = panel_t + 1;
fan_y = wall + pocket / 2;                 // centre of the fan
seat_a = nuc_w / 2 - seat_side;            // half width of the opening in the seat
seat_b = D - seat_bar - fan_y;             // half depth

z_tun = floor_t;
z_fl = z_tun + tunnel_h;       // filter ledge
z_fs = z_fl + ledge_t;         // filter slot
z_fanl = z_fs + filter_slot;   // fan ledge
z_fan = z_fanl + ledge_t;      // fan seat
z_plen = z_fan + fan_t + 0.6;
z_rail = z_plen + plenum_h;
z_seat = z_rail + rail_t;      // NUC seat
bay_h = nuc_h + nuc_h_slack + nuc_top_gap;
z_top = z_seat + bay_h;
H = z_top + top_t;

nuc_y0 = wall + (pocket - nuc_d) / 2;  // centred above the fan

echo(str("outer size (w x d x h): ", out_w, " x ", D, " x ", H));

// ---------- helpers ----------

module sym() {
  children();
  mirror([1, 0, 0]) children();
}

// extrude a 2D shape drawn in (X, Z) from y0 to y1
module ext(y0, y1) {
  translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0, convexity = 10) children();
}

module rrect(w, h, r) {
  translate([r, r]) offset(r = r) square([w - 2 * r, h - 2 * r]);
}

// ---------- body ----------

module body_profile() {
  difference() {
    translate([-out_w / 2, 0]) rrect(out_w, H, corner_r);
    translate([-pocket / 2, z_tun]) square([pocket, z_plen - z_tun + e]);
    translate([-in_w / 2, z_plen]) square([in_w, z_top - z_plen]);
  }
  sym() {
    for (z = [z_fl, z_fanl])
      translate([pocket / 2 - ledge_w, z]) square([ledge_w + e, ledge_t]);
  }
}

module rail_windows() {
  x0 = nuc_w / 2 + 1.5;
  y0 = 6;
  y1 = D - 13;
  n = 4;
  pillar = 6;
  len = (y1 - y0 - (n - 1) * pillar) / n;
  for (i = [0:n - 1])
    translate([x0, y0 + i * (len + pillar), z_rail - e])
      cube([in_w / 2 - x0, len, rail_t + 2 * e]);
}

// hex holes filling w x d, leaving out any that come near a keepout circle [x, y, r]
module hex_grid(w, d, keepout = []) {
  af = hex_af;
  s = af + hex_web;
  r = af / sqrt(3);
  nx = ceil(w / (s * 0.866));
  ny = ceil(d / s);
  for (i = [-nx:nx], j = [-ny:ny]) {
    x = i * s * 0.866;
    y = j * s + (abs(i) % 2 == 1 ? s / 2 : 0);
    clear = len([for (k = keepout) if (norm([x - k[0], y - k[1]]) <= k[2] + r) 1]) == 0;
    if (abs(x) + r <= w / 2 && abs(y) + af / 2 <= d / 2 && clear)
      translate([x, y]) circle(r = r, $fn = 6);
  }
}

module ear() {
  x0 = nuc_w / 2 + nuc_side_clear;
  x1 = in_w / 2 + e;
  n = floor((bay_h - 8) / ear_hole_pitch);
  first = (bay_h - (n - 1) * ear_hole_pitch) / 2;
  difference() {
    translate([0, 0, z_seat - e]) linear_extrude(bay_h + 2 * e)
      polygon([[x1, D], [x0, D], [x0, D - ear_t], [x1, D - ear_t - (x1 - x0)]]);
    for (i = [0:n - 1])
      translate([(x0 + x1) / 2 - ear_hole / 2, D - 20, z_seat + first + i * ear_hole_pitch - ear_hole / 2])
        cube([ear_hole, 21, ear_hole]);
  }
  // rib that reaches back past the NUC's front corner and keeps it centred, grows out of the rail at 45°
  y0 = nuc_y0 + nuc_d - 10;
  y1 = D - ear_t + e;
  h = 8;
  translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(1.6)
    polygon([[y0 - h, z_seat - e], [y0, z_seat + h], [y1, z_seat + h], [y1, z_seat - e]]);
}

module rear_stop() {
  x0 = nuc_w / 2 + nuc_side_clear;
  // closes the rear of the side channel
  translate([x0, 0, z_seat - e]) cube([in_w / 2 - x0 + e, 2, bay_h + 2 * e]);
  // stop for the NUC's rear corner
  translate([nuc_w / 2 - 5.5, 0, z_seat - e]) cube([x0 - nuc_w / 2 + 7.5, nuc_y0, 6]);
  // lateral guide with lead-in
  translate([0, 0, z_seat - e]) linear_extrude(10)
    polygon([[x0, 0], [x0 + 2.5, 0], [x0 + 2.5, nuc_y0 + 14], [x0, nuc_y0 + 10]]);
}

function louvre_z(i) = z_top - 4 - wall - louvre_h - i * louvre_pitch;

module side_vents() {
  xi = in_w / 2 - e;
  xo = out_w / 2 + e;
  intake_web = 2.4;
  intake_pitch = louvre_h + intake_web;
  intake_n = floor((tunnel_h - 1 + intake_web) / intake_pitch);
  len = (D - 2 * vent_margin - (vent_cols - 1) * vent_pillar) / vent_cols;
  for (c = [0:vent_cols - 1]) ext(vent_margin + c * (len + vent_pillar), vent_margin + c * (len + vent_pillar) + len) {
    // exhaust: slopes up towards the outside at 45°, stacked down from the top
    if (louvre_n > 0) for (i = [0:louvre_n - 1]) {
      z = louvre_z(i);
      polygon([[xi, z - e], [xo, z + wall + e], [xo, z + wall + e + louvre_h], [xi, z - e + louvre_h]]);
    }
    // intake: straight into the tunnel under the fan
    for (i = [0:intake_n - 1])
      translate([pocket / 2 - e, z_tun + 1 + i * intake_pitch]) square([xo - pocket / 2 + e, louvre_h]);
  }
}

// what the NUC stands on: a frame around an eight-sided opening that is centred on the fan
module seat() {
  a = seat_a;
  b = seat_b;
  c = seat_corner;
  translate([0, 0, z_rail]) linear_extrude(rail_t) difference() {
    translate([-in_w / 2 - e, 0]) square([in_w + 2 * e, D]);
    translate([0, fan_y]) polygon([[a, c - b], [a, b - c], [a - c, b], [c - a, b], [-a, b - c], [-a, c - b], [c - a, -b], [a - c, -b]]);
  }
}

// closes the front of the plenum under the seat. It hangs from the seat at 45° and follows the
// corner cuts of the opening, so it prints without supports.
module front_closure() {
  s_side = D - panel_t - panel_stop - plenum_h;      // under the pads: flat behind the fan panel
  s_mid = D - seat_bar + 2;                          // under the thin part of the bar
  s_cut = fan_y + seat_a + seat_b - seat_corner + 2; // under the corner cuts, at x = 0
  assert(s_mid + plenum_h - panel_stop <= D - 1, "seat_bar is too thin to close the plenum");
  module ramp(s) polygon([[s, z_rail + e], [2 * D, z_rail + e], [2 * D, z_plen], [s + plenum_h, z_plen]]);
  module across(x0, x1) translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(x1 - x0) children();
  w = in_w / 2 + e;
  intersection() {
    translate([-w, 0, z_plen]) cube([2 * w, D, plenum_h + e]);
    union() {
      across(-w, w) ramp(s_mid);
      intersection() {
        across(-w, w) ramp(s_side);
        // sheared, so the ramp starts 1 mm later for every mm towards the middle
        sym() multmatrix([[1, 0, 0, 0], [-1, 1, 0, 0], [0, 0, 1, 0]]) across(0, w) ramp(s_cut);
      }
    }
  }
}

// hollows out the wall beside the fan; the front end closes at 45°, so it prints without supports
module wall_cavity(x0, y0, z0, z1) {
  x1 = in_w / 2;
  y1 = D - panel_t - 2;
  translate([0, 0, z0]) linear_extrude(z1 - z0)
    polygon([[x0, y0], [x1, y0], [x1, y1 - (x1 - x0)], [x0, y1]]);
}

// V groove the snap bumps click into. It sits a bit behind the bumps, so they end up on its front
// flank and keep pulling the panel against its stops.
module detent(h) {
  linear_extrude(h) polygon([[0, -panel_t / 2], [bump, -snap_shift], [0, snap_w - snap_shift]]);
}

// lip a panel edge rests against, 45° on its rear side so it prints without supports
module stop_lip(w, z, dir) {
  yb = D - panel_t;
  s = panel_stop;
  translate([-w / 2 - e, 0, 0]) rotate([90, 0, 90]) linear_extrude(w + 2 * e)
    polygon([[yb - 2 * s, z - dir * e], [yb - s, z + dir * s], [yb, z + dir * s], [yb, z - dir * e]]);
}

module shell() {
  difference() {
    union() {
      ext(0, D) body_profile();
      seat();
      // rear wall of filter slot, fan bay and plenum
      ext(0, wall) translate([-in_w / 2 - e, z_fl]) square([in_w + 2 * e, z_seat - z_fl]);
    }
    sym() {
      rail_windows();
      side_vents();
      // tunnel runs the full inner width, the wall next to the fan is a hollow box
      wall_cavity(pocket / 2 - e, -e, z_tun, z_fl);
      wall_cavity(pocket / 2 + ledge_t, wall, z_fan, z_plen - ledge_t);
      translate([pocket / 2 - e, D - panel_t / 2, z_tun]) detent(z_plen - z_tun);
      // fan cable exit, one per rear corner
      translate([pocket / 2 - 26, -e, z_fan + 3]) cube([22, wall + 2 * e, 18]);
    }
    // seat for the fan panel
    translate([-pocket / 2, D - panel_t, z_tun]) cube([pocket, panel_t + e, z_plen - z_tun]);
    // top grille, optionally with mounting holes for a second fan
    translate([0, D / 2, z_top - e]) linear_extrude(top_t + 2 * e) {
      holes = top_fan_holes
        ? [for (sx = [-1, 1], sy = [-1, 1]) [sx * fan_hole_pitch / 2, sy * fan_hole_pitch / 2]] : [];
      hex_grid(in_w - 6, D - 14, [for (h = holes) [h[0], h[1], 6]]);
      for (h = holes) translate(h) circle(d = fan_hole_d);
    }
  }
}

module body() {
  x0 = nuc_w / 2 + nuc_side_clear;
  yb = D - panel_t;
  s = panel_stop;
  difference() {
    union() {
      shell();
      sym() {
        ear();
        rear_stop();
      }
      front_closure();
      stop_lip(2 * x0, z_top, -1);
      stop_lip(pocket, z_tun, 1);
    }
    // the other edge of each panel sits in a rebate in the sill between them
    translate([-x0, yb, z_seat - s]) cube([2 * x0, panel_t + e, s + e]);
    translate([-pocket / 2, yb, z_plen - e]) cube([pocket, panel_t + e, s + e]);
    sym() translate([x0 - e, D - panel_t / 2, z_seat]) detent(bay_h);
  }
}

// ---------- front panels ----------

// mesh plate with four snap fingers and a finger pull, fills an opening w0 wide from z0 to z1
module snap_panel(w0, z0, z1) {
  c = panel_clear;
  pull = 5 + panel_stop;  // the stop covers the lowest part of the notch
  w = w0 - 2 * c;
  h = z1 - z0 - 2 * c;
  finger = 18;
  ext(D - panel_t, D) translate([0, z0 + c + h / 2]) difference() {
    square([w, h], center = true);
    hex_grid(w - 2 * panel_frame, h - 2 * panel_frame, [[0, -h / 2, pull + 8]]);
    // slots that free the snap fingers
    sym() for (s = [-1, 1]) translate([w / 2 - 2.4, s * (h - finger) / 2])
      square([1.2, finger + e], center = true);
    translate([0, -h / 2]) square([20, 2 * pull], center = true);
  }
  sym() for (z = [z0 + c + 2.3, z1 - c - 9.3])
    translate([w / 2 - e, D - panel_t / 2, z]) linear_extrude(7) polygon([[0, -snap_w], [bump, 0], [0, snap_w]]);
}

module fan_panel() snap_panel(pocket, z_tun, z_plen + panel_stop);
module nuc_panel() snap_panel(nuc_w + 2 * nuc_side_clear, z_seat - panel_stop, z_top);

// ---------- dummies (visualisation only) ----------

module fan_dummy() {
  beige = "#e7dcc3";
  brown = "#6b3a2a";
  translate([0, wall + fan_clear + fan / 2, z_fan]) {
    color(beige) difference() {
      linear_extrude(fan_t) offset(r = 6) square(fan - 12, center = true);
      translate([0, 0, -1]) cylinder(d = 114, h = fan_t + 2);
      for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * fan_hole_pitch / 2, sy * fan_hole_pitch / 2, -1]) cylinder(d = 4.3, h = fan_t + 2);
    }
    color(brown) {
      translate([0, 0, 3]) cylinder(d = 42, h = fan_t - 6);
      for (a = [0:40:359]) rotate(a) translate([19, 0, fan_t / 2]) rotate([28, 0, 12])
        translate([0, -9, -0.8]) cube([36, 20, 1.6]);
      for (sx = [-1, 1], sy = [-1, 1], z = [0, fan_t - 2])
        translate([sx * fan_hole_pitch / 2, sy * fan_hole_pitch / 2, z])
          difference() { cylinder(d = 11, h = 2); translate([0, 0, -1]) cylinder(d = 4.3, h = 4); }
    }
    color(beige) for (a = [0:90:359]) rotate(a + 20) translate([0, -2, 2]) cube([58, 4, 3]);
  }
}

module nuc_dummy() {
  feet = 2.5;
  translate([0, nuc_y0, z_seat]) {
    color("#17181b") translate([-nuc_w / 2, 0, feet]) hull()
      for (x = [5, nuc_w - 5], y = [5, nuc_d - 5]) translate([x, y, 0]) cylinder(r = 5, h = nuc_h - feet);
    color("#0b0b0c") for (x = [-nuc_w / 2 + 9, nuc_w / 2 - 9], y = [9, nuc_d - 9])
      translate([x, y, 0]) cylinder(d = 9, h = feet);
    // front I/O
    color("#3d6fd6") for (x = [18, 34]) translate([x - 6.5, nuc_d - 0.5, 16]) cube([13, 1, 5.5]);
    color("#8a8d93") {
      for (x = [-2]) translate([x - 4.5, nuc_d - 0.5, 17]) cube([9, 1, 3.5]);
      translate([-40, nuc_d - 0.5, 19]) rotate([-90, 0, 0]) cylinder(d = 9, h = 1);
      // rear I/O
      for (x = [-44, -24, -6, 12, 30, 44]) translate([x - 7, -0.5, 14]) cube([14, 1, 12]);
    }
  }
}

module filter_dummy() {
  color("#9aa0a6", 0.9) translate([-60, wall + 0.5, z_fs + 0.6]) cube([120, 120, 1.5]);
}

body_col = "#3b3f46";

// ---------- output ----------

module print_body() translate([0, H, 0]) rotate([90, 0, 0]) body();
module print_fan_panel() translate([0, -z_tun, D]) rotate([-90, 0, 0]) fan_panel();
module print_nuc_panel() translate([0, -z_seat + panel_stop, D]) rotate([-90, 0, 0]) nuc_panel();

// front half removed, to show the inside
module cut() {
  difference() {
    children();
    translate([-200, cut_y, -50]) cube([400, 400, 400]);
  }
}

module arrow2d(pts, w = 2.6) {
  n = len(pts);
  for (i = [0:n - 2]) hull() {
    translate(pts[i]) circle(d = w);
    translate(pts[i + 1]) circle(d = w);
  }
  a = pts[n - 2];
  b = pts[n - 1];
  translate(b) rotate(atan2(b[1] - a[1], b[0] - a[0])) polygon([[0, -4.5], [8, 0], [0, 4.5]]);
}

cut_y = D * 0.55;

// STLs come out in print orientation
if (part == "body") print_body();
if (part == "fan-panel") print_fan_panel();
if (part == "nuc-panel") print_nuc_panel();

if (part == "print") color(body_col) {
  print_body();
  translate([0, H + 12, 0]) print_fan_panel();
  translate([0, H + 72, 0]) print_nuc_panel();
}

if (part == "assembly") {
  color(body_col) body();
  color(body_col) fan_panel();
  color(body_col) nuc_panel();
  fan_dummy();
  nuc_dummy();
  filter_dummy();
}

if (part == "exploded") {
  color(body_col) body();
  translate([0, 205, 0]) color(body_col) {
    fan_panel();
    nuc_panel();
  }
  translate([0, 150, 0]) fan_dummy();
  translate([0, 145, 0]) nuc_dummy();
  translate([0, 75, 0]) filter_dummy();
}

if (part == "section") {
  color(body_col) cut() body();
  color("#e7dcc3") cut() fan_dummy();
  color("#17181b") cut() nuc_dummy();
  color("#9aa0a6") cut() filter_dummy();
  zp = z_plen + plenum_h / 2;
  zt = z_top - (nuc_h_slack + nuc_top_gap) / 2;
  xc = (nuc_w / 2 + in_w / 2) / 2 + 0.6;
  color("#2f8fff") ext(cut_y, cut_y + 1.5) sym()
    arrow2d([[22, z_tun + 4], [22, z_plen + 2]]);
  color("#ff7a1a") ext(cut_y, cut_y + 1.5) sym()
    arrow2d([[30, zp], [xc, zp], [xc, zt], [46, zt], [46, H + 12]]);
}
