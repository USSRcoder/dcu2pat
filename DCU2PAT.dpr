{$APPTYPE CONSOLE}
program DCU2PAT;
{
  DCU2PAT -> fork of DCU32INT utility by Alexei Hmelnov
  with ugly hack, for make IDA patern files also.
  With *.int files, also created .pat files;
}
(*
The main module of the DCU32INT utility by Alexei Hmelnov.
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
  Windows,
  SysUtils,
  DCU32 in 'DCU32.pas',
  DCUTbl in 'DCUTbl.pas',
  DCU_In in 'DCU_In.pas',
  DCU_Out in 'DCU_Out.pas',
  FixUp in 'FixUp.pas';

{$R *.RES}

procedure WriteUsage;
begin
  Writeln(
  'Usage:'#13#10+
  '  DCU2PAT <Source file> <Flags> [<Destination file>]'#13#10+
  'Destination file may contain * to be replaced by unit name or name and extension'#13#10+
  'Destination file = "-" => write to stdout.'#13#10+
  'Flags (start with "/" or "-"):'#13#10+
  ' -S<show flag>* - Show flags (-S - show all), default: (+) - on, (-) - off'#13#10+
  '    I(+) - show Imported names'#13#10+
  '    T(-) - show Type table'#13#10+
  '    A(-) - show Address table'#13#10+
  '    D(-) - show Data block'#13#10+
  '    F(-) - show fixups'#13#10+
  '    V(-) - show auxiliary Values'#13#10+
  '    M(-) - don''t resolve class methods'#13#10+
  '    C(-) - don''t resolve constant values'#13#10+
  '    d(-) - show dot types'#13#10+
  '    v(-) - show VMT'#13#10+
  ' -I - interface part only'#13#10+
  ' -U<paths> = Unit directories'#13#10+
  ' -N<Prefix> = No Name Prefix ("%" - Scope char)'#13#10+
  ' -D<Prefix> = Dot Name Prefix ("%" - Scope char)'#13#10+
  ''#13#10
  );
end ;

const
  DCUName: String = '';
  FNRes: String = '';
  FNRes_pat: String = '';

function ProcessParms: boolean;
var
  i,j: integer;
  PS: String;
  Ch: Char;
begin
  Result := false;
  for i:=1 to ParamCount do begin
    PS := ParamStr(i);
    if (Length(PS)>1)and((PS[1]='/')or(PS[1]='-')) then begin
      Ch := UpCase(PS[2]);
      case Ch of
        'S': begin
          if Length(PS)=2 then
            SetShowAll
          else begin
            for j:=3 to Length(PS) do begin
              Ch := {UpCase(}PS[j]{)};
              case Ch of
                'I': ShowImpNames := false;
                'T': ShowTypeTbl := true;
                'A': ShowAddrTbl := true;
                'D': ShowDataBlock := true;
                'F': ShowFixupTbl := true;
                'V': ShowAuxValues := true;
                'M': ResolveMethods := false;
                'C': ResolveConsts := false;
                'd': ShowDotTypes := true;
                'v': ShowVMT := true;
              else
                Writeln('Unknown show flag: "',Ch,'"');
                Exit;
              end ;
            end ;
          end ;
        end ;
        'I': InterfaceOnly := true;
        'U': begin
          Delete(PS,1,2);
          DCUPath := PS;
        end ;
        'N': begin
          Delete(PS,1,2);
          NoNamePrefix := PS;
        end ;
        'D': begin
          Delete(PS,1,2);
          DotNamePrefix := PS;
        end ;
      else
        Writeln('Unknown flag: "',Ch,'"');
        Exit;
      end ;
      Continue;
    end ;
    if DCUName='' then
      DCUName := PS
    else if FNRes='' then
      FNRes := PS
    else
      Exit;
  end ;
  Result := DCUName<>'';
end ;

function ReplaceStar(FNRes,FN: String): String;
var
  CP: PChar;
begin
  CP := StrScan(PChar(FNRes),'*');
  if CP=Nil then begin
    Result := FNRes;
    Exit;
  end ;
  if StrScan(CP+1,'*')<>Nil then
    raise Exception.Create('2nd "*" is not allowed');
  FN := ExtractFilename(FN);
  if (CP+1)^=#0 then begin
    Result := Copy(FNRes,1,CP-PChar(FNRes))+ChangeFileExt(FN,'.int');
    Exit;
  end;
  Result := Copy(FNRes,1,CP-PChar(FNRes))+ChangeFileExt(FN,'')+Copy(FNRes,CP-PChar(FNRes)+2,MaxInt);
end ;

function ProcessFile(FN: String): integer {ErrorLevel};
var
  U: TUnit;
  ExcS: String;
  SaveOut: Text;
  OutRedir: boolean;
begin
  Result := 0;
  OutRedir := false;
  if FNRes<>'-' then begin
    Writeln{(StdErr)};
    Writeln('File: "',FN,'"');
    if FNRes='' then
      FNRes := ChangeFileExt(FN,'.int')
    else
      FNRes := ReplaceStar(FNRes,FN);

    FNRes_pat := ChangeFileExt(FNRes,'.pat');
    Writeln('Result: "',FNRes,'"');
    Writeln('Pat   : "',FNRes_pat,'"');
//    CloseFile(Output);
    Flush(Output);
    TTextRec(SaveOut) := TTextRec(Output);
    AssignFile(Output,FNRes);

    AssignFile(FNPat, FNRes_pat);
    Rewrite(FNPat);

    OutRedir := true;
  end ;
  try
    try
      Rewrite(Output); //Test whether the FNRes is a correct file name
      try
        InitOut;
        U := GetDCUByName(FN,0,0){TUnit.Create(FN)};
        U.Show;
      finally
        FreeDCU;
      end ;
    except
      on E: Exception do begin
        Result := 1;
        ExcS := Format('%s: "%s"',[E.ClassName,E.Message]);
        if TTextRec(Output).Mode<>fmClosed then begin
          Writeln;
          Writeln(ExcS);
          Flush(Output);
        end ;
        if OutRedir then
          Writeln(SaveOut,ExcS);
      end ;
    end ;
  finally
    if OutRedir then
      Close(SaveOut);
    if TTextRec(Output).Mode<>fmClosed then
      Close(Output);

    if TTextRec(FNPat).Mode<>fmClosed then
      Close(FNPat);
  end ;
end ;

begin
  if not ProcessParms then begin
    WriteUsage;
    Exit;
  end ;
  Halt(ProcessFile(DCUName));
end.
