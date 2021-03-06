#|
                    ***** A_STAR.LSP *****

This file describes the functions that collectively implement the A*
state-space search algorithm. The primary function in this file is the A*
function, which, when called, initiates the algorithm and returns a list of
states beginning with the state given, taken as the starting state, and ending
with the goal state. The A* algorithm works by implementing a heuristic to
estimate a state's distance to the goal state.

The A* algorithm uses two lists called the Open List and the Closed List. The
Open List is used to store found states whose successors have yet to be
generated, while the Closed List stores found states that have generated
successors. It begins by placing the starting state in the Open List, and then
enters a recursion cycle. In the cycle, it first finds the 'best' state on the
Open List. The way the algorithm determines which state is 'best' is by
estimating the length of the shortest solution path the state is a part of.
This estimation, f', is calculated by adding the number of states traversed
from the start state to get to the current state, g, and the estimated
smallest number of states left to traverse until the goal state is reached, h'.
The state with the smallest f' values is considered the 'best' state so far.
Once a 'best' state has been found, the algorithm checks if that state is the
goal. If it is not, it will generate that state's successor states and moves
the state to the Closed List. It then processes the successor states generated
by either placing the successor on the Open List, or throwing it out if the
state is already on either the Open List or the Closed List. When the goal
state is found, the recursion ends, and a list of states is built as each
function call resolves. This list of states represents the solution path
through the state-space.

This implementation uses nodes instead of states to keep track of more data on
each state. The structure of a node is as follows:
    ( g h' state parent-state )
        g - the distance the state is from the start state
        h' - the estimated distance the state is from the goal state
        state - the state that the node holds in the state-space
        parent-state - the state that the node's parent holds

Author: Scott Carda
Written Spring 2016 for CSC447/547 AI class.

|#

#|--------------------------------------------------------------------------|#
#|                            Global Variables                              |#
#|--------------------------------------------------------------------------|#

; Number of states generated by the A* algorithm
( defparameter *generated* 0 )
; Number of distinct states discovered by the A* algorithm
( defparameter *distinct* 0 )
; Number of states that were selected for
; generating successors by the A* algorithm
( defparameter *expanded* 0 )

#|--------------------------------------------------------------------------|#
#|                               A* Functions                               |#
#|--------------------------------------------------------------------------|#

; Performs the A* algorithm given a starting state, goal predicate function,
; successor generation function, and a static evaluation heuristic function.
( defun A* ( state goal? successors heuristic )
    "Performs a state-space search using the A* algorithm."
    ; Reset global counters
    ( setf *generated* 0 )
    ( setf *distinct* 1 )
    ( setf *expanded* 0 )

    ; Stripes off the leading NIL from the returned list of states
    ;( cdr
        ; Calls the recursive A*_search function
        ( A*_search
            ; Open List only has the starting node in it
            ( list ( list 0 ( funcall heuristic state ) state NIL ) )
            ; Closed List is empty
            NIL
            goal?
            successors
            heuristic
        )
    ;)
)

; Iteratively searches the state-space by picking the 'best' unexpanded
; node so far and expanding it, until the goal state is found.
( defun A*_search ( open_list closed_list goal? successors heuristic )
    "Iteratively searches the state-space with the A* algorithm."
    ( let
        (
            ; Gets the best node in the Open List
            ( best ( find_best open_list ) )
            ; Holds '((open_list) (closed_list)) which
            ; is returned by some functions
            both
            succ_list    ; List of successor nodes
            solution    ; List that is returned by this function
        )
        
        ; Iterative search of the state-space
        ( do ()
            ; Stop once the goal is found
            ( ( funcall goal? ( caddr best ) ) nil )
            
            ; Moves best to Closed List
            ( setf both
                ( mov_elem_between_lsts best open_list closed_list )
            )
            ( setf open_list ( car both ) )
            ( setf closed_list ( cadr both ) )

            ; Generates list of successors
            ( setf succ_list
                ( map
                    'list
                    #'( lambda ( state )
                        ( make_node state best heuristic )
                    )
                    ( funcall successors ( caddr best ) )
                )
            )
            
            ; Update number of nodes expanded
            ( setf *expanded* ( + *expanded* 1 ) )
            
            ; Update number of nodes generated
            ( setf *generated* ( + *generated* ( length succ_list ) ) )

            ; Processes successors
            ( setf both ( process_succs succ_list open_list closed_list ) )
            ( setf open_list ( car both ) )
            ( setf closed_list ( cadr both ) )
            
            ; Find next best
            ( setf best ( find_best open_list ) )
        )
        
        ; Set up the solution with the parent state of the
        ; goal state followed by the goal state
        ( setf solution ( list ( nth 3 best) ( nth 2 best ) ) )
        
        ; Build the solution backwards, using each node's parent
        ( do ()
            ; Stop when the parent is NIL ( this is the start state's parent )
            ( ( not ( car solution ) )
                ( cdr solution ) ; Strip off the leading NIL and return
            )
        
            ; Append the parent state to the front of the list
            ( setf solution ( cons ( nth 3
                ; Finds the node with the leading state
                ( get_node_with_state
                    ( car solution )
                    ; Searches both lists
                    ( append open_list closed_list )
                )
            ) solution ) )
        )
    )
)

#|--------------------------------------------------------------------------|#
#|                             Other Functions                              |#
#|--------------------------------------------------------------------------|#

; Finds and returns the node in node_list with the given state.
; Returns NIL if not found.
( defun get_node_with_state ( state node_list )
    "Returns a node with a given state from the given list of nodes."
    ( car ( member
        state
        node_list
        ; Compare the given state with the node's state
        :test #'( lambda ( state node ) ( equal state ( caddr node ) ) )
    ))
)

; Creates a node from a given state, its parent node, and a heuristic function.
; Nodes are of the following form:
;    ( g h' state parent-state )
;        g - the distance the state is from the start state
;        h' - the estimated distance the state is from the goal state
;        state - the state that the node holds in the state-space
;        parent-state - the state that the node's parent holds
( defun make_node ( state parent heuristic )
    "Creates a node."
    ( list
        ( 1+ ( car parent ) )       ; The g value ( dist from start state )
        ( funcall heuristic state ) ; The h' value ( estimated dist from goal )
        state ; The state
        ( caddr parent ) ; The parent state
    )
)

; Recursively searches the open_list for the node with the smallest f' value.
( defun find_best ( open_list &optional ( best () ) )
    "Returns the node from the given list with the smallest f' value."
    ( cond

        ; If the open_list is empty ( base case ): Returns best
        ( ( not ( car open_list ) ) best )

        ; If best has not been passed in, ( first call ):
        ; Assumes best is first on open_list and recurses
        ( ( not best ) ( find_best ( cdr open_list )( car open_list ) ) )

        ; If a better node is found:
        ( ( < ( eval_node ( car open_list ) ) ( eval_node best ) )
            ; Recurses with better node
            ( find_best ( cdr open_list ) ( car open_list ) )
        )

        ; Else: Recurses with current best node
        ( t ( find_best ( cdr open_list ) best ) )
    )
)

; Calculates a node's f' value as g + h'.
; Small function, but helps to reduce clutter.
( defun eval_node ( node )
    "Gets a node's f' value."
    ( + ( car node ) ( cadr node ) )
)

; Moves elem from a_list to b_list. Returns the updated lists
; in the following format: ( (a_list) (b_list) ).
( defun mov_elem_between_lsts ( elem a_list b_list )
    "Removes element from first list and adds it to the second list."
    ( let ( both )
        ; If elem is found in a_list:
        ( when ( member elem a_list :test #'equal )
            ( setf a_list ( remove elem a_list :test #'equal ) )
            ( setf b_list ( cons elem b_list ) )
            ( setf both ( list a_list b_list ) )
        )
        ; Returns updated lists
        both
    )
)

; Recursively processes successor nodes on succ_list by either
; placing the successor on the Open List, placing the successor on
; the Open List and throwing out an existing node with the same state, or
; throwing out the successor node in favor of an existing node with the
; same state. Returns the updated Open List and Closed List in the
; following format: ( (open_list) (closed_list) )
( defun process_succs ( succ_list open_list closed_list )
    "Conditionally puts all nodes of successor list into Open List."
    ( let
        (
            ; The Successor node being processed
            ( succ ( car succ_list ) )
            extra ; Holds a node found on the Closed List or Open List
        )
        ( cond

            ; If all successors have already been processed ( base case ):
            ( ( not succ )
                ; Return updated lists
                ( list open_list closed_list )
            )

            ( t
                ( cond

                    ; If the same state was found on the Closed List:
                    ( ( setf extra
                            ( get_node_with_state ( caddr succ ) closed_list )
                        )
                        ; If succ is better than extra:
                        ( when ( < ( eval_node succ ) ( eval_node extra ) )
                            ; Removes extra and puts succ on Open List
                            ( setf closed_list ( remove extra closed_list ) )
                            ( setf open_list ( cons succ open_list ) )
                        )
                    )

                    ; If the same state was found on the Open List:
                    ( ( setf extra
                            ( get_node_with_state ( caddr succ ) open_list )
                        )
                        ; If succ is better than extra:
                        ( when ( < ( eval_node succ ) ( eval_node extra ) )
                            ; Removes extra and puts succ on Open List
                            ( setf open_list ( remove extra open_list ) )
                            ( setf open_list ( cons succ open_list ) )
                        )
                    )

                    ; If no extras were found:
                    ( t
                        ; Puts succ on Open List
                        ( setf open_list ( cons succ open_list ) )
                        
                        ; Update number of distinct nodes
                        ( setf *distinct* ( + *distinct* 1 ) )
                    )
                )

                ; Recurse with updated lists
                ( process_succs ( cdr succ_list ) open_list closed_list )
            )
        )
    )
)
