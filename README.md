# dcu2pat

<b>DCU2PAT</b> - fork of [DCU32INT](https://gitlab.com/dcu32int/DCU32INT) utility by Alexei Hmelnov<br>
with ugly hack, for make IDA patern files also.<br>
With *.int files, also created .pat files.<br>

# dcu2pat usage:
1. Make 2 dirs, in the program folder:
* `d2.1_lib` (put here dcu files form delphi 2)
* `d2.1_res` (here results are saved)

2. run `alllib2.bat` for delphi2.0
* After performing, in the `D2.1_Res` folder, .pat files must be created. (.int files are also created, but they are problematic due to a terrible crooked hack)

3. Copy `*.pat` in one file can be done like this: go to the `D2.1_Res` folder and type
* `copy *.pat d2.1.pat`

4. Add to the end of the file `D2.1.pat`
* `'---\n'` for sigmake.exe (where 'n - new line)

5. To create a .sig file:
* `sigmake -n "Delphi 2.1 rtl" d2.1.pat "d2.1.sig"`

6. copy `d2.1.sig` to the `"folder with IDA"\SIG\PC\`

# dcu2pat tests:

Tested in free pascal, with lazarus ide<br>
Tested with Delphi 2/2.1 RTL only<br>

# why dcu2pat?

You can do .pat files from .obj generted by dcc32. The quality of such templates `.pat` from `.obj` lower.

# todo:
It is written terribly. Rewrite the Patterns generator, fully.
