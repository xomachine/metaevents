## ==========
## Metaevents
## ==========
##
## This library is designed as an alternative to the events_
## library with strong event type checking at compile time.
##
## .. _events: http://nim-lang.org/docs/events.html
## Event pipes
## -----------
##
## The main concept of this library is using an event pipe
## to communicate between event emmiters and event handlers.
## Due to compile-time nature each event pipe can support
## only specified set of events which should be declared
## by special macro at top level of the source code file.
##
## The event pipe is a type which constructed from
## event chains - sequencies of event handlers.
## Dispatching events between the chains is performed
## at compile time while the iterating through handlers
## in chain is a runtime operation.
##
## There is no special type for the event pipe in this library,
## so user has to declare his own event pipe (or event pipes)
## for set of events used in the code. Declaration of the
## event pipe can be performed via ``declareEventPipe`` macro.
## For example, there are two kind of events used in application:
##
## .. code-block:: Nim
##   type
##     ButtonPressed = object
##       button_id: int
##   
##     MouseMoved = object
##       shift_x: int
##       shift_y: int
##
## To construct the event pipe with name "TheEventPipe"
## for those events the following
## declaration should be placed at the top level of the file:
##
## .. code-block:: Nim
##   declareEventPipe(TheEventPipe,
##                    ButtonPressed,
##                    MouseMoved)
##
## This statement will just create the event pipe type declaration
## in the following way:
##
## .. code-block:: Nim
##   type
##     TheEventPipe* = object
##       ButtonPressed_pipe: seq[proc (e: ButtonPressed): bool]
##       MouseMoved_pipe: seq[proc (e: MouseMoved): bool]
##
## After declaring of the event pipe it can be used in code. First,
## the event pipe object instance should be created.
##
## .. code-block:: Nim
##   var MyEventPipe: TheEventPipe
##
## There are no special initiation required, just declare the
## instance of the event pipe type and use it. Detailed
## description of procedures used can be found below.
##
## .. code-block:: Nim
##   let mousehandler = proc (e: MouseMoved): bool =
##     discard # There are could be some handling stuff
##   MyEventPipe.on_event(mousehandler)
##   # ... a long listing ago
##   var moving: MouseMoved
##   MyEventPipe.emit(moving) # There goes call of the 'mousehandler'
##
## Multithreading
## --------------
##
## The metaevents library is not developed for multithreaded
## applications. All event handlers will be called by the
## control flow of the event emmiter without any syncronization
## or data transfer to another thread. But the handler
## might be written in the way that allows this library to be used
## in multithreaded application. In this case all work related
## to interthread communications is assigned to the user.
##

from strutils import `%`
import macros
from typetraits import name

proc event2field(event: string): string =
  ## Makes field name for event pipe object from event type
  event & "_pipe"

macro declareEventPipe*(name: untyped,
                       events: varargs[typed]): untyped =
  ## Declares event pipe of given name for supplied list of
  ## events.
  ##
  ## This macro must be used at the top level of file.
  ##
  ## For example, consider the following declaration:
  ##
  ## .. code-block:: Nim
  ##
  ##   declareEventPipe(stringPipe, string)
  ##
  ## It will produce the code:
  ##
  ## .. code-block:: Nim
  ##
  ##   type
  ##     stringPipe* = object
  ##       string_pipe: seq[proc(e: string): bool]
  ##
  ## So, the instance of the ``stringPipe`` type now can be
  ## used to subscribe on or emit events with type ``string``
  ## The other types of events including user suplied can
  ## also be passed to this macro.
  ##
  var field_list = newNimNode(nnkRecList)
  for event in events:
    let event_name = event.repr
    let proc_decl = "proc(e: $1): bool" % event_name
    let event_pipe_name = event2field(event_name)
    field_list.add(
      newTree(nnkIdentDefs,
        newIdentNode(event_pipe_name).postfix("*"),
        parseExpr("seq[$1]" % (proc_decl)),
        newEmptyNode()
      )
    )
  let obj = newTree(nnkObjectTy,
    newEmptyNode(),
    newEmptyNode(),
    field_list
  )
  let typeDef = newTree(nnkTypeDef,
    name.postfix("*"),
    newEmptyNode(),
    obj
  )
  let typeDecl = newTree(nnkTypeSection, typeDef)
    
  result = newTree(nnkStmtList, typeDecl)
  when defined(debug):
    hint(result.repr)

macro pipeEntry(pipe: any, postfix: string): untyped =
  ## Constructs expression to access pipe field for given type
  ## name.
  ##
  ## .. code-block:: Nim
  ##
  ## pipeEntry(pipe, "MyType")
  ## # will produce
  ## pipe.MyType_pipe
  ##
  result = pipe.newDotExpr(newIdentNode(event2field($postfix)))

proc on_event*[P, E](pipe: var P, handler: proc(e: E): bool) =
  ## Attaches handler for event ``E`` to the ``pipe``.
  ## The event type will be inferenced from the handler type.
  ## When the handler returns ``true``, the event won't be passed
  ## to next handlers in chain.
  assert(pipeEntry(pipe, name(E)) is seq[type(handler)],
    "No subpipe for event $1." % name(E))
  if isNil(pipeEntry(pipe, name(E))):
    pipeEntry(pipe, name(E)) = newSeq[type(handler)]()
  pipeEntry(pipe, name(E)).add(handler)

proc emit*[P, E](pipe: var P, event: E) =
  ## Emits an ``event`` to the event ``pipe``.
  ## The event will be passed to
  ## the all handlers related to such type of event until one of
  ## them won't return ``true``. The order of the handlers call
  ## is not guaranteed but might be preserved in case if no
  ## hadlers were detached.
  let subpipe = pipeEntry(pipe, name(E))
  assert(subpipe is seq[proc(e:E):bool],
    "No subpipe for event $1." % name(E))
  # The copying is necessary for passing tests related to removing
  # or adding handler while handling
  var subpipe_copy = newSeq[proc(e:E):bool](subpipe.len)
  for i in 0..<subpipe.len:
    subpipe_copy[i] = subpipe[i]
  for handler in subpipe_copy:
    if handler(event):
      break

proc detach*[P, E](pipe: var P, handler: proc(e: E): bool) =
  ## Detaches the ``handler`` from the event ``pipe``.
  ##
  ## If the ``handler`` is detached while handling
  ## event, changes will take effect only when next event
  ## will be emitted.
  let subpipe = pipeEntry(pipe, name(E))
  assert(subpipe is seq[proc(e:E):bool],
    "No subpipe for event $1." % name(E))
  let index = subpipe.find(handler)
  if index >= 0:
    pipeEntry(pipe, name(E)).del(index)

proc detach_all*[P, E](pipe: var P, event: typedesc[E]) =
  ## Detaches all event handlers for given ``event``
  let subpipe = pipeEntry(pipe, name(E))
  assert(subpipe is seq[proc(e:E):bool],
    "No subpipe for event $1." % name(E))
  pipeEntry(pipe, name(E)).setLen(0)

proc detach_all*[P](pipe: var P) =
  ## Detaches all event handlers for all events.
  for field_val in fields(pipe):
    field_val.setLen(0)
