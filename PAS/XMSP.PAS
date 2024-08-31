{***********************************************************************
*                            X M S P . P A S                           *
**--------------------------------------------------------------------**
*  Sujet        : D‚monstration de l'accŠs … la m‚moire ‚tendue et de  *
*                 la zone High Memory … l'aide des fonctions XMS telles*
*                 qu'elles sont appliqu‚es par exemple avec le pilote  *
*                 de p‚riph‚riques HIMEM.SYS.                          *
**--------------------------------------------------------------------**
*  Auteur        : MICHAEL TISCHER                                     *
*  D‚velopp‚ le  : 27.07.1990                                          *
*  DerniŠre MAJ  : 29.03.1992                                          *
***********************************************************************}

program XMSP;

uses Crt, Dos;              { Pour appel interruption et accŠs clavier }

const ERR_NOERR          = $00;                         { Pas d'erreur }
      ERR_NOTIMPLEMENTED = $80;            { Fonction appel‚e inconnue }
      ERR_VDISKFOUND     = $81;               { Ram disk VDISK d‚tect‚ }
      ERR_A20            = $82;      { Erreur sur canal d'adresses A20 }
      ERR_GENERAL        = $8E;    { Erreur pilote … caractŠre g‚n‚ral }
      ERR_UNRECOVERABLE  = $8F;                  { Erreur irratrapable }
      ERR_HMANOTEXIST    = $90;                      { HMA introuvable }
      ERR_HMAINUSE       = $91;                     { HMA d‚j… appel‚e }
      ERR_HMAMINSIZE     = $92;              { Taille HMA insuffisante }
      ERR_HMANOTALLOCED  = $93;                     { HMA non affect‚e }
      ERR_A20STILLON     = $94;    { Canal d'adresses A20 encore actif }
      ERR_OUTOMEMORY     = $A0;   { Plus de m‚moire ‚tendue disponible }
      ERR_OUTOHANDLES    = $A1;        { Ts les identifs XMS sont pris }
      ERR_INVALIDHANDLE  = $A2;              { Identificateur invalide }
      ERR_SHINVALID      = $A3;       { Identificateur source invalide }
      ERR_SOINVALID      = $A4;             { D‚calage source invalide }
      ERR_DHINVALID      = $A5;  { Identificateur destination invalide }
      ERR_DOINVALID      = $A6;        { D‚calage destination invalide }
      ERR_LENINVALID     = $A7; { Longueur invalide pour fonction Move }
      ERR_OVERLAP        = $A8;                { Recouvrement interdit }
      ERR_PARITY         = $A9;                     { Erreur de parit‚ }
      ERR_EMBUNLOCKED    = $AA;                 { UMB n'est pas bloqu‚ }
      ERR_EMBLOCKED      = $AB;                { UMB est encore bloqu‚ }
      ERR_LOCKOVERFLOW   = $AC;   { D‚bordement du compteur de blocage }
      ERR_LOCKFAIL       = $AD;        { L'UMB ne peut pas ˆtre bloqu‚ }
      ERR_UMBSIZETOOBIG  = $B0;            { Plus petit UMB disponible }
      ERR_NOUMBS         = $B1;                { Plus d'UMB disponible }
      ERR_INVALIDUMB     = $B2;{ L'adresse du segment UMB est invalide }

type XMSRegs = record                    { Informations pour appel XMS }
                 AX,               { Seuls les registres AX, BX, DX et }
                 BX,                { SI sont requis selon la fonction }
                 DX,                 { appel‚e, il faut donc une autre }
                 SI,                              { adresse de segment }
                 Segment : word
               end;

{-- Variables globales ------------------------------------------------}

var XMSPtr : pointer;     { Pointeur sur Extended Memory Manager (XMM) }
    XMSErr : BYTE;            { Code d'erreur de la derniŠre op‚ration }

{***********************************************************************
* XMSInit : Initialise les routines d'appel des fonctions XMS          *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Sortie : TRUE si pilote XMS identifi‚ sinon FALSE                    *
* Info    : - L'appel de cette fonction doit pr‚c‚der celui de toutes  *
*             les autres proc‚dures et fonctions ‚manant de ce         *
*             programme.                                               *
***********************************************************************}

function XMSInit : boolean;

var Regs : Registers;             { Registre pour appel d'interruption }
    xr : XMSRegs;

begin
  Regs.AX := $4300;             { D‚tecte disponibilit‚ du XMS Manager }
  intr( $2F, Regs );
  if ( Regs.AL = $80 ) then                     { D‚tect‚ XMS-Manager? }
    begin                                                        { Oui }
      Regs.AX := $4310;               { Retourner point d'accŠs au XMM }
      intr( $2F, Regs );
      XMSPtr := ptr( Regs.ES, Regs.BX );  { Copie adresse ds var glob. }
      XMSErr := ERR_NOERR;                      { Pas d'erreur apparue }
      XMSInit := true;             { Trouv‚ handler, module initialis‚ }
    end
  else                                { XMS handler n'est pas install‚ }
   XMSInit := false;
end;

{***********************************************************************
* XMSCall : Routine g‚n‚rale d'appel d'une fonction XMS                *
**--------------------------------------------------------------------**
* Entr‚e : NumFonc = Num‚ro de la fonction XMS appelante               *
*            XRegs = Structure de registres pour appel de fonction     *
* Info    : - Avant l'appel de cette proc‚dure, charger excusivement   *
*             les registres effectivement n‚cessaires … l'appel de la  *
*             fonction.                                                *
*           - AprŠs l'appel de la fonction XMS, les contenus des       *
*             registres du processeur sont copi‚s dans les composants  *
*             correspondants de la structure renvoy‚e.                 *
*           - Le premier appel de cette proc‚dure doit ˆtre pr‚c‚d‚    *
*             d'un appel en bon ordre de la proc‚dure XMSInit.         *
***********************************************************************}

procedure XMSCall( NumFonc : byte; var XRegs : XMSRegs );

begin
  inline ( $8C / $D9 /                          { mov    cx,ds        *}
           $51 /                                { push   cx           *}
           $C5 / $BE / $04 / $00 /              { lds    di,[bp+0004] *}
           $8A / $66 / $08 /                    { mov    ah,[bp+0008] *}
           $8B / $9D / $02 / $00 /              { mov    bx,[di+0002] *}
           $8B / $95 / $04 / $00 /              { mov    dx,[di+0004] *}
           $8B / $B5 / $06 / $00 /              { mov    si,[di+0006] *}
           $8E / $5D / $08 /                    { mov    ds,[di+08]   *}
           $8E / $C1 /                          { mov    es,cx        *}
           $26 / $FF / $1E / XMSPtr /           { call   es:[XMSPTr]  *}
           $8C / $D9 /                          { mov    cx,ds        *}
           $C5 / $7E / $04 /                    { lds    di,[bp+04]   *}
           $89 / $05 /                          { mov    [di],ax      *}
           $89 / $5D / $02 /                    { mov    [di+02],bx   *}
           $89 / $55 / $04 /                    { mov    [di+04],dx   *}
           $89 / $75 / $06 /                    { mov    [di+06],si   *}
           $89 / $4D / $08 /                    { mov    [di+08],cx   *}
           $1F                                  { pop    ds           *}
        );

     {-- Tests codes erreur -------------------------------------------}

  if ( XRegs.AX = 0 ) and ( XRegs.BX >= 128 ) then
    begin
      XMSErr := Lo(XRegs.BX)             { Erreur, stocker code erreur }
      {
       .
       .
       .
         emplacement ‚ventuel pour un autre traitement d'erreur
       .
       .
       .
      }
    end
  else
    XMSErr := ERR_NOERR;                     { Pas d'erreur, ‡a baigne }
end;

{***********************************************************************
* XMSQueryVer: Renvoie le nø de version de l'XMS et autres informations*
*              sur l'‚tat                                              *
**--------------------------------------------------------------------**
* Entr‚e : VerNr = Stocke nø de version aprŠs appel de la fonction     *
*                  (Format: 235 = 2.35)                                *
*           RevNr = Stocke nø de r‚vision aprŠs appel de la fonction   *
* Sortie : TRUEsi un HMA est disponible sinon FALSE                    *
***********************************************************************}

function XMSQueryVer( var VerNr, RevNr : integer ): boolean;

var XR : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 0, XR );
  VerNr := Hi(XR.AX)*100 + ( Lo(XR.AX) shr 4 ) * 10 +
           ( Lo(XR.AX) and 15 );
  RevNr := Hi(XR.BX)*100 + ( Lo(XR.BX) shr 4 ) * 10 +
           ( Lo(XR.BX) and 15 );
  XMSQueryVer := ( XR.DX = 1 );
end;

{***********************************************************************
* XMSGetHMA : Retourner … l'appelant le droit d'accŠs … la HMA.        *
**--------------------------------------------------------------------**
* Entr‚e : LenB = Nombre d'octets … allouer                            *
* Info    : Les programmes r‚sidents devraient r‚server exclusivement  *
*           la m‚moire strictement requise. Par contre, donner $FFFF   *
*           aux applications.                                          *
* Sortie : TRUE si la HMA a pu ˆtre rendue disponible sinon FALSE;     *
***********************************************************************}

function XMSGetHMA( LenB : word ) : boolean;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XR.DX := LenB;                    { Stocke longueur dans registre DX }
  XmsCall( 1, Xr );                            { Appel fonction XMS #1 }
  XMSGetHMA := ( XMSErr = ERR_NOERR );
end;

{***********************************************************************
* XMSReleaseHMA : LibŠre l'HMA et permet ainsi sa transmission …       *
*                 d'autres programmes.                                 *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Appeler cette proc‚dure avant de quitter un programme    *
*             si la HMA a ‚t‚ allou‚e par un appel de XMSGetHMA pour   *
*             pouvoir la transmettre aux programmes appel‚s plus tard  *
*           - L'appel de cette proc‚dure entraŒne la perte des         *
*             donn‚es stock‚es dans la HAM.                            *
***********************************************************************}

procedure XMSReleaseHMA;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 2, Xr );                            { Appel fonction XMS #2 }
end;

{***********************************************************************
* XMSA20OnGlobal: LibŠre le canal d'adresses A20, permettant l'accŠs   *
*                 direct … la HMA..                                    *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - La lib‚ration du canal d'adresses A20 est relativement   *
*             lente sur de nombreux ordinateurs. Veillez … ne pas      *
*             abuser de l'usage de cette proc‚dure.                    *
***********************************************************************}

procedure XMSA20OnGlobal;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 3, Xr );                            { Appel fonction XMS #3 }
end;

{***********************************************************************
* XMSA20OffGlobal: Pendant de la proc‚dure XMSA20OnGlobal, celle-ci    *
*                  bloque … nouveau le canal d'adresses A20, inter-    *
*                  sant l'accŠs direct … la HMA.                       *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Appelez toujours cette proc‚dure avant de quitter un     *
*             programme si le canal d'adresses A20 a ‚t‚ lib‚r‚ par    *
*             un appel de XMSA20OnGlobal.                              *
***********************************************************************}

procedure XMSA20OffGlobal;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 4, Xr );                            { Appel fonction XMS #4 }
end;

{***********************************************************************
* XMSA20OnLocal: Voir XMSA20OnGlobal                                   *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Cette proc‚dure locale se distingue de sa variante       *
*             globale par la lib‚ration du canal: elle n'est possible  *
*             que si elle n'a pas ‚t‚ effectu‚e par un appel pr‚c‚dent *
***********************************************************************}

procedure XMSA20OnLocal;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 5, Xr );                            { Appel fonction XMS #5 }
end;

{***********************************************************************
* XMSA20OffLocal : Voir XMSA29OffGlobal                                *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Info    : - Cette proc‚dure locale se distingue de sa variante       *
*             globale par la lib‚ration du canal: elle n'est possible  *
*             que si elle n'a pas ‚t‚ effectu‚e par un appel pr‚c‚dent *
***********************************************************************}

procedure XMSA20OffLocal;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 6, Xr );                            { Appel fonction XMS #6 }
end;

{***********************************************************************
* XMSIsA20On : Retourne l'‚tat du canal d'adresse A20                  *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Sortie : TRUE si le canal d'adresses A20 est lib‚r‚ sinon  FALSE.    *
***********************************************************************}

function XMSIsA20On : boolean;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 7, Xr );                            { Appel fonction XMS #7 }
  XMSIsA20On := ( Xr.AX = 1 );               { AX = 1 ---> canal libre }
end;

{***********************************************************************
* XMSQueryFree : Renvoie la m‚moire ‚tendue disponible et la taille du *
*                plus gros bloc libre                                  *
**--------------------------------------------------------------------**
* Entr‚e : TotalLibre: Stocke la taille totale de l'EM libre.          *
*           MaxBl  : Stocke la taille du plus grand bloc libre.        *
* Info    : - Les deux valeurs sont en Ko                              *
*           - La taille de la HMA n'est pas comptabilis‚e mˆme si elle *
*             n'a ‚t‚ affect‚e … aucun programme.                      *
***********************************************************************}

procedure XMSQueryFree( var TotalLibre, MaxBl : integer );

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  XmsCall( 8, Xr );                            { Appel fonction XMS #8 }
  TotalLibre := Xr.AX;                  { La taille totale est dans AX }
  MaxBl   := Xr.DX;                     { La m‚moire libre est dans DX }
end;

{***********************************************************************
* XMSGetMem : Alloue un bloc de m‚moire ‚tendue (EMB)                  *
**--------------------------------------------------------------------**
* Entr‚e : LenKB : Taille en Ko du bloc interrog‚                      *
* Sortie : Identificateur pour accŠs au bloc ou 0, si aucun bloc n'a   *
*          pu ˆtre allou‚. Un code d'erreur se trouve alors dans la    *
*          variable globale XMSErr.                                    *
***********************************************************************}

function XMSGetMem( LenKb : integer ) : integer;

var Xr : XMSRegs;                 { Registre pour communiquer avec XMS }

begin
  Xr.DX := LenKB;           { Stockons la longueur dans le registre DX }
  XmsCall( 9, Xr );                            { Appel fonction XMS #9 }
  XMSGetMem := Xr.DX                       { Retourne l'identificateur }
end;

{***********************************************************************
* XMSFreeMem : LibŠre un bloc de m‚moire ‚tendue (EMB) pr‚c‚demment    *
*              allou‚                                                  *
**--------------------------------------------------------------------**
* Entr‚e : Handle : L'identificateur pour acc‚der au bloc. Il a ‚t‚    *
*                   obtenu en appelant XMSGetMem.                      *
* Info    : - Le contenu de l'EMB est d‚finitivement d‚truit par cet   *
*             appel, l'identificateur devient invalide.                *
*           - Avant de quitter un programme, lib‚rez … l'aide de cette *
*             proc‚dure toutes les zones pr‚c‚demment allou‚es pour    *
*             pouvoir les allouer aux programmes suivants.             *
***********************************************************************}

procedure XMSFreeMem( Handle : integer );

var Xr : XMSRegs;                 { Registre pour communiquer avec XMS }

begin
  Xr.DX := Handle;      { Copions l'identificateur dans le registre DX }
  XmsCall( 10, Xr );                          { Appel fonction XMS #10 }
end;

{***********************************************************************
* XMSCopy : : Copie des zones de m‚moire entre la m‚moire ‚tendue et la*
*           m‚moire conventionnelle ou … l'int‚rieur de ces deux       *
*           groupes de m‚moire.                                        *
**--------------------------------------------------------------------**
* Entr‚e : HandleOrig  : Identificateur du bloc de m‚moire … d‚placer  *
*          OffsetOrig  : Offset dans ce bloc, … partir duquel le       *
*                        d‚placement sera effectu‚.                    *
*          HandleDest :  Identificateur du bloc de m‚moire cible       *
*          OffsetDest :  Offset dans le bloc cible.                    *
*          LenW       :  Nombre de mots d‚plac‚s                       *
* Info    : - Pour utiliser la m‚moire normale dans cette op‚ration,   *
*           donnez la valeur 0 … l'identificateur ("Handle") et pour   *
*           l'offset, le segment et l'adresse de l'offset dans sa      *
*           forme habituelle (offset avant le segment).                *
***********************************************************************}

procedure XMSCopy( HandleOrig  : integer; OffsetOrig  : longint;
                   HandleDest : integer; OffsetDest : longint;
                   LenW       : longint  );

type EMMS = record                    { Structure Move m‚moire ‚tendue }
              LenB    : longint;             { Nbre d'octets … d‚caler }
              SHandle : integer;               { Identificateur source }
              SOffset : longint;                     { D‚calage source }
              DHandle : integer;                  { Handle destination }
              DOffset : longint;                { D‚calage destination }
            end;

var Xr : XMSRegs;                 { Registre de communication avec XMS }
    Mi : EMMS;                                         { Stocke l'EMMS }

begin
  with Mi do                           { Commencer par pr‚parer l'EMMS }
    begin
      LenB := 2 * LenW;
      SHandle := HandleOrig;
      SOffset := OffsetOrig;
      DHandle := HandleDest;
      DOffset := OffsetDest
    end;

  Xr.Si      := Ofs( Mi );             { Adresse de l'offset de l'EMMS }
  Xr.Segment := Seg(Mi);                { Adresse du segment de l'EMMS }
  XmsCall( 11, Xr );                          { Appel fonction XMS #11 }
end;

{***********************************************************************
* XMSLock : Interdit tout d‚calage d'un bloc de m‚moire ‚tendue par    *
*           l'XMM et retourne son adresse absolue.                     *
**--------------------------------------------------------------------**
* Entr‚e : Handle : Identificateur du bloc de m‚moire retourn‚ lors de *
*          l'appel pr‚c‚dent de XMSGetMem.                             *
* Sortie : Adresse lin‚aire du bloc de m‚moire.                        *
***********************************************************************}

function XMSLock( Handle : integer ) : longint;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  Xr.DX := Handle;                                   { Handle de l'EMB }
  XmsCall( 12, Xr );                          { Appel fonction XMS #12 }
  XMSLock := longint(Xr.DX) shl 16 + Xr.BX;  { Calcule adr.sur 32 bits }
end;

{***********************************************************************
* XMSUnlock : LibŠre … nouveau un bloc de m‚moire ‚tendu pour une      *
*             op‚ration de d‚calage.                                   *
**--------------------------------------------------------------------**
* Entr‚e : Handle : Identificateur de la zone de m‚moire retourn‚ lors *
           d'un appel pr‚c‚dent de XMSGetMem.                          *
***********************************************************************}

procedure XMSUnLock( Handle : integer );

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  Xr.DX := Handle;                                   { Handle de l'EMB }
  XmsCall( 13, Xr );                          { Appel fonction XMS #13 }
end;

{***********************************************************************
* XMSQueryInfo : Retourne diverses informations sur un bloc de         *
*                m‚moire ‚tendue pr‚alablement allou‚.                 *
**--------------------------------------------------------------------**
* Entr‚e :  Handle : Identificateur de la zone de m‚moire              *
*           Lock   : Variable de stockage du compteur de Lock          *
*           LenKB  : Variable de stockage de la longueur du bloc en Ko *
*           FreeH  : Variable de stockage du nombre d'identificateurs  *
*                    restant libres.                                   *
* Info    : Cette proc‚dure ne permet pas de connaŒtre l'adresse d'un  *
*           bloc. Utilisez la fonction XMSLock pour cette information. *
***********************************************************************}

procedure XMSQueryInfo( Handle    : integer; var Lock, LenKB : integer;
                        var FreeH : integer );

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  Xr.DX := Handle;                                   { Handle de l'EMB }
  XmsCall( 14, Xr );                          { Appel fonction XMS #14 }
  Lock  := Hi( Xr.BX );                            { Lit les registres }
  FreeH := Lo( Xr.BX );
  LenKB := Xr.DX;
end;

{***********************************************************************
* XMSRealloc : Agrandit ou r‚duit la taille d'un bloc de m‚moire       *
*              ‚tendue allou‚ par XMSGetMem                            *
**--------------------------------------------------------------------**
* Entr‚e :  Handle   : Identificateur de la zone de m‚moire            *
*           NewLenkB : Nouvelle taille du bloc, en Ko                  *
* Sortie :  TRUE si la taille du bloc a ‚t‚ modifi‚e sinon FALSE       *
* Info   :  Ce bloc ne doit pas ˆtre verrouill‚!                       *
***********************************************************************}

function XMSRealloc( Handle, NewLenkB : integer ) : boolean;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  Xr.DX := Handle;                                   { Handle de l'EMB }
  Xr.BX := NewLenkB;        { La nouvelle longueur dans le registre BX }
  XmsCall( 15, Xr );                          { Appel fonction XMS #15 }
  XMSRealloc := ( XMSErr = ERR_NOERR );
end;

{***********************************************************************
* XMSGetUMB : Alloue un bloc de Upper Memory (UMB)                     *
**--------------------------------------------------------------------**
* Entr‚e :  LenPara : Taille de la zone allou‚e en paragraphes de 16   *
*                     octets chacun.                                   *
*           Seg     : Variable de stockage de l'adresse du segment de  *
*                     l'UMB allou‚ (si tout va bien)                   *
*           MaxPara : Variable contenant la taille du plus gros bloc   *
*                     UMB en cas d'‚chec.                              *
* Sortie : TRUE si un UMB a ‚t‚ allou‚ sinon FALSE                     *
* Info    : Attention! Cette fonction n'est pas compatible avec tous   *
*           les pilotes XMS. Elle est extrˆmement d‚pendante du        *
*           mat‚riel.                                                  *
***********************************************************************}

function XMSGetUMB( LenPara          : integer;
                    var Seg, MaxPara : word ) : boolean;

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  Xr.DX := LenPara;                       { Longueur demand‚e selon DX }
  XmsCall( 16, Xr );                          { Appel fonction XMS #16 }
  Seg := Xr.BX;                        { Retourne l'adresse du segment }
  MaxPara := Xr.DX;                        { Longueur du plus gros UMB }
  XMSGetUMB := ( XMSErr = ERR_NOERR );
end;

{***********************************************************************
* XMSFreeUMB : LibŠre un UMB allou‚ par XMSGetUMB.                     *
**--------------------------------------------------------------------**
* Entr‚e  : Seg : Adresse du segment de l'UMB … lib‚rer                *
* Info    : Attention! Cette fonction n'est pas compatible avec tous   *
*           les pilotes XMS. Elle est extrˆmement d‚pendante du        *
*           mat‚riel.                                                  *
***********************************************************************}

procedure XMSFreeUMB( var Seg : word );

var Xr : XMSRegs;                 { Registre de communication avec XMS }

begin
  Xr.DX := Seg;                 { Adresse du segment de l'UMB selon DX }
  XmsCall( 17, Xr );                          { Appel fonction XMS #17 }
end;

{----------------------------------------------------------------------}
{-- Proc‚dures de test et de d‚monstration                           --}
{----------------------------------------------------------------------}

{***********************************************************************
* HMATest : Teste la disponibilit‚ de l'HMA et d‚montre son maniement. *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
***********************************************************************}

procedure HMATest;

type HMAR = array [1..65520] of BYTE;                 { Le tableau HMA }
     HMARPTR = ^HMAR;                    { Pointeur sur le tableau HMA }

var ch   : char;                             { pour interroger touches }
    A20  : boolean;              { Etat courant du canal d'adresse A20 }
    hmap : HMARPTR;                               { Pointeur sur l'HMA }
    i,                                         { Compteur d'it‚rations }
    err  : word;                   { Nombre d'erreurs d'accŠs … la HMA }

begin
  write( 'Test HMA : Veuillez taper une touche pour lancer ' +
         'le test...' );
  ch := ReadKey;
  writeln( #10 );

   {-- Allouer HMA et tester chaque adresse de la m‚moire -------------}

  if ( XMSGetHMA( $FFFF) ) then               { Contr“lons-nous l'HMA? }
    begin                                                        { Oui }
      A20 := XMSIsA20On;                      { Donner l'‚tat du canal }
      If ( A20 = FALSE ) then                      { Canal A20 libre ? }
        XMSA20OnGlobal;                   { Non, le lib‚rer maintenant }

      hmap := HMARPTR(Ptr( $FFFF, $0010 ));         { Pointeur sur HMA }

      err := 0;                       { Jusque l… encore aucune erreur }
      for i := 1 to 65520 do        { Tester chaque adresse s‚par‚ment }
        begin
          write( #13, 'Cellule m‚moire : ', i );
          hmap^[i] := i mod 256;               { Ecrire dans l'adresse }
          if ( hmap^[i] <> i mod 256 ) then             { et la relire }
            begin                                            { Erreur! }
              writeln( ' ERREUR!' );
              inc( err );
            end;
        end;

      XMSReleaseHMA;                                  { Lib‚rons l'HMA }
      If ( A20 = FALSE ) then   { Est-ce que le canal A20 ‚tait libre? }
        XMSA20OffGlobal;                            { Non, lib‚rons-le }

      writeln( #13 );
      if ( err = 0 ) then                { Analyse du r‚sultat du test }
        writeln( 'HMA ok, aucune cellule de la m‚moire d‚fectueuse.')
      else
        writeln( 'ATTENTION! ', err, ' cellules d‚fectueuses dans',
                 ' l''HMA ! ');
    end
  else
   writeln( 'ATTENTION! AccŠs impossible … l''HMA.' );
end;

{***********************************************************************
* EMBTest : Teste la m‚moire ‚tendue et montre l'appel de plusieurs    *
*           fonctions XMS                                              *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
***********************************************************************}

procedure EMBTest;

type BAR = array [1..1024] of BYTE;      { tableau "Byte array" d'1 Ko }
     BARPTR = ^BAR;             { Pointeur sur le tableau "Byte array" }

var ch      : char;                          { Pour interroger touches }
    Adr     : longint;                              { Adresse de l'EMB }
    barp    : BARPTR;                     { Pointeur sur tampon d'1 Ko }
    i, j,                                      { Compteur d'it‚rations }
    err,                           { Nombre d'erreurs en accŠs … l'HMA }
    Handle,                      { Identificateur pour l'accŠs … l'EMB }
    TotalLibre,                   { Taille de toute la m‚moire ‚tendue }
    MaxBl   : integer;                          { Plus gros bloc libre }

begin
  write( 'Test EMB : Veuillez taper une touche pour ' +
         'lancer le test...' );
  ch := ReadKey;
  writeln( #10 );

  XMSQueryFree( TotalLibre, MaxBl ); { Ret. taille tot. de m‚m. ‚tend. }
  writeln( 'Taille totale de la m‚moire ‚tendue (avec HMA) : ',
            TotalLibre, ' KB' );
  writeln( '                  Dont le plus gros bloc libre : ',
            MaxBl, ' KB' );

  TotalLibre := TotalLibre - 64;   { Calcul taille effective sans HMA. }
  if ( MaxBl >= TotalLibre ) then              { Valeur vraisemblable? }
    MaxBl := MaxBl - 64;                                         { Non }

  if ( MaxBl <> 0 ) then                    { Encore assez de m‚moire? }
    begin                                                        { Oui }
      Handle := XMSGetMem( MaxBl );
      writeln( MaxBl, ' Ko allou‚s.' );
      writeln( 'Identificateur = ', Handle );
      Adr := XMSLock( Handle );                  { Retourner l'adresse }
      XMSUnlock( Handle );                         { Supprimer blocage }
      writeln( 'Adresse de d‚part = ', Adr, ' (', Adr div 1024, ' Ko)');

      GetMem( barp, 1024 );                    { Tampon sur Turbo Heap }
      err := 0;                       { Jusque l… encore aucune erreur }

      {-- V‚rifier l'EMB Ko aprŠs Ko ----------------------------------}

      for  i := 0 to MaxBl-1 do
        begin
          write( #13, 'Test Ko: ', i+1 );
          FillChar( barp^, 1024, i mod 255 );
          XMSCopy( 0, longint(barp), Handle, longint(i)*1024, 512 );
          FillChar( barp^, 1024, 255 );
          XMSCopy( Handle, longint(i)*1024, 0, longint(barp), 512 );

          {-- Compare le tampon recopi‚ avec le r‚sultat attendu    ---}

          j := 1;
          while ( j <= 1024 ) do
            if ( barp^[j] <> i mod 255 ) then
              begin                                          { Erreur! }
                writeln( ' ERREUR!' );
                inc( err );
                j := 1025;
              end
           else               { Pas d'erreur, cellule m‚moire suivante }
            inc( j );
        end;

      writeln( #13 );
      if ( err = 0 ) then                { Analyse du r‚sultat du test }
        writeln( 'EMB ok, aucun des blocs d''1 Ko v‚rifi‚s n''‚tait ' +
                 'd‚fectueux.')
      else
        writeln( 'ATTENTION! ', err, ' blocs d''1 Ko d‚fectueux' +
                 ' dans l''EMB' );

      FreeMem( barp, 1024 );                       { Lib‚rer le tampon }
      XMSFreeMem( Handle );                            { Lib‚rer l'EMB }
   end;
end;

{***********************************************************************
*                 P R O G R A M M E   P R I N C I P A L                *
***********************************************************************}

var VerNr,
    RevNr  : integer;

begin
  ClrScr;
  writeln( 'XMSP - (c) 1990, 92 by MICHAEL TISCHER' );
  writeln;
  if XMSInit then
   begin
     if XMSQueryVer( VerNr, RevNr ) then
      writeln( 'AccŠs possible … l''HMA.' )
     else
      writeln( 'Aucun accŠs … l''HMA.' );
     writeln( 'Nø de version XMS : ', VerNr div 100,
               '.', VerNr mod 100 );
     writeln( 'Nø de r‚vision   : ', RevNr div 100,
              '.', RevNr mod 100 );
     writeln;
     HMATest;                                               { Test HMA }
     writeln;
     EMBTest;                                   { Test m‚moire ‚tendue }
   end
  else
    writeln( 'Aucun pilote XMS install‚!');
end.

