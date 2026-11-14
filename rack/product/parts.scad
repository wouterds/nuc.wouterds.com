// One piece of the assembly at a time, in place, for product/render.sh.
// The NUC, the fan and the filter are rough stand-ins, modelled from photos.
include <../nuc-rack.scad>
piece = "body";
$fn = 96;

// what render.py needs to know to move the panels around, in mm
echo(dims = [D, panel_t, fan_y, z_tun, z_plen + panel_stop, z_seat - panel_stop, z_top]);
module at_fan() translate([0, wall + fan_clear + fan / 2, z_fan]) children();
module at_nuc() translate([0, nuc_y0, z_seat]) children();
module front(x, z, w, h, t = 0.6) translate([x - w / 2, nuc_d - 0.3, z]) cube([w, t, h]);
module rear(x, z, w, h, t = 0.6) translate([x - w / 2, 0.3 - t, z]) cube([w, t, h]);
if (piece == "body") body();
if (piece == "fan_panel") fan_panel();
if (piece == "nuc_panel") nuc_panel();
if (piece == "filter") translate([-60, wall + 0.5, z_fs + 0.4]) difference() { cube([120, 120, 2]); translate([9, 9, -1]) cube([102, 102, 4]); }
if (piece == "filter_mesh") translate([-51, wall + 9.5, z_fs + 1.2]) cube([102, 102, 0.3]);
if (piece == "fan_frame") at_fan() {
  difference() {
    linear_extrude(fan_t) offset(r = 6) square(fan - 12, center = true);
    translate([0, 0, -1]) cylinder(d = 114, h = fan_t + 2);
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * fan_hole_pitch / 2, sy * fan_hole_pitch / 2, -1]) cylinder(d = 4.3, h = fan_t + 2);
  }
  for (a = [0:90:359]) rotate(a + 20) translate([0, -2, fan_t - 5]) cube([58, 4, 3]);
}
if (piece == "fan_rotor") at_fan() {
  translate([0, 0, 3]) cylinder(d = 42, h = fan_t - 6);
  for (a = [0:40:359]) rotate(a) translate([19, 0, fan_t / 2]) rotate([28, 0, 12])
    translate([0, -9, -0.8]) cube([36, 20, 1.6]);
  for (sx = [-1, 1], sy = [-1, 1], z = [0, fan_t - 2])
    translate([sx * fan_hole_pitch / 2, sy * fan_hole_pitch / 2, z])
      difference() { cylinder(d = 11, h = 2); translate([0, 0, -1]) cylinder(d = 4.3, h = 4); }
}
if (piece == "nuc_body") at_nuc() {
  translate([-nuc_w / 2, 0, 2.5]) hull()
    for (x = [5, nuc_w - 5], y = [5, nuc_d - 5]) translate([x, y, 0]) cylinder(r = 5, h = nuc_h - 2.5);
  for (x = [-nuc_w / 2 + 9, nuc_w / 2 - 9], y = [9, nuc_d - 9]) translate([x, y, 0]) cylinder(d = 9, h = 2.5);
}
// connectors, as seen from the front: USB-C, two USB-A; at the rear: power, HDMI, LAN, USB, Thunderbolt
if (piece == "nuc_metal") at_nuc() {
  front(11, 17.5, 9, 3.2);
  for (x = [-4, -20]) front(x, 16.5, 13.5, 5.6);
  for (x = [-31, 33]) { rear(x, 9, 15, 6); rear(x, 19, 9, 3.2); }
  rear(-8, 8, 16, 13.5);
  for (z = [8, 16]) rear(13, z, 13.5, 5.6);
  translate([-46, 0.3, 12.5]) rotate([90, 0, 0]) cylinder(d = 7, h = 0.6);
}
if (piece == "nuc_blue") at_nuc() {
  for (x = [-4, -20]) front(x, 18, 11, 1.6, 0.9);
  rear(13, 17.5, 11, 1.6, 0.9);
}
if (piece == "nuc_dark") at_nuc() {
  rear(13, 9.5, 11, 1.6, 0.9);
  rear(-8, 10, 12.5, 9, 0.9);
  for (x = [-31, 33]) rear(x, 10.5, 12, 2.5, 0.9);
  translate([-46, 0.3, 12.5]) rotate([90, 0, 0]) cylinder(d = 4, h = 0.9);
  // power button and vents
  front(-38, 14.5, 12, 8, 0.5);
  for (i = [0:13]) rear(-41 + i * 6.3, 25, 3.2, 7.5, 0.4);
}
if (piece == "nuc_led") at_nuc() translate([-38, nuc_d - 0.3, 18.5]) rotate([-90, 0, 0]) cylinder(d = 2.4, h = 0.7);
// what is left after the walls and the top/bottom layers: the parts that get infill
if (piece == "core") intersection_for(v = [[1.7, 0, 0], [-1.7, 0, 0], [0, 0.8, 0], [0, -0.8, 0], [0, 0, 1.7], [0, 0, -1.7]])
  translate(v) body();
