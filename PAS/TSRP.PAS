{**********************************************************************}
{*                              T S R P                               *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Cr‚e un programme r‚sident … l'aide d'un       *}
{*                     module en assembleur                           *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   : 18.08.1988                                     *}
{*    DerniŠre MAJ   : 18.03.1992                                     *}
{**********************************************************************}

program TSRP;

uses DOS, CRT;                         { IntŠgre les unit‚s DOS et CRT }

{$M 2048, 0, 5120}          { 2Ko pour la pile et 5Ko maxi pour le tas }
{$L tsrpa}                           { IntŠgre le module en assembleur }

{-- D‚claration des fonctions externes du module en assembleur --------}

procedure TsrInit( PrzPtr   : word; { Offset de la proc‚dure r‚sidente }
                   ResPara  : word   { Nombre de paragraphes r‚sidents }
                 ) ; external ;              { ChaŒne d'identification }
function  TsrIsInst( i2F_fctnr : byte ) : boolean ; external ;
procedure TsrUnInst; external;     { D‚sinstalle le programme r‚sident }
procedure TsrSetPtr( Offset : word ); external;
function  TsrCanUnInst : boolean; external;

{$F+}                     { Ci-dessous les proc‚dures et fonctions FAR }

procedure TsrCall ; external;
procedure TsrSetHotKey( KeyMask  : word;         { shortcut (cf CONST) }
                        ScCode   : byte                    { Scan code }
                      ) ; external;

{$F-}

{-- Constantes --------------------------------------------------------}

{-- Scan codes de diif‚rentes touches ---------------------------------}

const SC_ESC             = $01;      SC_Y               = $2C;
      SC_1               = $02;      SC_X               = $2D;
      SC_2               = $03;      SC_C               = $2E;
      SC_3               = $04;      SC_V               = $2F;
      SC_4               = $05;      SC_B               = $30;
      SC_5               = $06;      SC_N               = $31;
      SC_6               = $07;      SC_M               = $32;
      SC_7               = $08;      SC_VIRGULE         = $33;
      SC_8               = $09;      SC_PPOINT          = $34;
      SC_9               = $0A;      SC_TIRET           = $35;
      SC_0               = $0B;      SC_SHIFT_GAUCHE    = $36;
      SC_SCHARFES_S      = $0C;      SC_PRINT_SCREEN    = $37;
      SC_APOSTROPH       = $0D;      SC_ALT             = $38;
      SC_BACKSPACE       = $0E;      SC_SPACE           = $39;
      SC_TAB             = $0F;      SC_CAPS            = $3A;
      SC_Q               = $10;      SC_F1              = $3B;
      SC_W               = $11;      SC_F2              = $3C;
      SC_E               = $12;      SC_F3              = $3D;
      SC_R               = $13;      SC_F4              = $3E;
      SC_T               = $14;      SC_F5              = $3F;
      SC_Z               = $15;      SC_F6              = $40;
      SC_U               = $16;      SC_F7              = $41;
      SC_I               = $17;      SC_F8              = $42;
      SC_O               = $18;      SC_F9              = $43;
      SC_P               = $19;      SC_F10             = $44;
      SC_UE              = $1A;      SC_NUM_LOCK        = $45;
      SC_PLUS            = $1B;      SC_SCROLL_LOCK     = $46;
      SC_RETURN          = $1C;      SC_CURSOR_HOME     = $47;
      SC_CONTROL         = $1D;      SC_CURSOR_UP       = $48;
      SC_A               = $1E;      SC_CURSOR_PG_UP    = $49;
      SC_S               = $1F;      SC_NUM_MOINS       = $4A;
      SC_D               = $20;      SC_CURSOR_LEFT     = $4B;
      SC_F               = $21;      SC_NUM_5           = $4C;
      SC_G               = $22;      SC_CURSOR_RIGHT    = $4D;
      SC_H               = $23;      SC_NUM_PLUS        = $4E;
      SC_J               = $24;      SC_CURSOR_END      = $4F;
      SC_K               = $25;      SC_CURSOR_DOWN     = $50;
      SC_L               = $26;      SC_CURSOR_PG_DOWN  = $51;
      SC_OE              = $27;      SC_INSERT          = $52;
      SC_AE              = $28;      SC_DELETE          = $53;
      SC_PLUSGRAND       = $29;      SC_SYS_REQUEST     = $54;
      SC_SHIFT_DROIT     = $2A;      SC_F11             = $57;
      SC_FIS             = $2B;      SC_F12             = $58;
      SC_NOKEY           = $80;          { Pas de touche additionnelle }

      {-- Masques binaires pour les touches de commande  --------------}

      RSHIFT =     1;
      LSHIFT =     2;                               { Majuscule gauche }
      CTRL   =     4;                                    { Touche CTRL }
      ALT    =     8;                                     { Touche ALT }
      SYSREQ =  1024;             { Touche SYS-REQ (Clavier AT uniqt ) }
      BREAK  =  4096;                                   { Touche BREAK }
      NUM    =  8192;                                     { Touche NUM }
      CAPS   = 16384;                                    { Touche CAPS }
      INSERT = 32768;                                  { Touche INSERT }

      I2F_CODE   = $C4;                 { Num‚ro de la fonction INT 2F }
      I2F_FKT_0  = $AA;                 { Code pour INT 2F, fonction 0 }
      I2F_FKT_1  = $BB;                 { Code pour INT 2F, fonction 1 }

{-- D‚clarations de types ---------------------------------------------}

type VBuf   = array[1..25, 1..80] of word;           { D‚crit un ‚cran }
     VPtr   = ^VBuf;                    { Pointe sur un buffer d'‚cran }

{
    D‚clarations des types de fonction et de proc‚dures grƒce auxquels
    il sera possible d'appeler des fonctions et des proc‚dures de
    l'exemplaire d‚j… install‚ du programme r‚sident
}

     SAProcT  = procedure;                  { Proc‚dure sans arguments }
     SHKProcT = procedure( KeyMask : word;              { TsrSetHotkey }
                           ScCode  : byte );
     PPtrT  = record       { Union pour compiler les ptrs de proc‚dure }
        case integer of
          1 : ( SAProc  : SAProcT  );
          2 : ( SHKProc : SHKProcT );
              end;

const Call : PPtrT = ( SAProc : TsrCall );

{-- Variables globales ------------------------------------------------}

var MBuf   : VBuf absolute $B000:0000;    { M‚moire d'‚cran monochrome }
    CBuf   : Vbuf absolute $B800:0000;       { M‚moire d'‚cran couleur }
    VioPtr : VPtr;                   { Pointeur sur la m‚moire d'‚cran }
    ATimes : integer;          { Nombre d'activations du prog r‚sident }

{**********************************************************************}
{* DispInit: Cr‚e un pointeur sur la m‚moire d'‚cran                  *}
{* Entr‚e  : n‚ant                                                    *}
{* Sortie  : n‚ant                                                    *}
{**********************************************************************}

procedure DispInit;

var Regs: Registers;                 { Stocke le contenu des registres }

begin
  Regs.ah := $0f;         { Fonction Nø  15 = d‚terminer le mode vid‚o }
  Intr($10, Regs);            { D‚clenche l'interruption vid‚o du BIOS }
  if Regs.al=7 then                         { Carte ‚cran monochrome ? }
    VioPtr := @MBuf       { Oui, fixe ptr sur m‚moire ‚cran monochrome }
  else                         { Il s'agit d'une carte EGA, VGA ou CGA }
    VioPtr := @CBuf;              { Fixe ptr sur m‚moire ‚cran couleur }
end;

{**********************************************************************}
{* SaveScreen: Sauvegarde le contenu de l'‚cran dans un buffer        *}
{* Entr‚e : SPTR : Pointeur sur le buffer qui va recevoir les donn‚es *}
{*                  sauvegard‚es                                      *}
{* Sortie : n‚ant                                                     *}
{**********************************************************************}

procedure SaveScreen( SPtr : VPtr );

var ligne,                                            { Ligne courante }
    colonne : byte;                                 { Colonne courante }

begin
  for ligne:=1 to 25 do            { Parcourt les 25 lignes de l'‚cran }
    for colonne:=1 to 80 do               {  ainsi que les 80 colonnes }
      SPtr^[ligne, colonne] := VioPtr^[ligne, colonne];
                              { TransfŠre un caractŠre et son attribut }
end;

{**********************************************************************}
{* RestoreScreen: Copie le contenu d'un buffer dans la m‚moire d'‚cran*}
{* Entr‚e : BPTR : Pointeur sur le buffer dont le contenu doit        *}
{*                 ˆtre copi‚ dans la m‚moire d'‚cran                 *}
{* Sortie : n‚ant                                                     *}
{**********************************************************************}

procedure RestoreScreen( BPtr : VPtr );

var ligne,                                            { Ligne courante }
    colonne : byte;                                 { Colonne courante }

begin
  for ligne:=1 to 25 do            { Parcourt les 25 lignes de l'‚cran }
    for colonne:=1 to 80 do               {  ainsi que les 80 colonnes }
      VioPtr^[ligne, colonne] := BPtr^[ligne, colonne];
                              { TransfŠre un carcatŠre et son attribut }
end;

{**********************************************************************}
{* ResPara: Calcule le nombre de paragraphes … allouer au programme   *}
{*          r‚sident                                                  *}
{* Entr‚es : n‚ant                                                    *}
{* Sortie : Nombre de paragraphes … r‚server                          *}
{**********************************************************************}

function ResPara : word;

begin

{$ifdef VER50}                                           { Pour TP 5.0 }
    ResPara := Seg(FreePtr^)+$1000-PrefixSeg;  { Nombre de paragraphes }
{$endif}

{$ifdef VER55}                                           { pour TP 5.5 }
    ResPara := Seg(FreePtr^)+$1000-PrefixSeg;  { Nombre de paragraphes }
{$endif}

{$ifdef VER60}                                           { pour TP 6.0 }
    ResPara := Seg(HeapEnd^)-PrefixSeg;
{$endif}

end;

{**********************************************************************}
{* ParamGetHotKey: Recherche dans la ligne de commande le paramŠtre /T*}
{*                 puis l'exploite                                    *}
{* Entr‚es : KEYMASK = Variable pour m‚moriser le masque de la touche *}
{*           SCCODE  = Variable pour m‚moriser le scan code           *}
{* Sortie  : TRUE, si la touche d'activation est identifi‚e, sinon    *}
{*           FALSE                                                    *}
{* Info    : - Les paramŠtres qui ne sont pas introduits par /T ne    *}
{*             sont pas trait‚s pour ˆtre laiss‚s … la disposition    *}
{*             d'autres fonctions                                     *}
{*           - Si aucun paramŠtre /T n'est d‚tect‚, les variables     *}
{*             contiennent respectivement les valeurs 0 et SC_NOKEY.  *}
{**********************************************************************}

function ParamGetHotKey( var KeyMask : word;
             var ScCode  : byte ) : boolean;

type TComman = record
                 Nom : string[6];
                 Valeur : word;
               end;

const ToucheC : array[ 1..9 ] of TComman =
         ( ( Nom: 'LSHIFT'; Valeur : LSHIFT ),
           ( Nom: 'RSHIFT'; Valeur : RSHIFT ),
           ( Nom: 'CTRL';   Valeur : CTRL   ),
           ( Nom: 'ALT';    Valeur : ALT    ),
           ( Nom: 'SYSREQ'; Valeur : SYSREQ ),
           ( Nom: 'BREAK';  Valeur : BREAK  ),
           ( Nom: 'NUM';    Valeur : NUM    ),
           ( Nom: 'CAPS';   Valeur : CAPS   ),
           ( Nom: 'INSERT'; Valeur : INSERT )
          );

var i, j,                                        { Compteurs de boucle }
    code,                                { Pour convertir le scan code }
    dummy : integer;                      { M‚morise l'erreur pour VAL }
    arg   : string;                               { Stocke un argument }

begin
  KeyMask := 0;
  ScCode  := SC_NOKEY;

  for i := 1 to ParamCount do          { Parcourt la ligne de commande }
    begin
      arg := ParamStr(i);                           { lit un argumeent }
      for j := 1 to length(arg) do        { Le convertit en majuscules }
        arg[j] := upcase(arg[j]);
      if( arg[1] = '/' ) and ( arg[2] = 'T' ) then
        begin                                   { C'est un argument /T }
          delete( arg, 1, 2 );             { Retire le /T de la chaŒne }
          val( arg, code, dummy );     { Convertit le reste en binaire }
          if( dummy = 0 ) then                  { Conversion r‚ussie ? }
            begin                                                { Oui }
              if( code > 0 ) and ( code < 128 ) then  { Code valable ? }
                ScCode := Code                      { Oui, le m‚morise }
              else
                begin                               { Code non valable }
                  ParamGetHotKey := false;
                  exit;     { Termine la fonction avec la valeur FALSE }
                end;
            end
          else                    { Pas de nombre = touche de commande }
            begin
              j := 1; { recherche dans tableau des touches de commande }
              while( j < 10 ) and ( arg <> ToucheC[j].Nom ) do
                j := j + 1;
              if( j < 10 ) then                         { Nom trouv‚ ? }
                KeyMask := KeyMask or ToucheC[j].Valeur
                                          {Oui, incorpore l'indicateur }
              else
                begin           { Non, ni nombre ni touche de commande }
                  ParamGetHotKey := false;
                  exit;     { Termine la fonction avec la valeur FALSE }
                end;
            end;
        end;
    end;
  ParamGetHotKey := true;        { Si la fonction parvient jusqu'ici , }
end;                              { c'est que les paramŠtres sont o.k. }

{**********************************************************************}
{* EndPrc: Appel‚e par le module assembleur lors de la d‚sinstallation*}
{*         du programme r‚sident                                      *}
{* Entr‚e : n‚ant                                                     *}
{* Sortie : n‚ant                                                     *}
{* Info : Cette proc‚dure doit se trouver dans le programme principal *}
{*        et doit ˆtre transform‚e par une directive $F+              *}
{*        en proc‚dure FAR                                            *}
{**********************************************************************}

{$F+}

procedure EndPrc;

begin
  TextBackground( Black );                               { Fond sombre }
  TextColor( LightGray );                          { CaractŠres clairs }
  writeln('Le programme r‚sident a ‚t‚ activ‚ ', ATimes, ' fois .');
end;

{$F-}

{**********************************************************************}
{* Tsr: Proc‚dure appel‚e par le module en assembleur lorsqu'on       *}
{*      actionne la touche d'activation                               *}
{* Entr‚e : n‚ant                                                     *}
{* Sortie : n‚ant                                                     *}
{* Info : Cette proc‚dure doit se trouver dans le programme principal *}
{*        et ne doit pas ˆtre transform‚e par une directive $F+       *}
{*        en proc‚dure FAR                                            *}
{**********************************************************************}

{$F-}                                           { pas de proc‚dure FAR }

procedure Tsr;

var BufPtr : VPtr;         { M‚morise un pointeur sur le buffer allou‚ }
    Colonne,                                { Colonne d'‚cran courante }
    Ligne  : byte;                                    { Ligne courante }
    Touche : char;

begin
  while KeyPressed do                      { Vide le buffer du clavier }
    Touche := ReadKey;
  inc( ATimes );                     { Incr‚mente le compteur d'appels }
  DispInit;                      { Lit l'adresse de la m‚moire d'‚cran }
  GetMem(BufPtr, SizeOf(VBuf) );                    { Alloue un buffer }
  SaveScreen( BufPtr );             { Sauvegarde le contenu de l'‚cran }
  Ligne := WhereY;                                    { Ligne actuelle }
  Colonne := WhereX;                                { Colonne actuelle }
  TextBackground( LightGray );                            { Fond clair }
  TextColor( Black );                              { CaractŠres fonc‚s }
  ClrScr;                                        { Efface tout l'‚cran }
  GotoXY(22, 12);
  write('TSRP  -  (c) 1988, 92 by MICHAEL TISCHER');
  GotoXY(30, 14);
  write('Appuyez sur une touche SVP ...');
  Touche := ReadKey;                     { Attend une frappe de touche }
  RestoreScreen( BufPtr );                   { Restaure l'ancien ‚cran }
  FreeMem( BufPtr, SizeOf(VBuf) );            {LibŠre le buffer allou‚ }
  GotoXY( Colonne, Ligne );    { Remet le curseur en position initiale }
end;

{**********************************************************************}
{**                        PROGRAMME PRINCIPAL                        *}
{**********************************************************************}

var KeyMask : word;
    ScCode : byte;

begin
  writeln('TSRP  -  (c) 1988, 92 by MICHAEL TISCHER');
  if not ParamGetHotKey( KeyMask, ScCode ) then
    begin         { Erreur dans les paramŠtres de la ligne de commande }
      writeln( 'ParamŠtre erron‚ dans la ligne de commande !');
      exit;
    end;

      {-- Les paramŠtres de la ligne de commande sont corrects --------}

  if( TsrIsInst( I2F_CODE ) = FALSE ) then  {Programme d‚j… install‚  ?}
    begin                                                        { Non }
      ATimes := 0;            { Le programme n'a pas encore ‚t‚ activ‚ }
      writeln( 'Le programme r‚sident a ‚t‚ install‚' );
      if( KeyMask = 0 ) and ( ScCode = SC_NOKEY ) then   {Pas de para ?}
        begin                           { Non valeur implicite = ALT H }
          TsrSetHotkey( ALT, SC_H );
          writeln( 'Activation: <ALT> + H' );
        end
      else                  { Installe touche d'activation utilisateur }
        TsrSetHotkey( KeyMask, ScCode );
      TsrInit( Ofs(Tsr), ResPara );            { Installe le programme }
    end
  else                                        { Programm d‚j… install‚ }
    begin
      if( KeyMask = 0 ) and ( ScCode = SC_NOKEY ) then   {Pas de para.?}
        begin                          { Non tente une d‚sinstallation }
          if TsrCanUnInst then
            begin
              TsrSetPtr(ofs(EndPrc));    { Appelle la proc‚dure EndPrc }
              Call.SAProc;           { dans l'exemplaire d‚j… install‚ }
              TsrUnInst;
              writeln( 'Le programme a pu ˆtre d‚sinstall‚.');
            end
          else
            writeln( 'Le programme n''a pas pu ˆtre d‚sinstall‚ .');
        end
      else                     { Fixe une nouvelle touche d'activation }
        begin
          writeln( 'Nouvelle touche d''activation install‚e ' );
            TsrSetPtr(ofs(TsrSetHotKey));
            Call.SHKProc( KeyMask, ScCode );
        end
    end;
end.
