
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
  let name_string = name.repr
  var field_list = newNimNode(nnkRecList)
  var init_sequence = newNimNode(nnkStmtList)
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
    init_sequence.add(parseExpr("result.$1 = newSeq[$2]()\n" %
      [event_pipe_name, proc_decl]))
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
  let initArg = newTree(nnkIdentDefs, newIdentNode("pipe"),
    parseExpr("typedesc[$1]" % name_string),
    newEmptyNode())
  let initDecl = newProc(newIdentNode("initPipe").postfix("*"),
    [name, initArg],
    init_sequence)
    
  result = newTree(nnkStmtList, typeDecl, initDecl)
  hint(result.repr)

#macro concat(name: string, postfix: string): untyped =
#  newIdentNode(name & postfix)

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
  pipeEntry(pipe, name(E) & "_pipe").add(handler)

proc emit*[P, E](pipe: var P, event: E) =
  ## Emits an ``event`` to the event ``pipe``.
  ## The event will be passed to
  ## the all handlers related to such type of event until one of
  ## them won't return ``true``.
  let subpipe = pipeEntry(pipe, name(E))
  assert(subpipe is seq[proc(e:E):bool],
    "No subpipe for event $1." % name(E))
  for handler in subpipe:
    if handler(event):
      break
  
