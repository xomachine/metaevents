
from strutils import `%`
import macros
from typetraits import name

macro declareEventPipe*(name: untyped,
                       events: varargs[typed]): untyped =
  let name_string = name.repr
  var field_list = newNimNode(nnkRecList)
  var init_sequence = newNimNode(nnkStmtList)
  for event in events:
    let event_name = event.repr
    let proc_decl = "proc(e: $1): bool" % event_name
    let event_pipe_name = event_name & "_pipe"
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
  result = pipe.newDotExpr(newIdentNode($postfix))

proc on_event*[P, E](pipe: var P, handler: proc(e: E):bool) =
  assert(pipeEntry(pipe, name(E) & "_pipe") is seq[type(handler)],
    "No subpipe for event $1." % name(E))
  pipeEntry(pipe, name(E) & "_pipe").add(handler)

proc emit*[P, E](pipe: var P, event: E) =
  assert(pipeEntry(pipe, name(E) & "_pipe") is seq[proc(e:E):bool],
    "No subpipe for event $1." % name(E))
  for handler in pipeEntry(pipe, name(E) & "_pipe"):
    if handler(event):
      break
  
 
