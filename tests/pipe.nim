import unittest
import metaevents

declareEventPipe(testPipe, int, string)

suite "Pipe tests":
  test "Simple event":
    var thePipe: testPipe
    var testvar = 0
    let testproc = proc(e: int): bool = testvar = e
    thePipe.on_event(testproc)
    thePipe.emit(5.int)
    check(testvar == 5)

  test "Simple ref event":
    var thePipe: ref testPipe
    new(thePipe)
    var testvar = 0
    let testproc = proc(e: int): bool = testvar = e
    thePipe[].on_event(testproc)
    thePipe[].emit(5.int)
    check(testvar == 5)

  test "Mixed events":
    var thePipe: testPipe
    var testint = 0
    var teststring = ""
    let firsthandler = proc(e: int): bool = testint = e
    let secondhandler = proc(e: string): bool = teststring = e
    thePipe.on_event(secondhandler)
    thePipe.on_event(firsthandler)
    thePipe.emit(5.int)
    check(testint == 5)
    check(teststring == "")
    thePipe.emit("hello")
    check(testint == 5)
    check(teststring == "hello")
    thePipe.emit(3.int)
    check(testint == 3)
    check(teststring == "hello")

  test "Events chain":
    var thePipe: testPipe
    var testint = 0
    let firsthandler = proc(e: int): bool = testint = e
    let uselesshandler = proc(e: int): bool = testint += e
    thePipe.on_event(firsthandler)
    thePipe.on_event(uselesshandler)
    thePipe.emit(5)
    check(testint == 10)

  test "Empty chain":
    var thePipe: testPipe
    thePipe.emit("hello")
    thePipe.emit(10)

  test "Chain break":
    var thePipe: testPipe
    var testint = 0
    let firsthandler = proc(e: int): bool =
      testint = e
      true
    let uselesshandler = proc(e: int): bool = testint += e
    thePipe.on_event(firsthandler)
    thePipe.on_event(uselesshandler)
    thePipe.emit(5)
    check(testint == 5)

  test "Event re-emit":
    var thePipe: testPipe
    var teststring = ""
    let inthandler = proc(e:int):bool = thePipe.emit($e)
    let strhandler = proc(e:string):bool = teststring = e
    thePipe.on_event(strhandler)
    thePipe.on_event(inthandler)
    thePipe.emit(6)
    check(teststring == "6")

  test "Add handler while handling":
    var thePipe: testPipe
    var testint = 0
    let testhandler = proc(e:int):bool = testint += e
    let adder = proc (e:int):bool = thePipe.on_event(testhandler)
    thePipe.on_event(adder)
    thePipe.emit(5)
    check(testint == 0)
    thePipe.emit(6)
    check(testint == 6)

  test "Remove handler":
    var thePipe: testPipe
    var testint = 0
    let testhandler = proc (e:int):bool = testint += e
    thePipe.on_event(testhandler)
    thePipe.emit(2)
    check(testint == 2)
    thePipe.detach(testhandler)
    thePipe.emit(3)
    check(testint == 2)

  test "Remove handler while handling":
    var thePipe: testPipe
    var testint = 0
    let testhandler = proc(e:int):bool = testint += e
    let remover = proc (e:int):bool = thePipe.detach(testhandler)
    thePipe.on_event(remover)
    thePipe.on_event(testhandler)
    thePipe.emit(5)
    check(testint == 5)
    thePipe.emit(6)
    check(testint == 5)

  test "Remove all handlers for event":
    var thePipe: testPipe
    var testint = 0
    var teststring = ""
    let testhandler = proc(e:int):bool = testint += e
    let stringhandler = proc(e:string):bool = teststring &= e
    let secondhandler = proc (e:int):bool = testint += e*2
    thePipe.on_event(testhandler)
    thePipe.on_event(secondhandler)
    thePipe.on_event(stringhandler)
    thePipe.emit(2)
    check(testint == 6)
    thePipe.emit("hell")
    check(teststring == "hell")
    thePipe.detach_all(int)
    thePipe.emit(4)
    thePipe.emit("o")
    check(testint == 6)
    check(teststring == "hello")

  test "Clear all handlers":
    var thePipe: testPipe
    var testint = 0
    var teststring = ""
    let testhandler = proc(e:int):bool = testint += e
    let stringhandler = proc(e:string):bool = teststring &= e
    let secondhandler = proc (e:int):bool = testint += e*2
    thePipe.on_event(testhandler)
    thePipe.on_event(secondhandler)
    thePipe.on_event(stringhandler)
    thePipe.detach_all()
    thePipe.emit(6)
    thePipe.emit("nope")
    check(teststring == "")
    check(testint == 0)
