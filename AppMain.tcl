#BEGIN IMAGES
set dir [file dirname [info script]]
source [file join $dir  "cards.tcl"]
source [file join $dir "random.tcl"]
#END IMAGES

#package require random
#set ranbin [info nameofexecutable]
#if [regexp "MacOS/Wishkit" $ranbin] {
#    set ranbin [regsub "MacOS/Wishkit" $ranbin "Resources/Scripts/Random"]
#} else {
#    set ranbin "./Random"
#}

wm title . "Seahaven Towers"
#Card format: DA, C2, ST, HJ
set ranks {A 2 3 4 5 6 7 8 9 T J Q K}
set suits {S C D H}
proc Suit {card} {return [string index $card 0]}
proc Rank {card} {return [string index $card 1]}
#----------------------------------------
proc EmptySlots {} {
    global C
    set total 0
    for {set i 11} {$i<=14} {incr i} {if (![llength $C($i)]) {incr total}}
    return $total
}
#----------------------------------------
proc Initialize {} {
    global ranks suits C deck movecount cheats difficulty
    set cheats 0
    set difficulty 1
    .diff config -text "Normal"
    pack forget .top.cheats.lbl .top.cheats.val
    set deck {}
    .c configure -bg darkslategray 
    foreach rank $ranks {
	foreach suit $suits {
	    lappend deck "$suit$rank"
	}}
    set nummoves 1000
    ::random::seed [clock seconds]
    for {set i 0} {$i<$nummoves} {incr i} {
	set N1 [expr int([::random::one]*52)]
	set N2 [expr int([::random::one]*52)]
	set C1 [lindex $deck $N1]
	set C2 [lindex $deck $N2]
	set deck [lreplace $deck $N1 $N1 $C2]
	set deck [lreplace $deck $N2 $N2 $C1]
    }
    catch {close $F}
    for {set i 1} {$i<=10} {incr i} {
	set C($i) [lrange $deck [expr ($i-1)*5] [expr $i*5-1]]
    }
    set C(11) ""
    set C(12) [lindex $deck 50]
    set C(13) [lindex $deck 51]
    set C(14) ""
    foreach i $suits {set C($i) {}}
    set movecount 0
    SavePoint
}
#----------------------------------------
bind . <Command-n> {NewGame}
bind . <Command-q> {exit}
bind . <Command-z> {Undo}
bind . <Command-x> {Redo}
bind . <Control-n> {NewGame}
bind . <Control-q> {exit}
bind . <Control-z> {Undo}
bind . <Control-x> {Redo}
bind . <BackSpace> {Undo}
bind . <Shift-BackSpace> {Redo}
#----------------------------------------
set difficulty 1
frame .top
label .top.debug -text "" -wraplength 800
#pack .top.debug
#NOTE: cheat count isn't reversed under undo
frame .top.cheats -width 105
label .top.cheats.lbl -text "# of cheats: "
label .top.cheats.val -textvariable cheats -width 2 -justify left
bind .top.cheats <Button> ""
menubutton .diff -direction below -width 10 -text "Normal"
menu .diff.menu -tearoff 0
.diff configure -menu .diff.menu
.diff.menu add radiobutton -label "Normal" -command {.diff configure -text "Normal"} -value 1 -variable difficulty
.diff.menu add radiobutton -label "Cheat" -command {.diff configure -text "Cheat"; pack .top.cheats.lbl .top.cheats.val -side left} -value 0 -variable difficulty
label .diffL -text "Difficulty:"
pack .top.cheats -side right 
pack .diff .diffL -in .top -side right
pack .top -side top -fill x
button .top.new -text "New" -command {NewGame}
button .top.quit -text "Quit" -command {exit}
button .top.undo -text "Undo" -command {Undo}
button .top.redo -text "Redo" -command {Redo}
pack .top.new .top.quit .top.undo .top.redo -side left
label .top.move -text "Move 1" -width 20 -justify left
pack .top.move -side left
canvas .c -width 800 -height 600 -bg darkslategray
pack .c -side top
foreach suit $suits {
    .c create rectangle 0 0 0 0 -tag R$suit -width 2
    .c create rectangle 0 0 0 0 -tag r$suit -width 2
    foreach rank $ranks {
	.c create image -100 -100 -image ::img::$suit$rank -anchor nw -tag $suit$rank
	.c bind "$suit$rank" <Button> "ClickCard $suit $rank"
    }}
for {set i 1} {$i<=14} {incr i} {
    set ch [string index "asdfgzxcvbqwer" [expr $i-1]]
    set Ch [string index "ASDFGZXCVBQWER" [expr $i-1]]
    set x [expr 55+(($i-1)%10)*75]
    set y [expr 140-(($i-1)/10)*25]
    set dum [.c create text $x $y -text $ch -font "Helvetica 18" -fill gray -tag col$i]
    .c bind $dum <Button> "TryMove $i 0"
    bind . <$ch> "TryMove $i 0"
    bind . <$Ch> "TryMove $i 1"
}
#----------------------------------------
proc ClickCard {suit rank} {
    set wh "$suit$rank"
    global C
    set col 0
    for {set i 1} {$i<=14 && !$col} {incr i} {
	if {[lsearch $C($i) $wh]>=0} {break}
    }
    if {$i<15} {TryMove $i 0}
}
#----------------------------------------
proc CheckMove {col} {
    global C
    set done 0
    if (![llength $C($col)]) {return 0}; #column empty
    foreach {pos move num} [Stack $col] {};
    if {$col<=10 && $pos==0 && [Rank $move] eq "K"} {return 0}; #don't move a king from an empty slot
    set empty [EmptySlots];
    foreach {pos move num} [Stack $col] {};
    if {$num<=$empty+1} {
	for {set i 1} {$i<=10} {incr i} {
	    if [DescendingQ [lindex $C($i) end] $move] {return 1}; #can be moved
	}
    }
    return 0;
}
proc LightLetters {} {
    global C
    for {set i 1} {$i<=14} {incr i} {
	if [CheckMove $i] {.c itemconfig col$i -font "Helvetica 18"} else {.c itemconfig col$i -font "Helvetica 14"}
    }
}
#----------------------------------------
proc Stack {col} {
    #Find top position and card of most movable stack on col
    global C
    set pos [expr [llength $C($col)]-1]; #position of bottom card
    set card [lindex $C($col) $pos];     #the bottom card
    set num 1
    while {!([Rank $card] eq "K") \
	       && [DescendingQ [lindex $C($col) [expr $pos-1]] $card]} { 
	incr pos -1
	incr num
	set card [lindex $C($col) $pos]
    }
    return "$pos $card $num"
}
#----------------------------------------
proc DescendingQ {hi lo} {
    global ranks
    set suitq [expr {[Suit $hi] eq [Suit $lo]}\
		   || ![llength [Suit $hi]]\
		   || ![llength [Suit $lo]]]
    set lon [lsearch $ranks [Rank $lo]]
    set hin [expr [lsearch $ranks [Rank $hi]]%14]
    return [expr $hin==$lon+1 && $suitq]
}
#----------------------------------------
proc MoveCards {i j pos} {
    global C
    eval lappend C($j) [lrange $C($i) $pos end]
    set C($i) [lreplace $C($i) $pos end]
}
#----------------------------------------
proc TryMove {col foundQ} {
    global C difficulty cheats
    set done 0
    set baseK 0; #true if moving a solitary king from the tableau
    if (![llength $C($col)]) {return 0}; #if column empty, do nothing
    foreach {pos move num} [Stack $col] {};
    if {$col<=10 && $pos==0 && [Rank $move] eq "K"} {set baseK 1}; #don't move a king from an empty slot
    if {!$foundQ && !$baseK} {
	set empty [EmptySlots];
	if {$num*$difficulty<=$empty+1} {
	    if {$num>$empty+1} {incr cheats [expr $num-$empty-1]}
	    for {set i 1} {$i<=10} {incr i} {
		if [DescendingQ [lindex $C($i) end] $move] {
		    MoveCards $col $i $pos
		    set done 1
		    SavePoint
		    break
		}
	    }
	}
    }
    if {!$done && $col<11} {
	for {set i 11} {$i<=14} {incr i} {
	    if ![llength $C($i)] {
		MoveCards $col $i end
#		set C($i) [lindex $C($col) end]
#		set C($col) [lreplace $C($col) end end]
		SavePoint
		set done 1;break;
	    }
	}
    }
    DrawDisplay;
    return $done;
}
#----------------------------------------
proc NewGame {} {
    Initialize
    DrawDisplay
}
#----------------------------------------
proc DrawDisplay {} {
    global movecount maxcount
#    console show 
    if {$movecount<=1} {set st disabled} else {set st normal}
    .menubar.mEdit entryconfigure Undo* -state $st
    .top.undo config -state $st
    if ($movecount>=$maxcount) {set st disabled} else {set st normal}
    .menubar.mEdit entryconfigure Redo* -state $st
    .top.redo config -state $st
    
	
    
    MoveAllToFoundation
    Draw
LightLetters
#    .top.debug configure -text [info nameofexecutable]
}
#----------------------------------------
proc Draw {} {
    global C suits
    set xmul 75
    set ymul 30
    set xoff 20
    set tabyoff 150
    set foundyoff 10
    for {set i 1} {$i<=10} {incr i} {
	for {set j 0} {$j<[llength $C($i)]} {incr j} {
	    .c coords [lindex $C($i) $j] [expr $xoff+$xmul*($i-1)] [expr $tabyoff+$ymul*$j]
	    .c raise [lindex $C($i) $j]
	}}
    for {set i 1} {$i<=4} {incr i} {
	.c coords $C(1$i) [expr $xoff+$xmul*($i-1)] $foundyoff
    }
    set win 0
    foreach suit $suits {
	set loc "[expr $xoff+$xmul*(6+[lsearch $suits $suit])] $foundyoff"
	set rect "$loc [expr [lindex $loc 0]+71] [expr [lindex $loc 1]+96]"
	.c coords R$suit $rect
	set rect [lreplace $rect 0 0 [expr $xoff+$xmul*[lsearch $suits $suit]]]
	set rect [lreplace $rect 2 2 [expr [lindex $rect 0]+71]]
	.c coords r$suit $rect
	for {set j 0} {$j<[llength $C($suit)]} {incr j} {
	    .c coords [lindex $C($suit) $j] [expr $xoff+$xmul*(6+[lsearch $suits $suit])] $foundyoff
	    .c raise [lindex $C($suit) $j]
	}
	if [llength $C($suit)]==13 {incr win}
    }
    if ($win==4) {Win}
    update
}
#----------------------------------------
proc Win {} {
   .c configure -bg blue
   bind . <Command-n> {}
   after 5000 {bind . <Command-n> {NewGame}; .c configure -bg gray}
}
#----------------------------------------
proc MoveAllToFoundation {} {
    global C
    set done 0
    while {$done==0} {
	set done 1
	for {set i 1} {$i<=14} {incr i} {
	    set moveq [lindex $C($i) end]
	    set suit [string index $moveq 0]
	    if ([llength $suit]) {
		if [DescendingQ $moveq [lindex $C($suit) end]] {
		    MoveCards $i $suit end
		    set done 0
		    Draw
		    after 50;
		}}
	}
    }
}
#----------------------------------------
proc SavePoint {} {
    global C movecount Point maxcount
    if ($movecount>0) {set temp $Point([expr $movecount-1])} else {set temp {}}
    if (![string equal [array get C] $temp]) {
	set Point($movecount) [array get C]
	incr movecount
	set maxcount $movecount
	.top.move configure -text "Move $movecount"
#	wm title . "Move $movecount"
    }
}
#----------------------------------------
proc Restart {} {
    global C movecount Point
    set movecount 1
    array set C $Point(0)
    DrawDisplay
    .top.move configure -text "Move $movecount (reset)"
}

proc Undo {} {
    #way to reverse cheat count? array which labels moves as cheats or not
    global C movecount Point
    if ($movecount>1) {
	incr movecount -1
	array set C $Point([expr $movecount-1])
	DrawDisplay
	.top.move configure -text "Move $movecount (undone)"
    }
}
#----------------------------------------
proc Redo {} {
    global C movecount Point maxcount
    if ($movecount<$maxcount) {
	incr movecount
	array set C $Point([expr $movecount-1])
	DrawDisplay
	.top.move configure -text "Move $movecount (redone)"
#	wm title . "move $movecount"
    }
}
#----------------------------------------
proc Help {} {
    global dir
    if [winfo exists .help] {raise .help
    } else {
	toplevel .help
	label .help.rules -bg gray -wraplength 500
	pack .help.rules
	set F [open [file join $dir rules] RDONLY]
	set text [read $F]
	close $F
	.help.rules config -text $text
	bind .help <Button-1> {destroy .help}
    }
}
#----------------------------------------
Initialize
bind . <Command-Control-c> {console show}
menu .menubar
. config -menu .menubar
foreach m {File Edit Help} {
    set $m [menu .menubar.m$m -tearoff 0]
    .menubar add cascade -label $m -menu .menubar.m$m
}
$File add command -label "New Game" -command NewGame -accelerator "Command-N"
$File add command -label "Restart Game" -command Restart
$Edit add command -label "Undo Move" -command Undo -accelerator "Command-Z"
$Edit add command -label "Redo Move" -command Redo -accelerator "Command-X"
$Help add command -label "Rules" -command Help -state normal

DrawDisplay
raise .
