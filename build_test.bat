@echo off
odin run src/test -out:bin/test.exe -debug -o:minimal -vet -strict-style
@echo on
