
version       = "0.1.0"
author        = "xomachine (Fomichev Dmitriy)"
description   = "Metaevents is a factory for your own events libraries"
license       = "MIT"


requires "nim >= 0.14.2"

task tests, "Run tests":
  let test_files = listFiles("tests")
  for file in test_files:
    exec("nim c --run -p:" & thisDir() & " -o:tmpfile " & file)
    rmFile "tmpfile"

task docs, "Build documentation":
  exec("nim doc --docSeeSrcUrl:https://gitlab.com/xomachine/" &
    "metaevents/ -p:" & thisDir() & " metaevents.nim")
