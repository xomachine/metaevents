
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
        newIdentNode(event_pipe_name),
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
  ## them won't return ``true``.
  let subpipe = pipeEntry(pipe, name(E))
  assert(subpipe is seq[proc(e:E):bool],
    "No subpipe for event $1." % name(E))
  # The copying is necessary for passing tests related to removing
  # or adding handler while handling
  var subpipe_copy = subpipe
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
