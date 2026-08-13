# proc is a function. this is used later to connect all the vdd! and vss! together.
proc connectGlobalNets {} {
	globalNetConnect vdd! -type pgpin -pin vdd! -all
	globalNetConnect vss! -type pgpin -pin vss! -all
	globalNetConnect vdd! -type tiehi -all
	globalNetConnect vss! -type tielo -all
	applyGlobalNets
}

# set the top level module name (used elsewhere in the scripts)
set design_toplevel cpu

# set the verilog file to pnr
set init_verilog ../synth/outputs/$design_toplevel.v

# set the lef file of your standard cells
# when you add your regfile lef, it is here
# if you want to supply more than one lef use the following syntax:
# set init_lef_file "1.lef 2.lef"
set init_lef_file "../stdcells.lef ../regfile.lef"
# actually set the top level cell name
set init_top_cell $design_toplevel

# set power and ground net names
set init_pwr_net vdd!
set init_gnd_net vss!

# set multi-mode multi-corner file
# this file contains the operating conditions used to evaluate timing
# for your design. In our case, we just use the single lib file as our corner.
# In ECE 498HK, this will contain slow, typical and fast corners
# for the wires and the standard cells
set init_mmmc_file mmmc.tcl

# actually init the design
init_design

# connect all the global nets in the design together (vdd!, vss!)
# the function is defined above.
connectGlobalNets

# TODO floorplan your design. Put the size of your chip that you want here.
floorPlan -site CoreSite -s 125 125 10 10 10 10

# create the horizontal vdd! and vss! wires used by the standard cells.
sroute -allowJogging 0 -allowLayerChange 0 -crossoverViaLayerRange { metal7 metal1 } -layerChangeRange { metal7 metal1 } -nets { vss! vdd! }

# create a power ring around your processor, connecting all the vss! and vdd! together physically.
addRing \
	-follow core \
	-offset {top 2 bottom 2 left 2 right 2} \
	-spacing {top 2 bottom 2 left 2 right 2} \
	-width {top 2 bottom 2 left 2 right 2} \
	-layer {top metal7 bottom metal7 left metal8 right metal8} \
	-nets { vss! vdd! }

# TODO add power grid
addStripe \
    -nets { vdd! vss! } \
    -layer metal6 \
    -direction vertical \
    -width 0.3 \
    -spacing 0.4 \
    -set_to_set_distance 100 \
    -start_offset 110 \
    -extend_to design_boundary



# TODO restrict routing to only metal 6
setDesignMode -bottomRoutingLayer metal1 -topRoutingLayer metal6

# TODO for the regfile part, place the regfile marco
# placeInstance ...
set regfile_insts [lsort [dbGet [dbGet top.insts.cell.name regfile -p2].name]]

set x0 20.0
set y0 12.8
set pitch_y 2.8

for {set i 0} {$i < 32} {incr i} {
    set inst [lindex $regfile_insts $i]
    set y [expr {$y0 + $i * $pitch_y}]
    placeInstance $inst $x0 $y R0 -fixed
}

# TODO specify where are the pins

# Inputs on left side, excluding clk/rst
set input_pins {}

for {set i 0} {$i <= 31} {incr i} {
    lappend input_pins "imem_rdata\[$i\]"
}

for {set i 0} {$i <= 31} {incr i} {
    lappend input_pins "dmem_rdata\[$i\]"
}

editPin \
    -spreadType SIDE \
    -side LEFT \
    -layer metal3 \
    -pin $input_pins


# Outputs on right side
set output_pins {}

for {set i 0} {$i <= 31} {incr i} {
    lappend output_pins "imem_addr\[$i\]"
}

for {set i 0} {$i <= 31} {incr i} {
    lappend output_pins "dmem_addr\[$i\]"
}

lappend output_pins dmem_write

for {set i 0} {$i <= 3} {incr i} {
    lappend output_pins "dmem_wmask\[$i\]"
}

for {set i 0} {$i <= 31} {incr i} {
    lappend output_pins "dmem_wdata\[$i\]"
}

editPin \
    -spreadType SIDE \
    -side RIGHT \
    -layer metal3 \
    -pin $output_pins


# Clock/reset on top
set top_pins {clk rst}

editPin \
    -spreadType SIDE \
    -side TOP \
    -layer metal3 \
    -pin $top_pins

# Fixing DFF DRC issue
specifyCellPad dff 30

# TODO uncomment the two below command to do pnr. These steps takes innovus more time.

# place all the standard cells in your design. This command is actually a series of many
# mini commands and settings, but it tries to optimally place the standard cells in your design
# considering area, timing, routing congestion, routing length, and other things.
# See "man place_design" to find out more.
place_design

routeDesign

connectGlobalNets

# TODO find the command that checks DRC
verify_drc -check_only all -report ../cpu2.drc.rpt

# save your design as a GDSII, which you can open in Virtuoso
# streamOut innovus.gdsii -mapFile "/class/ece425/innovus.map"

# save the design, so innovus can open it later
saveDesign $../cpu2
