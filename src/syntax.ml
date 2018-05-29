type cmd =
| CmdExit
| CmdQuery of prop
| CmdQueryAll of prop
| CmdDef of string * pat list * prop
and prop =
| PropOr of prop * prop
| PropAnd of prop * prop
| PropNot of prop
| PropEq of pat * pat
| PropPred of string * pat list
| PropTrue
| PropFalse
| PropCxt of sol * prop
and pat =
| PatWildcard
| PatVar of string
| PatConst of string
| PatApp of string * pat list
and sol = (pat * pat) list
