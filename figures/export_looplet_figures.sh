#!/bin/bash
file=Looplets # File name excluding extension

/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 0 --output "$file-lookup.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 1 --output "$file-run.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 2 --output "$file-spike.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 3 --output "$file-sequence.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 4 --output "$file-stepper.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 5 --output "$file-phase.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 6 --output "$file-switch.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 7 --output "$file-thunk.png" "$file.drawio"

file=LevelsVsFibers # File name excluding extension

/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 0 --output "$file-tensor.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 1 --output "$file-matrix.png" "$file.drawio"

file=Structures # File name excluding extension
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 0 --output "$file.png" "$file.drawio"
/Applications/draw.io.app/Contents/MacOS/draw.io --export --page-index 1 --output "$file-examples.png" "$file.drawio"