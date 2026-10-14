set root [file dirname [file normalize [info script]]]
cd $root
file mkdir "$root/build"
file delete -force "$root/build/SUCCESS"
if {[catch {
    import_device eagle_s20.db -package EG4S20BG256
    open_project "$root/campus_terminal.al"
    elaborate -top top
    read_adc "$root/campus_terminal.adc"
    read_sdc "$root/campus_terminal.sdc"
    cd "$root/build"
    optimize_rtl
    optimize_gate
    legalize_phy_inst
    set_param place seed 1
    export_db mapped.db
    place
    route
    update_timing
    report_area -io_info -file campus_terminal_area.rpt
    report_timing_summary -file campus_terminal_timing.rpt
    report_timing_status -file campus_terminal_timing_status.rpt
    set fd [open campus_terminal_timing_status.rpt r]
    set timing_status [read $fd];close $fd
    if {[regexp {SWNS:\s*-} $timing_status] || [regexp {HWNS:\s*-} $timing_status]} {
        error "Timing violations remain: $timing_status"
    }
    bitgen -bit campus_terminal.bit -bin campus_terminal.bin
    set fd [open SUCCESS w]; puts $fd [clock seconds]; close $fd
} result]} {puts "BUILD_FAILED: $result"; exit 1}
puts "BUILD_COMPLETED"
exit 0
