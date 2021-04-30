(*
 * http �����ú���
 *)
unit http_utils;

interface

{$I in_iocp.inc}

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.SysUtils, System.DateUtils, {$ELSE}
  Windows, SysUtils, DateUtils, {$ENDIF}
  http_base;

function AdjustFileName(const FileName: AnsiString): AnsiString;
function ChangeSlash(const FileName: AnsiString): AnsiString;

function CreateBoundary: AnsiString;
function CompareBuffer(Buf: PAnsiChar; const S: AnsiString; IgnoreCase: Boolean = False): Boolean;

function CheckUTFEncode(const Text: AnsiString; var Count: Integer): Boolean;
function DecodeHexText(const Text: AnsiString): AnsiString;
function ExtractFieldInf(var Buf: PAnsiChar; Len: Integer; var FieldValue: AnsiString): TFormElementType;

function GetFieldType(const ParamVal: AnsiString): THttpFieldType;
function GetContentType(const FileName: AnsiString): AnsiString;
function GetHexSize(Size: Integer): AnsiString; 

function GetHttpGMTDateTime: AnsiString; overload;
function GetHttpGMTDateTime(const FileTime: TFileTime): AnsiString; overload;
function GetLocalDateTime(const HttpGMTDateTime: AnsiString): TDateTime;

function FindInBuffer(Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;
function FindInBuffer2(Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;

function SearchInBuffer(var Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;
function SearchInBuffer2(var Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;

function InURLEncode(const URL: AnsiString): AnsiString;

implementation

uses
  iocp_utils;
                 
// =======================================

function AdjustFileName(const FileName: AnsiString): AnsiString;
var
  i: Integer;
  p, p2: PAnsiChar;
  IsSlash: Boolean;
begin
  // �����ļ����ƣ�/,// �� \

  if (FileName = '') then
    Exit;
    
  SetLength(Result, Length(FileName));

  p := PAnsiChar(FileName);
  p2 := PAnsiChar(Result);

  IsSlash := (p^ = '/');
  for i := 1 to Length(FileName) do
    if (p^ <> '/') then
    begin
      p2^ := p^;
      Inc(p); Inc(p2);
      IsSlash := False;
    end else
    begin
      if (i = 1) or (IsSlash = False) then
      begin
        p2^ := p^;
        Inc(p); Inc(p2);
      end else
        Inc(p);
      IsSlash := True;
    end;

  Delete(Result, p2 - PAnsiChar(Result) + 1, 9999);

end;

function ChangeSlash(const FileName: AnsiString): AnsiString;
var
  i: Integer;
  p, p2: PAnsiChar;
begin
  // ·�� \ �� /
  SetLength(Result, Length(FileName));
  p := PAnsiChar(FileName);
  p2 := PAnsiChar(Result);
  for i := 1 to Length(FileName) do
  begin
    if (p^ = '\') then
      p2^ := '/'
    else
      p2^ := p^;
    Inc(p);
    Inc(p2);
  end;
end;

function CreateBoundary: AnsiString;
begin
  // ���ɷָ���(����)
  Result := '-----iniocp-boundary-' + IntToHex(GetTickCount, 2);
end;

function CompareBuffer(Buf: PAnsiChar; const S: AnsiString;
         IgnoreCase: Boolean = False): Boolean;
var
  i: Integer;
  p: PAnsiChar;
begin
  // �Ƚ� Buf��S �������Ƿ���ͬ��IgnoreCase = True ʱ�����Դ�Сд��
  Result := True;
  p := PAnsiChar(S);
  for i := 1 to Length(S) do
    if (IgnoreCase = False) and (Buf^ = p^) or
       IgnoreCase and ((Buf^ = p^) or (AnsiChar(Ord(Buf^) - 32) = p^)) then
    begin
      Inc(Buf);
      Inc(p);
    end else
    begin
      Result := False;
      Break;
    end;
end;

function CheckUTFEncode(const Text: AnsiString; var Count: Integer): Boolean;
var
  Byt: Byte;
  pB, pE: PAnsiChar;
begin
  // �ж��Ƿ��� UTF-8 ���룺�����������磬���Ż���
  //                          ������Ҫȫ������ UTF-8 �������
  // 2�ֽڣ�110xxxxx 10xxxxxx
  // 3�ֽڣ�1110xxxx 10xxxxxx 10xxxxxx

  Count := 0;  // �ַ�����
  Result := True;

  pB := PAnsiChar(Text);
  pE := pB + Length(Text);

  while Result and (pB < pE) do
  begin
    Byt := Byte(pB^);
    if (Byt < $80) then  // ֵС��0x80=128��ΪASCII�ַ�
    begin
      Inc(pB);
      Inc(Count);
    end else
    if (Byt < $E0) then  // �˷�Χ��Ϊ2�ֽ�UTF-8�ַ�
    begin
      Result := Result and (pB < pE) and (Byte((pB + 1)^) and $C0 = $80);
      Inc(pB, 2);
      Inc(Count, 2);
    end else
    if (Byt < $F0) then  // �˷�Χ��Ϊ3�ֽ�UTF-8�ַ�
    begin
      Result := Result and (pB < pE - 1) and (Byte((pB + 1)^) and $C0 = $80) and
                           (Byte((pB + 2)^) and $C0 = $80);
      Inc(pB, 3);
      Inc(Count, 2);
    end else  // �������Ϊ��Ч��UTF-8�ַ�
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function DecodeHexText(const Text: AnsiString): AnsiString;
  function _DecodeChar(var Buf: PAnsiChar): AnsiChar; {$IFDEF USE_INLINE} inline; {$ENDIF}
  var
    Value: SmallInt;
  begin
    // ����ʮ�������ַ���ǰһ�ַ�Ӧ��Ϊ %��
    // %D2%BB%B8%F6%CE%C4%B1%BE%A1%A3
    Inc(Buf);
    if (Ord(Buf^) >= 97) then          // Сд A..Z = 97..
      Buf^ := AnsiChar(Ord(Buf^) - 32);

    if (Buf^ in ['0'..'9']) then       // Asc(0) = 48
      Value := (Ord(Buf^) - 48) shl 4
    else
      Value := (Ord(Buf^) - 55) shl 4; // Asc(A) = 65, ��Ӧ 10

    Inc(Buf);
    if (Buf^ in ['0'..'9']) then
      Inc(Value, Ord(Buf^) - 48)
    else
      Inc(Value, Ord(Buf^) - 55);

    Result := AnsiChar(Value);
  end;
var
  p, p2: PAnsiChar;
begin
  // ����ʮ�������ַ�������ʽ��
  // %D2%BB%B8%F6%CE%C4%B1%BE%A1%A3++a
  // ����� UTF ʱҪ���� UTF8Decode()

  SetLength(Result, Length(Text));

  p := PAnsiChar(Text);
  p2 := PAnsiChar(Result);

  try
    while (p^ <> #0) do
    begin
      case p^ of
        #37:  // �ٷֺ� MODULUS %
          if ((p + 1)^ in ['0'..'9', 'a'..'f', 'A'..'F']) then
            p2^ := _DecodeChar(p)
          else
            p2^ := p^;
        #43:  // �Ӻ� +
          p2^ := #32;
        else  // ����
          p2^ := p^;
      end;
      Inc(p);
      Inc(p2);
    end;

    SetLength(Result, p2 - PAnsiChar(Result));
  except
    Result := Text;
  end;

end;

function ExtractFieldInf(var Buf: PAnsiChar; Len: Integer;
         var FieldValue: AnsiString): TFormElementType;
var
  i: Integer;
  b, eq: PAnsiChar;
begin
  // ��ȡԪ�������ڵ����ݣ����ƻ��ļ���
  
  // ---------------------Boundary
  // Content-Disposition: form-data; name="textline2"; filename="����.txt"
  // <Empty Line>
  // Value Text

  b := Nil;                 // ���ƿ�ʼ
  eq := Nil;                // �Ⱥ�λ��

  FieldValue := '';
  Result := fdtUnknown;

  for i := 1 to Len do
  begin
    case Buf^ of
      'a'..'z',
      'A'..'Z', '_':        // Ԫ�����ơ���������
        if (b = nil) then   // = �Ҳ�
          b := Buf;

      '=': begin            // ���ͽ���
       //  FieldValue := GetStringValue(b, Integer(Buf - b));
        SetString(FieldValue, b, Integer(Buf - b));
        b := Nil;
        eq := Buf;

        // �ж��Ƿ�Ϊ�ļ�����
        FieldValue := UpperCase(FieldValue);
        if (FieldValue = 'NAME') then
          Result := fdtName
        else
        if (FieldValue = 'FILENAME') then
          Result := fdtFileName;
      end;

      '''', '"',
       ';', #13:             // ���� �� �ļ����ƽ���
        if (eq <> Nil) then  // = �Ҳ�����
          if (b = nil) then
            b := PAnsiChar(Buf + 1)
          else begin
          //  FieldValue := GetStringValue(b, Integer(Buf - b));
            SetString(FieldValue, b, Integer(Buf - b));
            if (i < Len) then
              Inc(Buf);
            Break;
          end;
    end;

    Inc(Buf);
  end;

end;

function GetFieldType(const ParamVal: AnsiString): THttpFieldType;
var
  i: Integer;
  DotCount: Integer;
begin
  // ����ַ����Ƿ�Ϊ���ִ�
  Result := hftString;
  if (ParamVal = '') or (Length(ParamVal) >= 10) then
    Exit;
  DotCount := 0;
  for i := 1 to Length(ParamVal) do
    case ParamVal[i] of
      '-', '+':
        if (i > 1) then   // ���Ǹ��š�����
          Exit;
      '0'..'9':
        { Empty } ;
      '.': begin
        Inc(DotCount);
        if (DotCount > 1) then
          Exit;
      end;
      else
        Exit;
    end;
  if (DotCount = 1) then
    Result := hftFloat
  else
    Result := hftInteger;
end;

function GetContentType(const FileName: AnsiString): AnsiString;
var
  i: Integer;
  Extension: AnsiString;
begin
  // ȡ�ļ�����: Content-type
  Extension := LowerCase(ExtractFileExt(FileName));
  for i := 1 to High(CONTENT_TYPES) do
    if (Extension = CONTENT_TYPES[i].Extension) then
    begin
      Result := CONTENT_TYPES[i].ContentType;
      Exit;
    end;
  Result := CONTENT_TYPES[0].ContentType;
end;

function GetHexSize(Size: Integer): AnsiString;
begin
  // �ѳ���תΪʮ�������ַ���
  Result := IntToHex(Size, 2);
end;

function _FileTimeToHttpGMTDateTime(const FileTime: TFileTime): AnsiString;
type
  TDblChar = array[0..1] of AnsiChar;
  TThrChar = array[0..2] of AnsiChar;

  PDateTimeFormat = ^TDateTimeFormat;
  TDateTimeFormat = packed record
    DayOfWeek: TThrChar; S: TDblChar;
    Day: TDblChar; S2: AnsiChar;
    Month: TThrChar; S3: AnsiChar;
    Year: TDblChar; Year2: TDblChar; S4: AnsiChar;
    Hour: TDblChar; S5: AnsiChar;
    Minute: TDblChar; S6: AnsiChar;
    Second: TDblChar; S7: AnsiChar;
  end;
  
const
  WEEK_DAYS: array[0..6] of TThrChar = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');

  MONTH_NAMES: array[1..12] of TThrChar = (
     'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',  'Jul',
     'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

  NUMBERS: array[0..99] of TDblChar = (
     '00', '01', '02', '03', '04', '05', '06', '07', '08', '09',
     '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
     '20', '21', '22', '23', '24', '25', '26', '27', '28', '29',
     '30', '31', '32', '33', '34', '35', '36', '37', '38', '39',
     '40', '41', '42', '43', '44', '45', '46', '47', '48', '49',
     '50', '51', '52', '53', '54', '55', '56', '57', '58', '59',
     '60', '61', '62', '63', '64', '65', '66', '67', '68', '69',
     '70', '71', '72', '73', '74', '75', '76', '77', '78', '79',
     '80', '81', '82', '83', '84', '85', '86', '87', '88', '89',
     '90', '91', '92', '93', '94', '95', '96', '97', '98', '99');
var
  SysTime: TSystemTime;
  p: PDateTimeFormat;
  i: Integer;  
begin
  // ȡ GMT ʱ��
  //   Wed, 09 Jun 2021 10:18:14 GMT

  FileTimeToSystemTime(FileTime, SysTime);  // UTC

  Result := 'Wed, 09 Jun 2021 10:18:19 GMT';
  p := PDateTimeFormat(@Result[1]);

  // ����
  p^.DayOfWeek := WEEK_DAYS[SysTime.wDayOfWeek];

  // �ա���
  p^.Day := NUMBERS[SysTime.wDay];
  p^.Month := MONTH_NAMES[SysTime.wMonth];

  // ��
  i := SysTime.wYear div 100;
  p^.Year := NUMBERS[i];
  p^.year2 := NUMBERS[SysTime.wYear - i * 100];

  // ʱ���֡���
  p^.Hour := NUMBERS[SysTime.wHour];
  p^.Minute := NUMBERS[SysTime.wMinute];
  p^.Second := NUMBERS[SysTime.wSecond];

end;

function GetHttpGMTDateTime: AnsiString;
var
  FileTime: TFileTime;
begin
  GetSystemTimeAsFileTime(FileTime);
  Result := _FileTimeToHttpGMTDateTime(FileTime);
end;

function GetHttpGMTDateTime(const FileTime: TFileTime): AnsiString;
begin
  Result := _FileTimeToHttpGMTDateTime(FileTime);
end;

function GetLocalDateTime(const HttpGMTDateTime: AnsiString): TDateTime;
const
  MONTH_NAMES: array[1..12] of AnsiString = (
          'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',  'JUL',
          'AUG', 'SEP', 'OCT', 'NOV', 'DEC');
  function GetMonthIndex(const S: AnsiString): Integer;
  var
    i: Integer;
  begin
    for i := 1 to High(MONTH_NAMES) do
      if (MONTH_NAMES[i] = S) then
      begin
        Result := i;
        Exit;
      end;
    Result := 0;
  end;
var
  i: Integer;
  S: AnsiString;
  wYear, wDay, wMonth: Word;
  wHour, wMin, wSec: Word;
begin
  // Http GMT ʱ��ת����ʱ��
  //    Wed, 27 Nov 2017 10:26:16 GMT
  if (Length(HttpGMTDateTime) < 22) then  // ���Բ�����,��֮ǰ�����ݺ� ��GMT��
    Exit;

  i := Pos(',', HttpGMTDateTime);

  if (i > 0) then
    try
      // ��
      if (HttpGMTDateTime[i + 1] = #32) then
        Inc(i, 2)
      else
        Inc(i);

      S := Copy(HttpGMTDateTime, i, 2);
      wDay := StrToInt(S);

      // ��
      Inc(i, 3);
      S := Copy(HttpGMTDateTime, i, 3);
      wMonth := GetMonthIndex(UpperCase(S));

      if (wMonth = 0) then
        Exit;

      // ��
      Inc(i, 4);
      S := Copy(HttpGMTDateTime, i, 4);
      wYear := StrToInt(S);

      // ʱ:��:��
      Inc(i, 5);
      S := Copy(HttpGMTDateTime, i, 2);
      wHour := StrToInt(S);

      S := Copy(HttpGMTDateTime, i + 3, 2);
      wMin := StrToInt(S);

      S := Copy(HttpGMTDateTime, i + 6, 2);
      wSec := StrToInt(S);

      // ����ת��
      if TryEncodeDateTime(wYear, wMonth, wDay,
                           wHour, wMin, wSec, 0, Result) then
        Result := Result + 0.33333333   // + 8 Сʱ
      else
        Result := -1;

    except
      //
    end;
end;

function FindInBuffer(Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;
begin
  Result := SearchInBuffer(Buf, Len, Text);
end;

function FindInBuffer2(Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;
begin
  Result := SearchInBuffer2(Buf, Len, Text);
end;

function SearchInBuffer(var Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;
var
  i, n, k: Integer;
  s, s2: PAnsiChar;
begin
  // ��λ Text�����ִ�Сд���� Buf ��λ�ú�һ�ֽڣ�Buf ͬʱ�ƶ�
  //   AB1231ACD1234AEnaMe, 1234, NAME -> 10, 16

  s := PAnsiChar(Text);  // Text ��ʼλ��
  s2 := s;               // Text ��ǰλ��

  k := Length(Text);     // Text ����
  n := 0;                // ƥ�����

  Result := False;
  for i := 1 to Len do
  begin
    if (Buf^ = s2^) then
    begin
      Inc(n);            // ƥ����+
      if (n = k) then    // ȫ��ƥ��ɹ�
      begin
        Inc(Buf);        // ����һ�ֽ�
        Result := True;  // λ�� = LongWord(buf - b) - k + 1;
        Exit;
      end else
        Inc(s2);         // ��һ�ֽ�
    end else
    if (n > 0) then      // ƥ���
    begin
      n := 0;            // ���� 0
      s2 := s;           // ��λ����ʼλ��
    end;

    Inc(Buf);
  end;

end;

function SearchInBuffer2(var Buf: PAnsiChar; Len: Integer; const Text: AnsiString): Boolean;
var
  i, n, k: Integer;
  s, s2: PAnsiChar;
begin
  // ��λ Text�����ִ�Сд���� Buf ��λ�ú�һ�ֽڣ�Buf ͬʱ�ƶ�
  //   AB1231ACD1234AEnaMe, 1234, NAME -> 10, 16

  s := PAnsiChar(Text);  // Text ��ʼλ��
  s2 := s;               // Text ��ǰλ��

  k := Length(Text);     // Text ����
  n := 0;                // ƥ�����

  Result := False;
  for i := 1 to Len do
  begin
    if (Buf^ = s2^) or   // = ����Сд
       (Ord(Buf^) in [97..122]) and (AnsiChar(Ord(Buf^) - 32) = s2^) then
    begin
      Inc(n);            // ƥ����+
      if (n = k) then    // ȫ��ƥ��ɹ�
      begin
        Inc(Buf);        // ����һ�ֽ�
        Result := True;  // λ�� = LongWord(buf - b) - k + 1;
        Exit;
      end else
        Inc(s2);         // ��һ�ֽ�
    end else
    if (n > 0) then      // ƥ���
    begin
      n := 0;            // ���� 0
      s2 := s;           // ��λ����ʼλ��
    end;

    Inc(Buf);
  end;

end;

function InURLEncode(const URL: AnsiString): AnsiString;
var
  S: AnsiString;
  p, p2: PAnsiChar;
begin
  // ת������ URL �ַ���Ϊ Hex ����
  //   Դ��� httpApp.HTTPEncode
  SetLength(Result, Length(S) * 3);

  p := PAnsiChar(S);
  p2 := PAnsiChar(Result);

  while (p^ <> #0) do
  begin
    case p^ of
      'A'..'Z', 'a'..'z', '0'..'9', // ��ת����RFC 1738
      '*', '@', '.', '_', '-',
      '$', '!', '''', '(', ')':
        p2^ := p^;
      #32:  // �ո�
        p2^ := '+';
      else
        begin
          FormatBuf(p2^, 3, '%%%.2x', 6, [Ord(p^)]);
          Inc(p2, 2);
        end;
    end;
    Inc(p);
    Inc(p2);
  end;

  SetLength(Result, p2 - PAnsiChar(Result));

end;

end.
