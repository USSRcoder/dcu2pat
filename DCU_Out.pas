unit DCU_Out;

interface
(*
The output module of the DCU32INT utility by Alexei Hmelnov.
(Pay attention on the SoftNL technique for pretty-printing.)
----------------------------------------------------------------------------
E-Mail: alex@monster.icc.ru
http://monster.icc.ru/~alex/DCU/
----------------------------------------------------------------------------

See the file "readme.txt" for more details.

------------------------------------------------------------------------
                             IMPORTANT NOTE:
This software is provided 'as-is', without any expressed or implied warranty.
In no event will the author be held liable for any damages arising from the
use of this software.
Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:
1. The origin of this software must not be misrepresented, you must not
   claim that you wrote the original software.
2. Altered source versions must be plainly marked as such, and must not
   be misrepresented as being the original software.
3. This notice may not be removed or altered from any source
   distribution.
*)
uses
  SysUtils, FixUp;

{ Options: }
const
  InterfaceOnly: boolean=false;
  ShowImpNames: boolean=true;
  ShowTypeTbl: boolean=true;
  ShowAddrTbl: boolean=true;
  ShowDataBlock: boolean=true;
  ShowFixupTbl: boolean=true;
  ShowAuxValues: boolean=true;
  ResolveMethods: boolean=true;
  ResolveConsts: boolean=true;
  ShowDotTypes: boolean=true;
  ShowVMT: boolean=true;
  AuxLevel: integer=0;

const
  NoNamePrefix: String = '_N%_';
  DotNamePrefix: String = '_D%_';

procedure SetShowAll;

procedure PutS(S: String);
procedure PutSFmt(Fmt: String; Args: array of const);
function  PutS_pat(S: String):string;
function  PutSFmt_pat(Fmt: String; Args: array of const):string;
procedure NL;
procedure SoftNL;
procedure InitOut;
procedure FlushOut;

function CharDumpStr(var V;N : integer): ShortString;

function IntLStr(DP: Pointer; Sz: Cardinal; Neg: boolean): String;

function CharStr(Ch: Char): String;
function CharStr2(Ch: Char): String;
function WCharStr(WCh: WideChar): String;
function WCharStr2(WCh: WideChar): String;
function BoolStr(DP: Pointer; DS: Cardinal): String;
function StrConstStr(CP: PChar; L: integer): String;

const
  cSoftNL=#0;
  MaxOutWidth: Cardinal = 75;
  MaxNLOfs: Cardinal = 31 {Should be < Ord(' ')};

var
  NLOfs: cardinal;

procedure ShowDump(
  DP: PChar;
  SizeDispl:Cardinal;
  Size: Cardinal;
  Ofs0Displ: Cardinal;
  Ofs0 : Cardinal;
  WMin: Cardinal;
  FixCnt: integer;
  FixTbl: PFixupTbl;
  FixUpNames: boolean;
  var OutS:String;
  var OutP:String );

procedure ShowDump2(
  DP: PChar; {Dump address}
  SizeDispl {used to calculate display offset digits},
  Size {Dump size}: Cardinal;
  Ofs0Displ {initial display offset},
  Ofs0 {offset in DCU data block - for fixups},
  WMin{Minimal dump width (in bytes)}: Cardinal;
  FixCnt: integer; FixTbl: PFixupTbl;
  FixUpNames: boolean;
  var OutS:String;
  var OutP:String
);



implementation

uses
  DCU32{CurUnit}, DCU_In;

procedure SetShowAll;
begin
  ShowImpNames := true;
  ShowTypeTbl := true;
  ShowAddrTbl := true;
  ShowDataBlock := true;
  ShowFixupTbl := true;
  ShowAuxValues := true;
  ResolveMethods := true;
  ResolveConsts := true;
  ShowDotTypes := true;
  ShowVMT := true;
end ;

var
  BufNLOfs: Cardinal;
  BufLen: cardinal;
  Buf: array[0..$800-1] of Char;

procedure FillNL(NLOfs: Cardinal);
var
  S: ShortString;
  W: integer;
begin
  W := NLOfs;
  if W<0 then
    W := 0
  else if W>MaxNLOfs then
    W := MaxNLOfs;
  S[0] := Chr(W);
  FillChar(S[1],W,' ');
  Write(S);
end ;

function GetSoftNLOfs(var ResNLOfs: Cardinal): integer;
var
  i,iMin: integer;
  MinOfs,Ofs: integer;
begin
  MinOfs := Ord(' ');
  Result := BufLen;
  for i:=BufLen-1 downto 0 do begin
    Ofs := Ord(Buf[i]);
    if Ofs<MinOfs then begin
      MinOfs := Ofs;
      Result := i;
    end ;
  end ;
  if MinOfs<Ord(' ') then
    ResNLOfs := MinOfs
  else
    ResNLOfs := NLOfs;
end ;

procedure FlushBufPart(W,NLOfs: integer);
var
  i: integer;
//  S: String;
  SaveCh: Char;
begin
  if W>0 then begin
    for i:=0 to W-1 do
     if Buf[i]<' ' then
       Buf[i] := ' ';
    FillNL(BufNLOfs);
//    SetString(S,Buf,W);
//    Write(S);
    SaveCh := Buf[W];
    Buf[W] := #0;
    Write(Buf);
    Buf[W] := SaveCh;
  end ;
  Writeln;
  while (W<BufLen)and(Buf[W]<=' ') do
    Inc(W);
  if W<BufLen then begin
    move(Buf[W],Buf,BufLen-W);
    fillchar(Buf[W], BufLen-W, 0);
  end;
  BufLen := BufLen-W;
  BufNLOfs := NLOfs;
end ;

function FlushSoftNL(W: Cardinal): boolean;
var
  Split: integer;
  ResNLOfs: Cardinal;
begin
  Result := false;
  while ((BufNLOfs+BufLen+W)>MaxOutWidth)and(BufLen>0) do begin
    Split := GetSoftNLOfs(ResNLOfs);
   {Break only at the soft NL splits: }
    if Split>=BufLen then
      Break;
    FlushBufPart(Split,ResNLOfs);
  end ;
  Result := (BufNLOfs+BufLen+W)<= MaxOutWidth;
end ;

procedure BufChars(CP: PChar; Len: integer);
var
  i: integer;
  ch: Char;
begin
//  FlushSoftNL(Len);
  While Len>0 do begin
    if BufLen>=High(Buf) then
      Exit {Just in case};
    ch := CP^;
    Inc(CP);
    Dec(Len);
    if ch<' ' then begin
      if NLOfs>MaxNLOfs then
        Ch := Chr(MaxNLOfs)
      else
        Ch := Chr(NLOfs);
    end ;
    Buf[BufLen] := Ch;
    Inc(BufLen);
    if (ch<' ') then
      FlushSoftNL(0);
  end ;
  FlushSoftNL(0);
//  move(S[1],Buf[BufLen],Length(S));
//  Inc(BufLen,Length(S));
{  if FlushSoftNL(Length(S)) then begin
    move(S[1],Buf[BufLen],Length(S));
    Inc(BufLen,Length(S));
   end
  else begin
    FillNL(BufNLOfs);
    Write(S);
    Writeln;
  end ;}
end ;

procedure PutS(S: String);
begin
  if AuxLevel>0 then
    Exit;
  if S='' then
    Exit;
  BufChars(PChar(S),Length(S));
end ;

procedure PutSFmt(Fmt: String; Args: array of const);
begin
  if AuxLevel>0 then
    Exit;
  PutS(Format(Fmt,Args));
end ;

function PutS_pat(S: String):string;
begin
  result := '';
  if AuxLevel>0 then
    Exit;
  if S='' then
    Exit;
  result:= S;
end ;


function PutSFmt_pat(Fmt: String; Args: array of const):string;
begin
  result := '';
  if AuxLevel>0 then
    Exit;
  result := PutS_pat(Format(Fmt,Args));
end ;

procedure FlushOut;
begin
  FlushBufPart(BufLen,NLOfs);
end ;

procedure NL;
begin
  if AuxLevel>0 then
    Exit;
  FlushOut;
end ;

procedure SoftNL;
var
  Ch: Char;
begin
  if AuxLevel>0 then
    Exit;
  Ch := cSoftNL;
  BufChars(@Ch,1);
end ;

procedure InitOut;
begin
  NLOfs := 0;
  BufLen := 0;
  BufNLOfs := NLOfs;
end ;

function CharDumpStr(var V;N : integer): ShortString;
var
  C : array[1..255]of Char absolute V;
  i : integer ;
  S: ShortString;
  Ch: Char;
  TstAbs: byte absolute S;
begin
  if N>255 then
    N := 255;
  CharDumpStr[0] := Chr(N);
  for i := 1 to N do
    if C[i] < ' ' then
      CharDumpStr[i] := '.'
    else
      CharDumpStr[i] := C[i] ;
end ;

function DumpStrRaw(var V;N : integer): String;
var
  C : array[0..0]of Char absolute V;
  i : integer ;
  S: String;
begin
  SetLength(result,N);
  for i := 1 to N do
      result[i] := C[i] ;
end ;


function CharNStr(Ch: Char;N : integer): ShortString;
begin
  SetLength(Result,N);
  FillChar(Result[1],N,Ch);
end ;

type
  TByteChars = packed record Ch0,Ch1: Char end;

const
  Digit : array[0..15] of Char = '0123456789ABCDEF';

function ByteChars(B: Byte): Word;
var
  Ch: TByteChars;
begin
  Ch.Ch0 := Digit[B shr 4];
  Ch.Ch1 := Digit[B and $f];
  ByteChars := Word(Ch);
end ;

function DumpStr(var V;N : integer): String;
var
  i : integer ;
  BP: ^Byte;
  P: Pointer;
begin
  //Result[0] := Chr(N*3-1);
  SetLength(Result,N*3-1);
  P := @Result[1];
  BP := @V;
  for i := 1 to N do begin
    Word(P^) := ByteChars(BP^);
    Inc(Cardinal(P),2);
    Char(P^) := ' ';
    Inc(Cardinal(P));
    Inc(Cardinal(BP));
  end ;
end ;


function IsVTMEnd(var V;N : integer): String;
var
  i : integer ;
  BP: ^Byte;
  P: Pointer;
begin
  //Result[0] := Chr(N*3-1);
  SetLength(Result,N*3-1);
  P := @Result[1];
  BP := @V + 1;
  for i := 1 to N do begin
    Word(P^) := ByteChars(BP^);
    Inc(Cardinal(P),2);
    Char(P^) := ' ';
    Inc(Cardinal(P));
    Inc(Cardinal(BP));
  end ;
end ;


function DumpStr_pat(var V;N : integer): String;
var
  i : integer ;
  BP: ^Byte;
  P: Pointer;
begin
  //Result[0] := Chr(N*2);
  SetLength(Result,N*2);
  P := @Result[1];
  BP := @V;
  for i := 1 to N do begin
    Word(P^) := ByteChars(BP^);
    Inc(Cardinal(P),2);
//    Char(P^) := ' ';
//    Inc(Cardinal(P));
    Inc(Cardinal(BP));
  end ;
end ;

procedure ShowDump(DP: PChar; {Dump address}
  SizeDispl {used to calculate display offset digits},
  Size {Dump size}: Cardinal;
  Ofs0Displ {initial display offset},
  Ofs0 {offset in DCU data block - for fixups},
  WMin{Minimal dump width (in bytes)}: Cardinal;
  FixCnt: integer; FixTbl: PFixupTbl;
  FixUpNames: boolean; var OutS:String; var OutP:String);
const
  FmtS: String='%0.0x: %s';
var
  LP: PChar;
  LS,W: Cardinal;
  DS,DS_pat, FixS,FS,DumpFmt: String;
  DSP,CP: PChar;
  Sz,LSz: Cardinal;
  dOfs:integer;
  LCh,Ch: Char;
//  IsBig: boolean;
  FP: PFixupRec;
  K: Byte;
  N: PName;
  J: integer;
  Pattern: String;
  const char_len:integer = 2;
begin
  if integer(Size)<=0 then begin
    PutS('[]');
    Exit;
  end ;
  LSz := 0;
  if SizeDispl=0 then
    SizeDispl := Size;
  Sz := Ofs0Displ+SizeDispl;
  while Sz>0 do begin
    Inc(LSz);
    Sz := Sz shr 4;
  end ;
  W := 16;
  LCh := Chr(Ord('0')+LSz);
  FmtS[2] := LCh;
  FmtS[4] := LCh;
  LP := DP;
//  IsBig := Size>W;
  if Size<W then begin
    W := Size;
    if W<WMin then
      W := WMin;
  end ;
  if WMin>0 then
    DumpFmt := '|%-'+IntToStr(3*W-1)+'s|'
  else
    DumpFmt := '|%s|';
  FP := Pointer(FixTbl);
  if FP=Nil then
    FixCnt := 0 {Just in case};
  repeat
    LSz := W;
    if LSz>Size then
      LSz := Size;
    //WriteLn('lala3:',FmtS);
    //WriteLn(Ofs0Displ+(LP-DP));
    //WriteLn(CharDumpStr(LP^,LSz));
    //Flush(Output);
    //fn ofs     - Ofs0Displ+(LP-DP)
    //dump bytes - CharDumpStr(LP^,LSz)
    PutSFmt(FmtS,[Ofs0Displ+(LP-DP),CharDumpStr(LP^,LSz)]);
    if (LSz<W){and IsBig} then
      PutS(CharNStr(' ',W-LSz));
    //----
    DS := Format(DumpFmt{'|%s|'},[DumpStr(LP^,LSz)]);
    DSP := PChar(DS);
    DS_pat := Format('%s',[DumpStr_pat(LP^,LSz)]);

    if FixUpNames then
      FixS := '';
    while FixCnt>0 do begin
      //bug? must be in parents?
      //dOfs := FP^.OfsF and (FixOfsMask-Ofs0);
      dOfs := FP^.OfsF and FixOfsMask-Ofs0;
      K := TByte4(FP^.OfsF)[3];
      if (dOfs>=LSz)and not((dOfs=LSz)and(K={CurUnit.}fxEnd{LSz=Size})) then
        Break;
      CP := DSP+dOfs*3;
      case CP^ of
        '|': CP^ := '[';
        ' ': begin
          CP^ := '(';
          OutP += Format(' ^%4.4X ',[Ofs0Displ+(LP-DP) + dOfs]);
          Pattern := '[......]';
          for j := 1 to 4*char_len do begin
              if dOfs*char_len + j  <= DS_PAT.Length then
                 DS_pat[dOfs*char_len + j] := Pattern[j];
              //Insert('^', DS_pat, dOfs*3 + 1);
          end;
        end;
        '(','[': CP^ := '{';
      end ;
      if FixUpNames then begin
        FS := Format('DK%x %s',[K,CurUnit.GetAddrStr(FP^.NDX,true)]);
        if FixS='' then
          FixS := FS
        else
          FixS := Format('%s, %s',[FixS,FS]);
      end ;
      Dec(FixCnt);
      Inc(FP);
    end ;
    Inc(Ofs0,LSz);
    if (DS = '|E8(00 00 00 00      |') then begin
       WriteLn('lala4:',DS);
       Flush(Output);
    end;
    OutS += DS_pat;
    PutS(DS);
    if FixUpNames then begin
      OutS += FixS;
      PutS(FixS);
    end;
    {PutS('|');
    PutS(DumpStr(LP^,LSz));
    if (LSz<W)and IsBig then
      PutS(CharNStr(' ',3*(W-LSz)));}
    Dec(Size,LSz);
    Inc(LP,LSz);
    if Size>0 then
      NL;
  until Size<=0;
end ;


const vmtSelfPtr        = -52;// ; Pointer to self
const vmtInitTable      = -48;// ; Pointer to instance initialization table
const vmtTypeInfo       = -44;// ; Pointer to type information table
const vmtFieldTable     = -40;// ; Pointer to field definition table
const vmtMethodTable    = -36;// ; Pointer to method definition table
const vmtDynamicTable   = -32;// ; Pointer to dynamic method table
const vmtClassName      = -28;// ; Class name pointer
const vmtInstanceSize   = -24;// ; Instance size
const vmtParent         = -20;// ; Pointer to parent class
const vmtDefaultHandler = -16;// ; DefaultHandler method
const vmtNewInstance    = -12;// ; NewInstance method
const vmtFreeInstance   = -8 ;// ; FreeInstance method
const vmtDestroy        = -4 ;// ; destructor Destroy
const d2_vmt_ofs : array [0..12] of integer = (
vmtSelfPtr,vmtInitTable,vmtTypeInfo,vmtFieldTable,vmtMethodTable,vmtDynamicTable,
vmtClassName,vmtInstanceSize,vmtParent,vmtDefaultHandler,vmtNewInstance,
vmtFreeInstance,vmtDestroy);

function vmt_string(x:integer):string;
begin
  result:='                  ';
  case x of
    vmtSelfPtr          : result:='vmtSelfPtr        ';
    vmtInitTable        : result:='vmtInitTable      ';
    vmtTypeInfo         : result:='vmtTypeInfo       ';
    vmtFieldTable       : result:='vmtFieldTable     ';
    vmtMethodTable      : result:='vmtMethodTable    ';
    vmtDynamicTable     : result:='vmtDynamicTable   ';
    vmtClassName        : result:='vmtClassName      ';
    vmtInstanceSize     : result:='vmtInstanceSize   ';
    vmtParent           : result:='vmtParent         ';
    vmtDefaultHandler   : result:='vmtDefaultHandler ';
    vmtNewInstance      : result:='vmtNewInstance    ';
    vmtFreeInstance     : result:='vmtFreeInstance   ';
    vmtDestroy          : result:='vmtDestroy        ';
  end;
end;

function FixUpIndex(
  DataPos,
  Size {Dump size}: Cardinal;
  Ofs0Displ {initial display offset},
  Ofs0 {offset in DCU data block - for fixups},
  FixCnt: integer;
  FixTbl: PFixupTbl
  ):PFixupRec;
var
  FP: PFixupRec;
  dOfs:integer;
  K: Byte;
begin
  result := nil;
  FP := Pointer(FixTbl);
  if FP=Nil then FixCnt := 0;
  while FixCnt>0 do begin
    dOfs := FP^.OfsF and FixOfsMask-Ofs0;
    K := TByte4(FP^.OfsF)[3];
    if (dOfs>=Size)and not((dOfs=Size)and(K=fxEnd)) then
      Break;
    if (DataPos = dOfs + Ofs0Displ) then begin
      result := FP;
      exit;
    end;
    //OutS += Format('dOfs:%2.2X    disp:%2.2X    @:%4.4X     %4.4X    %s',[dOfs, Ofs0Displ, dOfs + Ofs0Displ, Ofs0, CurUnit.GetAddrStr(FP^.NDX,false)])+#13#10;
    Dec(FixCnt);
    Inc(FP);
  end ;

end;

procedure ShowDump2(DP: PChar; {Dump address}
  SizeDispl {used to calculate display offset digits},
  Size {Dump size}: Cardinal;
  Ofs0Displ {initial display offset},
  Ofs0 {offset in DCU data block - for fixups},
  WMin{Minimal dump width (in bytes)}: Cardinal;
  FixCnt: integer; FixTbl: PFixupTbl;
  FixUpNames: boolean; var OutS:String; var OutP:String);
const
  FmtS: String='%0.0x: %s';
var
  LP: PChar;
  LPs: PChar;
  LS: Cardinal;
  //W: Cardinal;
  DS,DS_pat, FixS,FS,DumpFmt,method_str,raw: String;
  DSP,CP: PChar;
  Sz:Cardinal;
  LSz: Cardinal;
  dOfs:integer;
  LCh,Ch: Char;
//  IsBig: boolean;
  FP: PFixupRec;
  K: Byte;
  N: PName;
  J,L: integer;
  Pattern: String;
  gap_str : String;
  ret_type_str : String;
  LastPos: integer;
  NewPos, dv, dm, i: integer;
  PropsBegin: Byte;
  NoVMT : boolean;
  D:TDCURec;
  vmtClassNamePtr:integer;
const
  char_len:integer = 2;
begin
  if integer(Size)<=0 then begin
    OutS+=PutS_pat('[]');
    Exit;
  end ;

  //moved to FixUpIndex
  //OutS += 'VMT:'#13#10;
  //FP := Pointer(FixTbl);
  //if FP=Nil then FixCnt := 0;
  //LSz := Size;
  //while FixCnt>0 do begin
  //  dOfs := FP^.OfsF and FixOfsMask-Ofs0;
  //  K := TByte4(FP^.OfsF)[3];
  //  if (dOfs>=LSz)and not((dOfs=LSz)and(K=fxEnd{LSz=Size})) then
  //    Break;
  //   OutS += Format('dOfs:%2.2X    disp:%2.2X    @:%4.4X     %4.4X    %s',[dOfs, Ofs0Displ, dOfs + Ofs0Displ, Ofs0, CurUnit.GetAddrStr(FP^.NDX,false)])+#13#10;
  //  Dec(FixCnt);
  //  Inc(FP);
  //end ;

  if (size - Ofs0Displ > 4) then begin
    i := 0;
    while i < size do begin

      //FixUp data; only for methods part of vmt; no props; no other;
      //todo: align and props
      FP := FixUpIndex(i, Size, Ofs0Displ, Ofs0, FixCnt, FixTbl);

      if conf_verbose > 10 then
      if not((i >= $30{D2}) and (FP = nil)) or (i<$30) then begin
        OutS += '/*';
        OutS += inttohex(i,4) + ' ';
        OutS += inttohex(PDWord((@DP^)+i-Ofs0Displ)^,8) + ' ';
        OutS += vmt_string(i+vmtSelfPtr);
        OutS += '*/';
      end;

      if (FP <> nil) and (i >= $24) then begin
        ret_type_str :='void ';
        D := CurUnit.GetAddrDef(FP^.NDX);
        if (i > $24{D2}) and ((D<>nil) and (D is TProcDecl)) then begin
           if (TProcDecl(D).hDTRes > 0) then
              ret_type_str := CurUnit.ShowTypeDef2(TProcDecl(D).hDTRes,Nil) + ' ';
        end;
        OutS += ret_type_str
        +'(*'
        + StringReplace(CurUnit.GetAddrStr(FP^.NDX,false),'.','_',[rfReplaceAll])
        + ') '
        + CurUnit.ShowDeclArgs2(FP^.NDX) + ';';
      end else if (i >= $30{D2}) then begin
          break;
      end else begin
          OutS += 'void (*' + vmt_string(i+vmtSelfPtr)+');';
      end;

      //dump class name from RTTI, if vmtClassName pointer present in VMT meta;
      if (i= $18) then begin
        vmtClassNamePtr:= integer(PInt32((@DP^)+i-Ofs0Displ)^);
        if (vmtClassNamePtr > 0) then
          OutS+='/*(' + CharDumpStr(PChar(@DP^+vmtClassNamePtr - Ofs0Displ + 1)^, Byte(PChar(@DP^+vmtClassNamePtr - Ofs0Displ)^)) + ')*/';
      end;
      OutS +=  #13#10;
      i+=4;

    end;
  end;
  //if Size > 64 then begin
     //raw := DumpStrRaw(DP^,Size);
     //fileputcontext_raw('vcl/rtti.1',raw);
  //end;
  exit;


  //old, more detailed, but ugly parser
  PropsBegin:=0;
  LSz := 0;
  //if SizeDispl=0 then
  //  SizeDispl := Size;
  //Ofs0Displ := 0;
  Sz := Ofs0Displ+Size;
  while Sz>0 do begin
    Inc(LSz);
    Sz := Sz shr 4;
  end ;
  //W := Size;
  LCh := Chr(Ord('0')+LSz);
  FmtS[2] := LCh;
  FmtS[4] := LCh;
  LP := DP;

  //if Size<W then begin
  //  W := Size;
  //  if W<WMin then
  //    W := WMin;
  //end ;
  //if WMin>0 then
  //  DumpFmt := '|%-'+IntToStr(3*W-1)+'s|'
  //else
    DumpFmt := '|%s|';
  LastPos := 0;
  NewPos := 0;
  FP := Pointer(FixTbl);
  if FP=Nil then
    FixCnt := 0 {Just in case};
  repeat
    LSz := Size;
    if LSz>Size then
      LSz := Size;
    //WriteLn('lala3:',FmtS);
    //WriteLn(Ofs0Displ+(LP-DP));
    //WriteLn(CharDumpStr(LP^,LSz));
    //Flush(Output);
    //fn ofs     - Ofs0Displ+(LP-DP)
    //dump bytes - CharDumpStr(LP^,LSz)

    //NO dump bin chars
    //OutS+=PutSFmt_pat(FmtS,[Ofs0Displ+(LP-DP),CharDumpStr(LP^,LSz)]);
    //if (LSz<W){and IsBig} then
    //  OutS+=PutS_pat(CharNStr(' ',W-LSz));

    //----
    DS := Format(DumpFmt{'|%s|'},[DumpStr(LP^,LSz)]);
    DSP := PChar(DS);
    DS_pat := Format('%s',[DumpStr_pat(LP^,LSz)]);

    if FixUpNames then
      FixS := '';
    while FixCnt>0 do begin
      dOfs := FP^.OfsF and FixOfsMask-Ofs0;
      K := TByte4(FP^.OfsF)[3];
      if (dOfs>=LSz)and not((dOfs=LSz)and(K={CurUnit.}fxEnd{LSz=Size})) then
        Break;
      CP := DSP+dOfs*3;
      case CP^ of
        '|': CP^ := '[';
        ' ': CP^ := '(';
        '(','[': CP^ := '{';
      end ;

      //D2 RTTI Parse
      if FixUpNames then begin

        //calculating and fill gaps between VMT fields
        //comment out `no vmt` lines
        NewPos := Ofs0Displ + (LP-DP) + dOfs;
        gap_str := '';//IsVTMEnd(LP^,3);
        if (NewPos - LastPos > 4) then begin

           //is gap; means VMT end
           if (NewPos > $20) then PropsBegin := 1;

           L := NewPos - LastPos - 4;
           dv := L shr 2;
           dm := L mod 4;
           For i := 1 to dv do begin
             //no VMT = [<0x20..firts gap<]
             NoVMT := ((LastPos + I*4) <= $20) or (PropsBegin > 0);
             if(conf_verbose > 10) and ((LastPos + I*4) >= $20) then begin
               if (NoVMT) then gap_str+= '//Not VMT2 '{+inttohex(LastPos + I*4)};
               gap_str+= Format('/*    PAD    4           %4.4X */ Char gap0x%2.2X[4],'#13#10,[LastPos + I*4,LastPos + I*4]);
             end;
           end;
           if (dm <> 0) then begin
              //no VMT = [<0x20..firts gap<]
              NoVMT := ((LastPos + dv*4 + dm) <= $20) or (PropsBegin > 0);
              if(conf_verbose > 10) and ((LastPos + dv*4 + dm) >= $20) then begin
                if (NoVMT) then gap_str+= '//Not VMT3 '{+inttohex(LastPos + dv*4 + dm)};
                gap_str+= Format('/*    PAD    %1.1X           %4.4X */ Char gap0x%2.2X[%4.4X],'#13#10,[dm, LastPos + dv*4 + dm, LastPos + dv*4 + dm, dm]);
              end;
           end;
        end;

        //no VMT = [<0x20..firts gap<]
        if (conf_verbose > 10) then begin
          NoVMT := ((integer(Ofs0Displ + (LP-DP) + dOfs)) <= $20) or (PropsBegin > 0);
          if (NoVMT) then gap_str+= '//Not VMT5 '{+inttohex(integer(Ofs0Displ + (LP-DP) + dOfs))};
        end;

        //dump class name from RTTI, if vmtClassName pointer present in VMT meta;
        if (integer(Ofs0Displ + (LP-DP) + dOfs) = $18) then begin
          vmtClassNamePtr:= integer(PChar(@LP^+$18 - Ofs0Displ)^);
          if (vmtClassNamePtr > 0) then begin
             gap_str+='/* name= ' + {inttohex(vmtClassNamePtr) + ' ' +}
                        CharDumpStr(PChar(@LP^+vmtClassNamePtr - Ofs0Displ + 1)^, Byte(PChar(@LP^+vmtClassNamePtr - Ofs0Displ)^)) + '*/ ';
          end;
        end;

        ret_type_str :='void (*';
        D := CurUnit.GetAddrDef(FP^.NDX);
        //D := CurUnit.GetTypeDef(i);
        if ((D<>nil) and(D is TProcDecl))then begin
          if (TProcDecl(D).hDTRes > 0) then
             ret_type_str := CurUnit.ShowTypeDef2(TProcDecl(D).hDTRes,Nil) + ' (*';
        end;

        method_str :=
        ''
        +ret_type_str
        +StringReplace(CurUnit.GetAddrStr(FP^.NDX,false),'.','_',[rfReplaceAll])
        +') '
        //+'|'
        //+ '('
        //+ inttohex(FP^.NDX) + ' '
        + CurUnit.ShowDeclArgs2(FP^.NDX);
        //+ ')'

        if (Ofs0Displ + (LP-DP) + dOfs < $24) {and (Ofs0Displ + (LP-DP) + dOfs <> $18)} then
           method_str := 'void* '+vmt_string(Ofs0Displ + (LP-DP) + dOfs + vmtSelfPtr);

        FS := Format('%s/*DK%x %s %4.4X */ %s',[gap_str, K, vmt_string(Ofs0Displ + (LP-DP) + dOfs + vmtSelfPtr) ,Ofs0Displ + (LP-DP) + dOfs,
        method_str
        ]);

        if FixS='' then
          FixS := FS
        else
          FixS := Format('%s;'#13#10'%s',[FixS,FS]);
        LastPos := NewPos;
      end ;
      Dec(FixCnt);
      Inc(FP);
    end ;
    Inc(Ofs0,LSz);
    //OutS += DS_pat;

    //no dump chars hex values
    //OutS+=PutS_pat(DS);

    if FixUpNames then begin
       OutS += PutS_pat(FixS+';');
       if (conf_verbose > 10) then
          OutS += '/*last*/';
    end;

    {PutS('|');
    PutS(DumpStr(LP^,LSz));
    if (LSz<W)and IsBig then
      PutS(CharNStr(' ',3*(W-LSz)));}
    Dec(Size,LSz);
    Inc(LP,LSz);
    if Size>0 then
      //NL;
      OutS += #13#10;
  until Size<=0;
end ;

function IntLStr(DP: Pointer; Sz: Cardinal; Neg: boolean): String;
var
  i : integer;
  BP: ^Byte;
  P: Pointer;
  V: integer;
  Ok: boolean;
begin
  if Neg then begin
    Ok := true;
    case Sz of
      1: V := ShortInt(DP^);
      2: V := SmallInt(DP^);
      4: V := LongInt(DP^);
    else
      Ok := false;
      if Sz=8 then begin
        V := LongInt(DP^);
        Inc(PChar(DP),4);
        NDXHi := LongInt(DP^);
        Result := NDXToStr(V);
        Exit;
      end ;
    end ;
    if Ok then begin
      //Result := IntToStr(V);
      if V>=0 then
        Result := Format('0x%x',[V])
      else
        Result := Format('-0x%x',[-V]);
      Exit;
    end ;
  end ;
  Pointer(BP) := PChar(DP)+Sz-1;
  SetLength(Result,Sz*2+2);
  P := PChar(Result);
  Char(P^) := '0';
  Inc(PChar(P));
  Char(P^) := 'x';
  Inc(PChar(P));
  for i := 1 to Sz do begin
    Word(P^) := ByteChars(BP^);
    Inc(PChar(P),2);
    Dec(PChar(BP));
  end ;
end ;

function CharStr(Ch: Char): String;
begin
  if Ch<' ' then
    Result := Format('#%d',[Byte(Ch)])
  else
    Result := Format('''%s''{#$%x}',[Ch,Byte(Ch)])
end ;

function CharStr2(Ch: Char): String;
begin
  if Ch<' ' then
    Result := Format('0x%d',[Byte(Ch)])
  else
    Result := Format('''%s''/*0x%x*/',[Ch,Byte(Ch)])
end ;


function WCharStr(WCh: WideChar): String;
var
  WStr: array[0..1]of WideChar;
  S: String;
  Ch: Char;
begin
  if Word(WCh)<$100 then
    Ch := Char(WCh)
  else begin
    WStr[0] := WCh;
    Word(WStr[1]) := 0;
    S := WideCharToString(WStr);
    Ch := S[1];
  end ;
  if Ch<' ' then
    Result := Format('#%d',[Word(WCh)])
  else
    Result := Format('''%s''{#$%x}',[Ch,Word(WCh)])
end ;

function WCharStr2(WCh: WideChar): String;
var
  WStr: array[0..1]of WideChar;
  S: String;
  Ch: Char;
begin
  if Word(WCh)<$100 then
    Ch := Char(WCh)
  else begin
    WStr[0] := WCh;
    Word(WStr[1]) := 0;
    S := WideCharToString(WStr);
    Ch := S[1];
  end ;
  if Ch<' ' then
    Result := Format('%d',[Word(WCh)])
  else
    Result := Format('''%s''/*%x*/',[Ch,Word(WCh)])
end ;


function BoolStr(DP: Pointer; DS: Cardinal): String;
var
  S: String;
  CP: PChar;
  All0: boolean;
begin
  CP := PChar(DP)+DS-1;
  while (CP>PChar(DP))and(CP^=#0)do
    Dec(CP);
  if (CP=PChar(DP)) then begin
    if CP^=#0 then begin
      Result := 'false';
      Exit;
    end ;
    if CP^=#1 then begin
      Result := 'true';
      Exit;
    end ;
  end ;
  Result := Format('true{%s}',[IntLStr(DP,DS,false)]);
end ;

function StrConstStr(CP: PChar; L: integer): String;
var
  WasCode,Code: boolean;
  ch: Char;
  LRes: integer;

  procedure PutCh(ch: Char);
  begin
    Inc(LRes);
    Result[LRes] := ch;
  end ;

  procedure PutStr(S: String);
  begin
    move(S[1],Result[LRes+1],Length(S));
    Inc(LRes,Length(S));
  end ;

  procedure PutQuote;
  begin
    PutCh('''');
  end ;

begin
  SetLength(Result,3*L+2);
  LRes := 0;
  Code := true;
  while L>0 do begin
    ch := CP^;
    Inc(CP);
    Dec(L);
    WasCode := Code;
    Code := ch<' ';
    if WasCode<>Code then
      PutQuote;
    if Code then
      PutStr(CharStr(Ch))
    else begin
      if Ch='''' then
        PutQuote;
      PutCh(Ch);
    end ;
  end ;
  if not Code then
    PutQuote;
  if LRes=0 then
    Result := ''''''
  else
    SetLength(Result,LRes);
end ;

end.
