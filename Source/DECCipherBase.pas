{*****************************************************************************
  The DEC team (see file NOTICE.txt) licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License. A copy of this licence is found in the root directory of
  this project in the file LICENCE.txt or alternatively at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
*****************************************************************************}
unit DECCipherBase;

interface

{$I DECOptions.inc}

uses
  SysUtils, Classes, DECBaseClass, DECFormatBase, DECUtil;

type
  /// <summary>
  ///   Null cipher, doesn't encrypt, only copy
  /// </summary>
  TCipher_Null          = class;

  /// <summary>
  ///   Possible kindes of cipher algorithms
  /// </summary>
  TCipherTypes = (ctStream, ctBlock, ctSymmetric, ctAsymmetric);

  /// <summary>
  ///   Actual kind of cipher algorithm
  /// </summary>
  TCipherType = set of TCipherTypes;

  /// <summary>
  ///   Record containing meta data about a certain cipher
  /// </summary>
  TCipherContext = packed record
    /// <summary>
    ///   maximal key size in bytes
    /// </summary>
    KeySize    : Integer;
    /// <summary>
    ///   mininmal block size in bytes, e.g. 1 = Streamcipher
    /// </summary>
    BlockSize  : Integer;
    /// <summary>
    ///   internal buffersize in bytes
    /// </summary>
    BufferSize : Integer;
    /// <summary>
    ///   internal size in bytes of cipher dependend structures
    /// </summary>
    UserSize   : Integer;
    UserSave   : Boolean;

    /// <summary>
    ///   Specifies the kind of cipher
    /// </summary>
    CipherType : TCipherType;
  end;

  /// <summary>
  ///   TCipher.State represents the internal state of processing
  /// <para>
  ///   csNew : cipher isn't initialized, .Init() must be called before en/decode
  /// </para>
  /// <para>
  ///   csNew : cipher isn't initialized, .Init() must be called before en/decode
  /// </para>
  /// <para>
  ///   csInitialized : cipher is initialized by .Init(), i.e. Keysetup was processed
  /// </para>
  /// <para>
  ///   csEncode : Encoding was started, and more chunks can be encoded, but not decoded
  /// </para>
  /// <para>
  ///   csDecode : Decoding was started, and more chunks can be decoded, but not encoded
  /// </para>
  /// <para>
  ///   csPadded : trough En/Decoding the messagechunks are padded, no more chunks can
  ///                   be processed, the cipher is blocked
  /// </para>
  /// <para>
  ///   csDone : Processing is finished and Cipher.Done was called. Now new En/Decoding
  ///            can be started without calling .Init() before. csDone is basically
  ///            identical to csInitialized, except Cipher.Buffer holds the encrypted
  ///            last state of Cipher.Feedback, thus Cipher.Buffer can be used as C-MAC.
  /// </para>
  /// </summary>
  TCipherState = (csNew, csInitialized, csEncode, csDecode, csPadded, csDone);
  /// <summary>
  ///   Set of cipher states, representing the internal state of processing
  /// </summary>
  TCipherStates = set of TCipherState;

  /// <summary>
  ///   This defines how the individual blocks of the data to be processed are
  ///   linked with each other.
  ///
  ///   Modes cmCBCx, cmCTSx, cmCTSxx, cmCFBx, cmOFBx, cmCFSx, cmECBx are working
  ///   on Blocks of Cipher.BufferSize bytes, when using a Blockcipher that's equal
  ///   to Cipher.BlockSize.
  ///
  ///   Modes cmCFB8, cmOFB8, cmCFS8 work on 8 bit Feedback Shift Registers.
  ///
  ///   Modes cmCTSx, cmCFSx, cmCFS8 are proprietary modes developed by Hagen
  ///   Reddmann. These modes works as cmCBCx, cmCFBx, cmCFB8 but with double
  ///   XOR'ing of the inputstream into Feedback register.
  ///
  ///   Mode cmECBx needs message padding to be a multiple of Cipher.BlockSize and
  ///   should be used only in 1-byte Streamciphers.
  ///
  ///   Modes cmCFB8, cmCFBx, cmOFB8, cmOFBx, cmCFS8 and cmCFSx need no padding.
  ///
  ///   Modes cmCTSx, cmCBCx need no external padding, because internally the last
  ///   truncated block is padded by cmCFS8 or cmCFB8. After padding these Modes
  ///   cannot be used to process any more data. If needed to process chunks of
  ///   data then each chunk must be algined to Cipher.BufferSize bytes.
  ///
  ///   Mode cmCTS3 is a proprietary mode developed by Frederik Winkelsdorf. It
  ///   replaces the CFS8 padding of the truncated final block with a CFSx padding.
  ///   Useful when converting projects that previously used the old DEC v3.0. It
  ///   has the same restrictions for external padding and chunk processing as
  ///   cmCTSx has.
  /// </summary>
  TCipherMode = (
    cmCTSx,   // double CBC, with CFS8 padding of truncated final block
    cmCBCx,   // Cipher Block Chaining, with CFB8 padding of truncated final block
    cmCFB8,   // 8bit Cipher Feedback mode
    cmCFBx,   // CFB on Blocksize of Cipher
    cmOFB8,   // 8bit Output Feedback mode
    cmOFBx,   // OFB on Blocksize bytes
    cmCFS8,   // 8Bit CFS, double CFB
    cmCFSx,   // CFS on Blocksize bytes
    cmECBx    // Electronic Code Book
    {$IFDEF DEC3_CMCTS}
    ,cmCTS3   // double CBC, with less secure padding of truncated final block
              // for DEC 3.0 compatibility only (see DECOptions.inc)
    {$ENDIF DEC3_CMCTS}
  );

  /// <summary>
  ///   Each cipher algorithm has to implement a Encode and a Decode method which
  ///   has the same signature as this type. The CipherFormats get these
  ///   encode/decode methods passed to do their work.
  /// </summary>
  /// <param name="Source">
  ///   Contains the data to be encoded or decoded
  /// </param>
  /// <param name="Dest">
  ///   Contains the data after encoding or decoding
  /// </param>
  /// <param name="DataSize">
  ///   Number of bytes to encode or decode
  /// </param>
  TDECCipherCodeEvent = procedure(const Source; var Dest; DataSize: Integer) of object;

  /// <summary>
  ///   Class type of the cipher base class
  /// </summary>
  TDECCipherClass = class of TDECCipher;

  /// <summary>
  ///   Base class for all implemented cipher algorithms
  /// </summary>
  /// <remarks>
  ///   When adding new block ciphers do never directly inherit from this class!
  ///   Inherit from TDECCipherFormats.
  /// </remarks>
  TDECCipher = class(TDECObject)
  strict private
    FData     : PByteArray;
    FDataSize : Integer;

    /// <summary>
    ///   Sets the cipher mode, means how each block is being linked with his
    ///   predecessor to avoid certain attacks
    /// </summary>
    procedure SetMode(Value: TCipherMode);
  strict protected
    /// <summary>
    ///   Padding Mode
    /// </summary>
    FMode: TCipherMode;
    /// <summary>
    ///   Current processing state
    /// </summary>
    FState: TCipherState;
    FBufferSize: Integer;
    FBufferIndex: Integer;
    FUserSize: Integer;
    FBuffer: PByteArray;
    FVector: PByteArray;
    FFeedback: PByteArray;
    /// <summary>
    ///   Seems to be a pointer to the last element of FBuffer?
    /// </summary>
    FUser: Pointer;
    FUserSave: Pointer;
    procedure CheckState(States: TCipherStates);

    /// <summary>
    ///   Initialize the key, based on the key passed in
    /// </summary>
    /// <param name="Key">
    ///   Encryption/Decryption key to be used
    /// </param>
    /// <param name="Size">
    ///   Size of the key passed in bytes. 
    /// </param>
    procedure DoInit(const Key; Size: Integer); virtual; abstract;
    procedure DoEncode(Source, Dest: Pointer; Size: Integer); virtual; abstract;
    procedure DoDecode(Source, Dest: Pointer; Size: Integer); virtual; abstract;
  public
    /// <summary>
    ///   List of registered DEC classes. Key is the Identity of the class.
    /// </summary>
    class var ClassList : TDECClassList;

    /// <summary>
    ///   Tries to find a class type by its name
    /// </summary>
    /// <param name="Name">
    ///   Name to look for in the list
    /// </param>
    /// <returns>
    ///   Returns the class type if found. if it could not be found a
    ///   EDECClassNotRegisteredException will be thrown
    /// </returns>
    class function ClassByName(const Name: string): TDECCipherClass;

    /// <summary>
    ///   Tries to find a class type by its numeric identity DEC assigned to it.
    ///   Useful for file headers, so they can easily encode numerically which
    ///   cipher class was being used.
    /// </summary>
    /// <param name="Identity">
    ///   Identity to look for
    /// </param>
    /// <returns>
    ///   Returns the class type of the class with the specified identity value
    ///   or throws an EDECClassNotRegisteredException exception if no class
    ///   with the given identity has been found
    /// </returns>
    function ClassByIdentity(Identity: Int64): TDECCipherClass;

    /// <summary>
    ///   Initializes the instance. Relies in parts on information given by the
    ///   Context class function.
    /// </summary>
    constructor Create; override;
    /// <summary>
    ///   Frees internal structures and where necessary does so in a save way so
    ///   that data in those structures cannot be "stolen".
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Provides meta data about the cipher algorithm used like key size.
    ///   To be overidden in the concrete cipher classes.
    /// </summary>
    /// <remarks>
    ///   C++ does not support virtual static functions thus the base cannot be
    ///   marked 'abstract'. Calling this version of the method will lead to an
    ///   EDECAbstractError
    /// </remarks>
    class function Context: TCipherContext; virtual;

    /// <summary>
    ///   Initializes the cipher with the necessary encryption/decryption key
    /// </summary>
    /// <param name="Key">
    ///   Encryption/decryption key. Recommended/required key length is dependant
    ///   on the concrete algorithm.
    /// </param>
    /// <param name="Size">
    ///   Size of the key in bytes
    /// </param>
    /// <param name="IVector">
    ///   Initialization vector. This contains the values the first block of
    ///   data to be processed is linked with. This is being done the same way
    ///   as the 2nd block of the data to be processed will be linked with the
    ///   first block and so on and this is dependant on the cypher mode set via
    ///   Mode property
    /// </param>
    /// <param name="IVectorSize">
    ///   Size of the initialization vector in bytes
    /// </param>
    /// <param name="IFiller">
    ///   optional parameter defining the value with which the last block will
    ///   be filled up if the size of the data to be processed cannot be divided
    ///   by block size without reminder. Means: if the last block is not
    ///   completely filled with data.
    /// </param>
    procedure Init(const Key; Size: Integer; const IVector; IVectorSize: Integer; IFiller: Byte = $FF); overload;
    /// <summary>
    ///   Initializes the cipher with the necessary encryption/decryption key
    /// </summary>
    /// <param name="Key">
    ///   Encryption/decryption key. Recommended/required key length is dependant
    ///   on the concrete algorithm.
    /// </param>
    /// <param name="IVector">
    ///   Initialization vector. This contains the values the first block of
    ///   data to be processed is linked with. This is being done the same way
    ///   as the 2nd block of the data to be processed will be linked with the
    ///   first block and so on and this is dependant on the cypher mode set via
    ///   Mode property
    /// </param>
    /// <param name="IFiller">
    ///   optional parameter defining the value with which the last block will
    ///   be filled up if the size of the data to be processed cannot be divided
    ///   by block size without reminder. Means: if the last block is not
    ///   completely filled with data.
    /// </param>
    procedure Init(const Key: TBytes; const IVector: TBytes; IFiller: Byte = $FF); overload;
    /// <summary>
    ///   Initializes the cipher with the necessary encryption/decryption key
    /// </summary>
    /// <param name="Key">
    ///   Encryption/decryption key. Recommended/required key length is dependant
    ///   on the concrete algorithm.
    /// </param>
    /// <param name="IVector">
    ///   Initialization vector. This contains the values the first block of
    ///   data to be processed is linked with. This is being done the same way
    ///   as the 2nd block of the data to be processed will be linked with the
    ///   first block and so on and this is dependant on the cypher mode set via
    ///   Mode property
    /// </param>
    /// <param name="IFiller">
    ///   optional parameter defining the value with which the last block will
    ///   be filled up if the size of the data to be processed cannot be divided
    ///   by block size without reminder. Means: if the last block is not
    ///   completely filled with data.
    /// </param>
    procedure Init(const Key: RawByteString; const IVector: RawByteString = ''; IFiller: Byte = $FF); overload;
    {$IFNDEF NEXTGEN}
    /// <summary>
    ///   Initializes the cipher with the necessary encryption/decryption key.
    ///   Only for use with the classic desktop compilers.
    /// </summary>
    /// <param name="Key">
    ///   Encryption/decryption key. Recommended/required key length is dependant
    ///   on the concrete algorithm.
    /// </param>
    /// <param name="IVector">
    ///   Initialization vector. This contains the values the first block of
    ///   data to be processed is linked with. This is being done the same way
    ///   as the 2nd block of the data to be processed will be linked with the
    ///   first block and so on and this is dependant on the cypher mode set via
    ///   Mode property
    /// </param>
    /// <param name="IFiller">
    ///   optional parameter defining the value with which the last block will
    ///   be filled up if the size of the data to be processed cannot be divided
    ///   by block size without reminder. Means: if the last block is not
    ///   completely filled with data.
    /// </param>
    procedure Init(const Key: AnsiString; const IVector: AnsiString = ''; IFiller: Byte = $FF); overload;
    /// <summary>
    ///   Initializes the cipher with the necessary encryption/decryption key.
    ///   Only for use with the classic desktop compilers.
    /// </summary>
    /// <param name="Key">
    ///   Encryption/decryption key. Recommended/required key length is dependant
    ///   on the concrete algorithm.
    /// </param>
    /// <param name="IVector">
    ///   Initialization vector. This contains the values the first block of
    ///   data to be processed is linked with. This is being done the same way
    ///   as the 2nd block of the data to be processed will be linked with the
    ///   first block and so on and this is dependant on the cypher mode set via
    ///   Mode property
    /// </param>
    /// <param name="IFiller">
    ///   optional parameter defining the value with which the last block will
    ///   be filled up if the size of the data to be processed cannot be divided
    ///   by block size without reminder. Means: if the last block is not
    ///   completely filled with data.
    /// </param>
    procedure Init(const Key: WideString; const IVector: WideString = ''; IFiller: Byte = $FF); overload;
    {$ENDIF}

    /// <summary>
    ///   Properly finishes the cryptographic operation. It needs to be called
    ///   at the end of encrypting or decrypting data, otherwise the last block
    ///   or last byte of the data will not be properly processed.
    /// </summary>
    procedure Done;

    /// <summary>
    ///   Sets the processing state to csNew, which means that before using this
    ///   object any further,  init must be called and it securely fills the
    ///   processing buffer with zeroes.
    /// </summary>
    procedure Protect; virtual;

    // Encoding / Decoding Routines
    // Do not add further methods of that kind here! If needed add them to
    // TDECFormattedCipher in DECCipherFormats or inherit from that one.

    /// <summary>
    ///   Encrypts the contents of a RawByteString. This method is deprecated
    ///   and should be replaced by a variant expecting TBytes as source in
    ///   order to not support mistreating strings as binary buffers.
    /// </summary>
    /// <remarks>
    ///   This is the direct successor of the EncodeBinary method from DEC 5.2
    /// </remarks>
    /// <param name="Source">
    ///   The data to be encrypted
    /// </param>
    /// <param name="Format">
    ///   Optional parameter. Here a formatting method can be passed. The
    ///   resulting encrypted data will be formatted with this function, if one
    ///   has been passed. Examples are hex or base 64 formatting.
    /// </param>
    /// <returns>
    ///   Encrypted data. Init must have been called previously.
    /// </returns>
    function EncodeRawByteString(const Source: RawByteString;
                                 Format: TDECFormatClass = nil): RawByteString; deprecated; // please use EncodeBytes functions now
    /// <summary>
    ///   Decrypts the contents of a RawByteString. This method is deprecated
    ///   and should be replaced by a variant expecting TBytes as source in
    ///   order to not support mistreating strings as binary buffers.
    /// </summary>
    /// <remarks>
    ///   This is the direct successor of the DecodeBinary method from DEC 5.2
    /// </remarks>
    /// <param name="Source">
    ///   The data to be decrypted
    /// </param>
    /// <param name="Format">
    ///   Optional parameter. Here a formatting method can be passed. The
    ///   data to be decrypted will be formatted with this function, if one
    ///   has been passed. Examples are hex or base 64 formatting.
    ///   This is used for removing a formatting applied by the EncodeRawByteString
    ///   method.
    /// </param>
    /// <returns>
    ///   Decrypted data. Init must have been called previously.
    /// </returns>
    function DecodeRawByteString(const Source: RawByteString;
                                 Format: TDECFormatClass = nil): RawByteString; deprecated; // please use DecodeBytes functions now

    /// <summary>
    ///   Encrypts the contents of a ByteArray.
    /// </summary>
    /// <param name="Source">
    ///   The data to be encrypted
    /// </param>
    /// <param name="Format">
    ///   Optional parameter. Here a formatting method can be passed. The
    ///   resulting encrypted data will be formatted with this function, if one
    ///   has been passed. Examples are hex or base 64 formatting.
    /// </param>
    /// <returns>
    ///   Encrypted data. Init must have been called previously.
    /// </returns>
    function EncodeBytes(const Source: TBytes; Format: TDECFormatClass = nil): TBytes;
    /// <summary>
    ///   Decrypts the contents of a ByteArray.
    /// </summary>
    /// <param name="Source">
    ///   The data to be decrypted
    /// </param>
    /// <param name="Format">
    ///   Optional parameter. Here a formatting method can be passed. The
    ///   data to be decrypted will be formatted with this function, if one
    ///   has been passed. Examples are hex or base 64 formatting.
    ///   This is used for removing a formatting applied by the EncodeRawByteString
    ///   method.
    /// </param>
    /// <returns>
    ///   Decrypted data. Init must have been called previously.
    /// </returns>
    function DecodeBytes(const Source: TBytes; Format: TDECFormatClass): TBytes;

    // MAC
{ TODO : Variante mit TBytes zwar unten auch pro forma umgesetzt, jedoch mit R�ckgriff auf
  DECUtils.RawStringToBytes und overload geht nicht, wenn nur der R�ckgabetyp unterschiedlich}
//    function CalcMAC(Format: TDECFormatClass = nil): TBytes; overload;

    function CalcMAC(Format: TDECFormatClass = nil): RawByteString; overload; deprecated; // please use the TBytes based overload;

    // properties

    /// <summary>
    ///   Provides the size of the initialization vector in bytes.
    /// </summary>
    property InitVectorSize: Integer
      read   FBufferSize;
    /// <summary>
    ///   Provides access to the contents of the initialization vector
    /// </summary>
    property InitVector: PByteArray
      read   FVector; //

    property Feedback: PByteArray
      read   FFeedback; // buffer size bytes
    /// <summary>
    ///   Allows to query the current internal processing state
    /// </summary>
    property State: TCipherState
      read   FState;
    /// <summary>
    ///   Mode used for padding data to be encrypted/decrypted. See TCipherMode.
    /// </summary>
    property Mode: TCipherMode
      read   FMode
      write  SetMode;
  end;

  /// <summary>
  ///   A do nothing cipher, usefull for debugging and development purposes. Do
  ///   not use it for actual encryption as it will not encrypt anything at all!
  /// </summary>
  TCipher_Null = class(TDECCipher)
  protected
    procedure DoInit(const Key; Size: Integer); override;
    procedure DoEncode(Source, Dest: Pointer; Size: Integer); override;
    procedure DoDecode(Source, Dest: Pointer; Size: Integer); override;
  public
    /// <summary>
    ///   Provides meta data about the cipher algorithm used like key size.
    /// </summary>
    class function Context: TCipherContext; override;
  end;

function ValidCipher(CipherClass: TDECCipherClass = nil): TDECCipherClass;
procedure SetDefaultCipherClass(CipherClass: TDECCipherClass = nil);

implementation

uses
  TypInfo, DECData;

{$IFOPT Q+}{$DEFINE RESTORE_OVERFLOWCHECKS}{$Q-}{$ENDIF}
{$IFOPT R+}{$DEFINE RESTORE_RANGECHECKS}{$R-}{$ENDIF}

resourcestring
  sAlreadyPadded        = 'Cipher has already been padded, cannot process message';
  sInvalidState         = 'Cipher is not in valid state for this action';
  sNoKeyMaterialGiven   = 'No Keymaterial given (Security Issue)';
  sKeyMaterialTooLarge  = 'Keymaterial is too large for use (Security Issue)';
  sIVMaterialTooLarge   = 'Initvector is too large for use (Security Issue)';
  sInvalidMACMode       = 'Invalid Cipher mode to compute MAC';
  sCipherNoDefault      = 'No default cipher has been registered';

var
  FDefaultCipherClass: TDECCipherClass = nil;

function ValidCipher(CipherClass: TDECCipherClass): TDECCipherClass;
begin
  if CipherClass <> nil then
    Result := CipherClass
  else
    Result := FDefaultCipherClass;

  if Result = nil then
    raise EDECCipherException.Create(sCipherNoDefault);
end;

procedure SetDefaultCipherClass(CipherClass: TDECCipherClass);
begin
  FDefaultCipherClass := CipherClass;
end;

{ TDECCipher }

constructor TDECCipher.Create;
var
  MustUserSaved: Boolean;
begin
  inherited Create;

  FBufferSize   := Context.BufferSize;
  FUserSize     := Context.UserSize;
  MustUserSaved := Context.UserSave;

  FDataSize := FBufferSize * 3 + FUserSize;

  if MustUserSaved then
    Inc(FDataSize, FUserSize);

  // ReallocMemory instead of ReallocMem due to C++ compatibility as per 10.1 help
  FData     := ReallocMemory(FData, FDataSize);
  FVector   := @FData[0];
  FFeedback := @FVector[FBufferSize];
  FBuffer   := @FFeedback[FBufferSize];
  FUser     := @FBuffer[FBufferSize];

  if MustUserSaved then
    FUserSave := @PByteArray(FUser)[FUserSize]
  else
    FUserSave := nil;

  Protect;
end;

destructor TDECCipher.Destroy;
begin
  Protect;
  // FreeMem instead of ReallocMemory which produced a memory leak. ReallocMemory
  // was used instead of ReallocMem due to C++ compatibility as per 10.1 help
  FreeMem(FData, FDataSize);
  FVector   := nil;
  FFeedback := nil;
  FBuffer   := nil;
  FUser     := nil;
  FUserSave := nil;
  inherited Destroy;
end;

procedure TDECCipher.SetMode(Value: TCipherMode);
begin
  if Value <> FMode then
  begin
    if not (FState in [csNew, csInitialized, csDone]) then
      Done;

    FMode := Value;
  end;
end;

procedure TDECCipher.CheckState(States: TCipherStates);
var
  s: string;
begin
  if not (FState in States) then
  begin
    if FState = csPadded then
      s := sAlreadyPadded
    else
      s := sInvalidState;
    raise EDECCipherException.Create(s);
  end;
end;

function TDECCipher.ClassByIdentity(Identity: Int64): TDECCipherClass;
begin
  result := TDECCipherClass(ClassList.ClassByIdentity(Identity));
end;

class function TDECCipher.ClassByName(const Name: string): TDECCipherClass;
begin
  result := TDECCipherClass(ClassList.ClassByName(Name));
end;

class function TDECCipher.Context: TCipherContext;
begin
  // C++ does not support virtual static functions thus the base cannot be
  // marked 'abstract'. This is our workaround:
  raise EDECAbstractError.Create(Self);
end;

procedure TDECCipher.Init(const Key; Size: Integer; const IVector; IVectorSize: Integer; IFiller: Byte);
begin
  Protect;

  if (Size > Context.KeySize) and (ClassType <> TCipher_Null) then
    raise EDECCipherException.Create(sKeyMaterialTooLarge);

  if IVectorSize > FBufferSize then
    raise EDECCipherException.Create(sIVMaterialTooLarge);

  DoInit(Key, Size);
  if FUserSave <> nil then
    Move(FUser^, FUserSave^, FUserSize);

  FillChar(FVector^, FBufferSize, IFiller);
  if IVectorSize = 0 then
  begin
    DoEncode(FVector, FVector, FBufferSize);
    if FUserSave <> nil then
      Move(FUserSave^, FUser^, FUserSize);
  end
  else
    Move(IVector, FVector^, IVectorSize);

  Move(FVector^, FFeedback^, FBufferSize);

  FState := csInitialized;
end;

procedure TDECCipher.Init(const Key: TBytes; const IVector: TBytes; IFiller: Byte = $FF);
begin
  if Length(Key) = 0 then
    raise EDECCipherException.Create(sNoKeyMaterialGiven);

  if IVector <> nil then
    Init(Key[0], Length(Key), IVector[0], Length(IVector), IFiller)
  else
    Init(Key[0], Length(Key), NullStr, 0, IFiller);
end;

procedure TDECCipher.Init(const Key: RawByteString; const IVector: RawByteString = ''; IFiller: Byte = $FF);
begin
  if Length(Key) = 0 then
    raise EDECCipherException.Create(sNoKeyMaterialGiven);

  if Length(IVector) > 0 then
    Init(Key[Low(Key)], Length(Key) * SizeOf(Key[Low(Key)]),
         IVector[Low(IVector)], Length(IVector) * SizeOf(IVector[Low(IVector)]), IFiller)
  else
    Init(Key[Low(Key)], Length(Key) * SizeOf(Key[Low(Key)]), NullStr, 0, IFiller);
end;


{$IFNDEF NEXTGEN}
procedure TDECCipher.Init(const Key, IVector: AnsiString; IFiller: Byte);
begin
  if Length(Key) = 0 then
    raise EDECCipherException.Create(sNoKeyMaterialGiven);

  if Length(IVector) > 0 then
    Init(Key[Low(Key)], Length(Key) * SizeOf(Key[Low(Key)]),
         IVector[Low(IVector)], Length(IVector) * SizeOf(IVector[Low(IVector)]), IFiller)
  else
    Init(Key[Low(Key)], Length(Key) * SizeOf(Key[Low(Key)]), NullStr, 0, IFiller);
end;
{$ENDIF}


{$IFNDEF NEXTGEN}
procedure TDECCipher.Init(const Key, IVector: WideString; IFiller: Byte);
begin
  if Length(Key) = 0 then
    raise EDECCipherException.Create(sNoKeyMaterialGiven);

  if Length(IVector) > 0 then
    Init(Key[Low(Key)], Length(Key) * SizeOf(Key[Low(Key)]),
         IVector[Low(IVector)], Length(IVector) * SizeOf(IVector[Low(IVector)]), IFiller)
  else
    Init(Key[Low(Key)], Length(Key) * SizeOf(Key[Low(Key)]), NullStr, 0, IFiller);
end;
{$ENDIF}

procedure TDECCipher.Done;
begin
  if FState <> csDone then
  begin
    FState := csDone;
    FBufferIndex := 0;
    DoEncode(FFeedback, FBuffer, FBufferSize);
    Move(FVector^, FFeedback^, FBufferSize);
    if FUserSave <> nil then
      Move(FUserSave^, FUser^, FUserSize);
  end;
end;

procedure TDECCipher.Protect;
begin
  FState := csNew;
  ProtectBuffer(FData[0], FDataSize);
end;

function TDECCipher.EncodeRawByteString(const Source: RawByteString; Format: TDECFormatClass): RawByteString;
var
  b : TBytes;
begin
  SetLength(b, 0);
  if Length(Source) > 0 then
  begin
    SetLength(b, Length(Source) * SizeOf(Source[Low(Source)]));
    DoEncode(@Source[low(Source)], @b[0], Length(Source) * SizeOf(Source[low(Source)]));
    Result := BytesToRawString(ValidFormat(Format).Encode(b));
  end;
end;

function TDECCipher.EncodeBytes(const Source: TBytes; Format: TDECFormatClass = nil): TBytes;
begin
  SetLength(Result, 0);
  if Length(Source) > 0 then
  begin
    SetLength(Result, Length(Source) * SizeOf(Source[0]));
    DoEncode(@Source[0], @Result[0], Length(Source) * SizeOf(Source[0]));
    Result := ValidFormat(Format).Encode(Result);
  end;
end;

function TDECCipher.DecodeRawByteString(const Source: RawByteString; Format: TDECFormatClass): RawByteString;
var
  b : TBytes;
begin
  SetLength(Result, 0);
  if Length(Source) > 0 then
  begin
{ TODO :
In Delphi 10.1 Berlin on mobile this issues a W1057 implicit string
conversion warning as https://quality.embarcadero.com/browse/RSP-20574
shows that BytesOf(Val: RawByteString) is in an IFNDEF NextGen block! }
    b := ValidFormat(Format).Decode(BytesOf(Source));

    DoDecode(@b[0], @Result[Low(Result)], Length(Result) * SizeOf(Result[Low(Result)]));
  end;
end;

function TDECCipher.DecodeBytes(const Source: TBytes; Format: TDECFormatClass): TBytes;
begin
  SetLength(Result, 0);
  if Length(Source) > 0 then
  begin
    Result := ValidFormat(Format).Decode(Source);
    DoDecode(@Result[0], @Result[0], Length(Result) * SizeOf(Result[0]));
  end;
end;


function TDECCipher.CalcMAC(Format: TDECFormatClass): RawByteString;
begin
  Done;
  if FMode in [cmECBx] then
    raise EDECException.Create(sInvalidMACMode)
  else
    Result := ValidFormat(Format).Encode(FBuffer^, FBufferSize);
  { TODO : Wie umschreiben? EncodeBytes direkt kann so nicht aufgerufen werden }
end;

//function TDECCipher.CalcMAC(Format: TDECFormatClass): TBytes;
//begin
//  Done;
//  if FMode in [cmECBx] then
//    raise EDECCipherException.Create(sInvalidMACMode)
//  else
//  begin
//    Result := DECUtil.RawStringToBytes(ValidFormat(Format).Encode(FBuffer^, FBufferSize));
//  end;
//end;

{ TCipher_Null }

class function TCipher_Null.Context: TCipherContext;
begin
  Result.KeySize := 0;
  Result.BlockSize := 1;
  Result.BufferSize := 32;
  Result.UserSize := 0;
  Result.UserSave := False;
end;

procedure TCipher_Null.DoInit(const Key; Size: Integer);
begin
  // dummy
end;

procedure TCipher_Null.DoEncode(Source, Dest: Pointer; Size: Integer);
begin
  if Source <> Dest then
    Move(Source^, Dest^, Size);
end;

procedure TCipher_Null.DoDecode(Source, Dest: Pointer; Size: Integer);
begin
  if Source <> Dest then
    Move(Source^, Dest^, Size);
end;

{$IFDEF RESTORE_RANGECHECKS}{$R+}{$ENDIF}
{$IFDEF RESTORE_OVERFLOWCHECKS}{$Q+}{$ENDIF}

{$IFDEF DELPHIORBCB}
procedure ModuleUnload(Instance: NativeInt);
var // automaticaly deregistration/releasing
  i: Integer;
begin
  if TDECCipher.ClassList <> nil then
  begin
    for i := TDECCipher.ClassList.Count - 1 downto 0 do
    begin
      if NativeInt(FindClassHInstance(TClass(TDECCipher.ClassList[i]))) = Instance then
        TDECCipher.ClassList.Remove(TDECCipher.ClassList[i].Identity);
    end;
  end;
end;
{$ENDIF DELPHIORBCB}

initialization
  // Code for packages and dynamic extension of the class registration list
  {$IFDEF DELPHIORBCB}
  AddModuleUnloadProc(ModuleUnload);
  {$ENDIF DELPHIORBCB}

  TDECCipher.ClassList := TDECClassList.Create;

  TCipher_Null.RegisterClass(TDECCipher.ClassList);
finalization
  // Ensure no further instances of classes registered in the registraiotn list
  // are possible through the list after this unit has been unloaded by unloding
  // the package this unit is in
  {$IFDEF DELPHIORBCB}
  RemoveModuleUnloadProc(ModuleUnload);
  {$ENDIF DELPHIORBCB}

  TDECCipher.ClassList.Free;

end.
