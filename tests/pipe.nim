import unittest
import metaevents

declareEventPipe(testPipe, int, string)

suite "Pipe tests":
  test "Simple event":
    var thePipe = initPipe(testPipe)
    var testvar = 0
    let testproc = proc(e: int): bool = testvar = e
    thePipe.on_event(testproc)
    
    thePipe.emit(5.int)
    check(testvar == 5)
