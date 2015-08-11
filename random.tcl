namespace eval random {
    proc seed {n} {
        expr srand($n)
    }
    proc one {} {
        return [expr rand()]
    }
}
