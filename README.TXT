# dcu2pat

DCU2PAT -> fork of DCU32INT utility by Alexei Hmelnov
with ugly hack, for make IDA patern files also.
With *.int files, also created .pat files;

Tested in free pascal, with lazarus ide;


# usage:
make 2 dirs, in the program folder;
 d2.1_lib (put here dcu files form delphi 2)
 d2.1_res (here results are saved)

run alllib2.bat for delphi2.0

After performing, in the D2.1_Res folder, 
a .pat files must be created. 
(.int files are also created, but they are problematic due to a terrible crooked hack)

Copy *.pat in one file can be like this:
Go to the D2.1_Res folder and enter 
`` `copy *.pat d2.1.pat```

Add to the end of the file D2.1.pat file of the end of the file
```--- Enter``` for sigmake.exe

To create a .Sig file:
sigmake -n "Delphi 2.1 rtl" d2.1.pat "d2.1.sig"

d2.1.sig copy to the "folder with IDA"\SIG\PC\
