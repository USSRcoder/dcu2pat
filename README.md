# dcu2pat

<b>DCU2PAT</b> - fork of [DCU32INT](https://gitlab.com/dcu32int/DCU32INT) utility by Alexei Hmelnov<br>
with ugly hack, for make IDA patern files also.<br>
With *.int files, also created .pat files.<br>
Also, *.h files created<br>

# DCU32.pas
set `conf_verbose` variable from 0 to 100, for verbose output in .h files;
May be ugly, but it need, when you creating structures with offsets in IDA;

# dcu2pat usage:
1. Make 2 dirs, in the program folder:
* `d2.1_lib` (put here dcu files form delphi 2; Debug dcu have more meta info, so use it) 
* `d2.1_res` (here results are saved)

2. run `alllib2.bat` for delphi2.0
* After performing, in the `D2.1_Res` folder, .pat files must be created. (.int files are also created, but they are problematic due to a terrible crooked hack)

3. Copy `*.pat` in one file can be done like this: go to the `D2.1_Res` folder and type
* `copy *.pat d2.1.pat`

4. Add to the end of the file `D2.1.pat`
* `'---\n'` for sigmake.exe (where \n - new line)

5. To create a .sig file:
* `sigmake -n "Delphi 2.1 rtl" d2.1.pat "d2.1.sig"`

6. copy `d2.1.sig` to the `"folder with IDA"\SIG\PC\`

# IDA and types:
When loading .exe in IDA -
1. Select checkbox "manual load";

    Disable "auto analys"

    Change "Compiler type" to Delphi in the settings

    Calling Conversion - fastcall (x32) by default
   
2. Run .h file(s) with type information so that IDA correctly recognizes procedures by name and their arguments. That is why this version of DCU2PAT generates .h files (you need to manually edit this file, because it is raw and will not work out of the box);

    Alternatively, system.hpp can be taken from CBuilder (generated using bcbdcc32.exe from .pas source included in CBuilder). But it does not have all the types (only 10%. And this is cpp, and IDA needs c).
   
    This is a fairly comprehensive and separate topic - how to generate types for IDA (collection of Python scripts).
   
3. Load "d2.1.sig"

4. Enable "auto analysis";

This way I was able to recognize almost 80%+ of the functions from the library on my victim.

# dcu2pat tests:
Build and run in free pascal, with lazarus ide<br>
Tested with Delphi 2/2.1 RTL only<br>

# why dcu2pat?
You can do .pat files from .obj generted by dcc32. The quality of such templates `.pat` from `.obj` lower.
VMT structs are created, in .h files;

# todo:
It is written terribly. Rewrite the Patterns generator, fully.

Public system.h and ida python scrips.
