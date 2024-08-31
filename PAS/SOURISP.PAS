{**********************************************************************}
{*                         S O U R I S . P A S                        *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Fournit diverses fonctions pour le travail     *}
{*                     avec la souris                                 *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   : 21/04/1989                                     *}
{*    DerniŠre modif.: 23/04/1989                                     *}
{*--------------------------------------------------------------------*}
{*    Le module assembleur sourisp.obj doit se trouver dans le        *}
{*                     r‚pertoire courant sinon le chemin complet     *}
{*                     doit ˆtre sp‚cifier lors de son int‚gration.   *}
{**********************************************************************}

uses Dos;                                         { Int‚grer unit‚ DOS }

{$L sourispa} { Int‚grer le module assembleur }

{== D‚claration des fonctions externes ================================}

{$F+}                                         { C'est une fonction FAR }
procedure AssHand ; external;        { Le gestionnaire d'‚v‚nements en }
{$F-}                   { assembleur ne plus obliger des fonctions FAR }

{== Constantes ========================================================}

const

{-- Codes d'‚v‚nement -------------------------------------------------}

      EV_MOU_MOVE     =   1;                         { Souris d‚plac‚e }
      EV_LEFT_PRESS   =   2;       { Bouton gauche de la souris appuy‚ }
      EV_LEFT_REL     =   4;      { Bouton gauche de la souris relƒch‚ }
      EV_RIGHT_PRESS  =   8;        { Bouton droit de la souris appuy‚ }
      EV_RIGHT_REL    =  16;       { Bouton droit de la souris relƒch‚ }
      EV_MOU_ALL      =  31;              { Tous les ‚v‚nements souris }

      LBITS           =   6;            { EV_LEFT_PRESS or EV_LEFT_REL }
      RBITS           =  24;          { EV_RIGHT_PRESS or EV_RIGHT_REL }

      AUCUNE_ZONE    = 255;    { Curseur de la souris pas dans zone xy }

      PtrSameChar     = $00ff;                        { Mˆme caractŠre }
      PtrSameCol      = $00ff;                          { Mˆme couleur }
      PtrInvCol       = $7777;                      { Couleur invers‚e }
      PtrSameColz     = $807f;              { Mˆme couleur clignotante }
      PtrInvColz      = $F777;          { Couleur invers‚e clignotante }

      ET             = 0;{ Combinaisons d'‚v‚nements pour MouEventWait }
      OU            = 1;

      ZV              = #13#10;                        { Saut de ligne }

{== D‚clarations de type ==============================================}

type  FCTPTR   = longint;                 { Adresse d'une fonction FAR }
      PTRVIEW  = longint;        { Masque pour le curseur de la souris }
      ZONE  = record                    { D‚crit une zone de la souris }
                   x1,          { Coordonn‚es du coin sup‚rieur gauche }
                   y1,                 { et du coin inf‚rieur droit de }
                   x2,                             { la zone sp‚cifi‚e }
                   y2      : byte;
                   PtrMask : PTRVIEW;  { Masque pour le curseur souris }
                 end;
      TABLEAUZONES = array [0..100] of ZONE;
      PTRZONE   = ^TABLEAUZONES;
      PTRREC   = record                           { Sert … acc‚der aux }
                   Ofs : word;                { ‚l‚ments d'un pointeur }
                   Seg : word;                            { quelconque }
                 end;
      PTRVREC  = record                           { Sert … acc‚der aux }
                   ScreenMask : word;          { ‚l‚ments d'un PTRVIEW }
                   CursorMask : word;
                 end;
      BUFZONE   = array [0..10000] of byte;           { Buffer de zone }
      PTRBZ    = ^BUFZONE;            { Pointeur sur un buffer de zone }

{== Variables globales ================================================}

var  NmbZones,                                       { Nombre de zones }
     TLine,                                { Nombre de lignes de texte }
     TCol     : byte;                    { Nombre de colonnes de texte }
     MouAvail : boolean;              { Est TRUE, si souris disponible }
     OldPtr,              { Ancienne apparence du curseur de la souris }
     StdPtr   : PTRVIEW;{ Masque pour le curseur de la souris standard }
     BufPtr   : PTRBZ;  { Pointeur sur buffer pour identification zone }
     PtrZonAct: PTRZONE;         { Pointeur sur vecteur de zone actuel }
     BLen     : integer;        { Longueur du buffer de zone en octets }
     ExitOld  : pointer;      { Pointeur sur l'ancienne proc‚dure Exit }

{ Variables d‚finies lors de chaque appel du gestionnaire de la souris }

     ZonSou,                                 { Zone de souris actuelle }
     MouCol,                   { Colonne de la souris (‚cran de texte) }
     MouRow   : byte;            { Ligne de la souris (‚cran de texte) }
     MouEvent : integer;                         { Masque d'‚v‚nements }

{-- Variables qui ne sont d‚finies par le gestionnaire de la souris ---}
{-- que lorsqu'intervient un ‚v‚nement attendu                      ---}

     ZonEv,                      { Zone dans laquelle figure la souris }
     EvCol,                                     { Colonne de la souris }
     EvRow : byte;                                { Ligne de la souris }

{**********************************************************************}
{*  MouPtrMask: Compose les masques curseur et ‚cran … partir d'un    *}
{*              masque de bits pour le caractŠre et pour la couleur   *}
{**------------------------------------------------------------------**}
{*  Entr‚e : Caractere = masque bits pour les masques curseur et      *}
{*                       ‚cran concernant le caractŠre                *}
{*           Couleur   = masque bits pour les masques curseur et      *}
{*                       ‚cran concernant la couleur du caractŠre     *}
{*  Sortie : les masques curseur et ‚cran sous forme d'une valeur du  *}
{*           type PtrView                                             *}
{*  Infos :  pour Caractere et Couleur peuvent ˆtre transmises les    *}
{*           constantes PtrSameChar, PtrSameCol, PtrSameColz,         *}
{*           PtrInvCol et PtrInvColz ainsi que les r‚sultats des      *}
{*           fonctions PtrDifChar et PtrDifCol                        *}
{**********************************************************************}

function MouPtrMask( Caractere, Couleur  : word ) : PTRVIEW;

var Mask : PTRVIEW;             { Les masques curseur et ‚cran … cr‚er }

begin
  PTRVREC( Mask ).ScreenMask := ( ( Couleur and $ff ) shl 8 ) +
                                ( Caractere and $ff );
  PTRVREC( Mask ).CursorMask := ( Couleur and $ff00 ) + ( Caractere shr 8 );
  MouPtrMask := Mask;           { Renvoyer masque au programme d'appel }
end;

{**********************************************************************}
{*  PtrDifChar: cr‚e la partie caractŠre des masques curseur et ‚cran *}
{*              concernant le caractŠre                               *}
{**------------------------------------------------------------------**}
{*  Entr‚e : Code ASCII du caractŠre devant ˆtre le curseur souris    *}
{*  Sortie : Masques curseur et ‚cran pour ce caractŠre               *}
{*  Infos :  Le r‚sultat de la fonction devra ˆtre retrait‚ … l'aide  *}
{*           de la fonction MouPtrMask                                *}
{**********************************************************************}

function PtrDifChar( Caractere : byte ) : word;

begin
  PtrDifChar := Caractere shl 8;
end;

{**********************************************************************}
{*  PtrDifCol: Cr‚e la partie caractŠre des masques curseur et ‚cran  *}
{*             concernant la couleur du curseur de la souris          *}
{**------------------------------------------------------------------**}
{*  Entr‚e : Couleur du caractŠre devant ˆtre le curseur de la souris *}
{*  Sortie : Masques curseur et ‚cran pour cette couleur              *}
{*  Infos  : Le r‚sultat de la fonction devra ˆtre retrait‚ … l'aide  *}
{*           de la fonction MouPtrMask                                *}
{**********************************************************************}

function PtrDifCol( Couleur : byte ) : word;

begin
  PtrDifCol := Couleur shl 8;
end;

{**********************************************************************}
{*  MouDefinePtr: transmet au driver de la souris les masques curseur *}
{*                et ‚cran qui d‚finissent d‚sormais l'apparence du   *}
{*                curseur de la souris                                *}
{**------------------------------------------------------------------**}
{*  Entr‚e : Masque = les masques curseur et ‚cran sous forme d'un    *}
{*                    paramŠtre du type PTRVIEW                       *}
{*  Infos :  - le paramŠtre Masque doit avoir ‚t‚ cr‚‚ … l'aide de la *}
{*             fonction MouPtrMask                                    *}
{*           - les 16 bits de plus fort poids de Masque repr‚sentent  *}
{*             le masque ‚cran, les 16 bits faibles le masque curseur *}
{**********************************************************************}

procedure MouDefinePtr( Mask : PTRVIEW );

var Regs : Registers;    { Registres du processeur pour l'appel d'int. }

begin
  if OldPtr <> Mask then { Modification par rapport au dernier appel ? }
    begin                                                        { Oui }
      Regs.AX := $000a;          { Nø fct pour "Set text pointer type" }
      Regs.BX := 0;                           { Fixer curseur logiciel }
      Regs.CX := PTRVREC( Mask ).ScreenMask; { Mot faible : masque AND }
      Regs.DX := PTRVREC( Mask ).CursorMask;   { Mot fort : masque XOR }
      Intr( $33, Regs);               { Appeler le driver de la souris }
      OldPtr := Mask;                  { Ranger le nouveau masque bits }
    end;
end;

{**********************************************************************}
{*  MouEventHandler: Est appel‚ par le driver de la souris … travers  *}
{*                   la routine assembleur AssHand dŠs qu'intervient  *}
{*                   un ‚v‚nement concernant la souris                *}
{**------------------------------------------------------------------**}
{*  Entr‚e : EvFlags  = le masque Event                               *}
{*           ButState = ‚tat actuel des boutons de la souris          *}
{*           X, Y     = position actuelle du curseur de la souris     *}
{*                      concernant l'‚cran de texte                   *}
{**********************************************************************}

procedure MouEventHandler( EvFlags, ButState, x, y : integer );

var NouZon : byte;                        { Num‚ro de la nouvelle zone }

begin

  MouEvent := MouEvent and not(1);                  { Masquer le bit 0 }
  MouEvent := MouEvent or ( EvFlags and 1 );         { Copier le bit 0 }

  if ( EvFlags and LBITS ) <> 0 then {Bouton gauche relƒch‚ ou appuy‚ ?}
    begin                                                        { Oui }
      MouEvent := MouEvent and not( LBITS );       { Masque ‚tat actuel}
      MouEvent := MouEvent or ( EvFlags and LBITS );  { Incruster ‚tat }
    end;

  if ( EvFlags and RBITS ) <> 0 then { Bouton droit relƒch‚ ou appuy‚ ?}
    begin                                                        { Oui }
      MouEvent := MouEvent and not( RBITS );       { Masque ‚tat actuel}
      MouEvent := MouEvent or ( EvFlags and RBITS );  { Incruster ‚tat }
    end;

  MouCol := x;                { Convertir colonne en colonnes de texte }
  MouRow := y;                    { Convertir ligne en lignes de texte }

  {-- D‚terminer zone dans laquelle figure la souris et examiner   ----}
  {-- si la zone a ‚t‚ modifi‚e depuis le dernier appel du         ----}
  {-- gestionnaire. Dans ce cas, l'apparence du curseur de la      ----}
  {-- souris doit ˆtre red‚finie.                                  ----}

  NouZon := BufPtr^[ MouRow * TCol + MouCol ];          { Retirer zone }
  if NouZon <> ZonSou then                           { Nouvelle zone ? }
    begin                                                        { Oui }
      if NouZon = AUCUNE_ZONE then            { En dehors d'une zone ? }
        MouDefinePtr( StdPtr )    { Oui, curseur de la souris standard }
      else                                          { Non, zone connue }
        MouDefinePtr( PtrZonAct^[ NouZon ].PtrMask );
    end;
  ZonSou := NouZon;      { Ranger num‚ro de zone dans variable globale }
end;

{**********************************************************************}
{*  MouIBufFill: stocke le code d'une zone de la souris … l'int‚rieur *}
{*               de la m‚moire de zone interne du module              *}
{**------------------------------------------------------------------**}
{*  Entr‚e : x1, y1 = coin sup‚rieur gauche de la zone de la souris   *}
{*           x2, y2 = coin inf‚rieur droit de la zone de la souris    *}
{*           Code   = le code de zone                                 *}
{**********************************************************************}

procedure MouIBufFill( x1, y1, x2, y2, Code : byte );

var Index   : integer;                       { D‚signe le champ trait‚ }
    Colonne,                                      { Compteur de boucle }
    Ligne   : byte;

begin
  for Ligne:=y1 to y2 do            { Parcourir les diff‚rentes lignes }
    begin
      Index := Ligne  * TCol + x1;         { Premier index de la ligne }
      for Colonne:=x1 to x2 do    { Parcourir les colonnes de la ligne }
        begin
          BufPtr^[ Index ] := Code;                     { Stocker code }
          inc( Index );                { Fixer index sur champ suivant }
        end;
    end;
end;

{**********************************************************************}
{*  MouDefZone : permet d'enregistrer diff‚rentes zones de l'‚cran,   *}
{*               qui seront identifi‚es comme zones de souris         *}
{*               distinctes et pourront ˆtre dot‚es d'un curseur de   *}
{*               la souris particulier                                *}
{**------------------------------------------------------------------**}
{*  Entr‚e : Nombre = Nombre de zones de l'‚cran                      *}
{*           ZPtr   = Pointeur sur le tableau dans lequel les diff‚-  *}
{*                    rentes zones sont chacune d‚crites par une      *}
{*                    structure du type ZONE                          *}
{*  Infos :  - le code AUCUNE_ZONE est attribu‚ aux zones de l'‚cran  *}
{*             rest‚es libres                                         *}
{*           - lorsque le curseur de la souris p‚nŠtre dans l'une des *}
{*             zones souris inscrites dans le tableau, le             *}
{*             gestionnaire d'‚v‚nements commute imm‚diatement sur    *}
{*             la forme du curseur de la souris dans cette zone       *}
{**********************************************************************}

procedure ZoneMouDef( Nombre : byte; PtrZ : PTRZONE );

var ActZon,                               { Num‚ro de la zone actuelle }
    Zone : byte;                                  { Compteur de boucle }

begin
  PtrZonAct := PtrZ;                     { Ranger pointeur sur vecteur }
  NmbZones := Nombre;                             { et nombre de zones }
  FillChar( BufPtr^, BLen, AUCUNE_ZONE );{Tous les ‚l‚ments=AUCUNE_ZONE}
  for Zone:=0 to nombre-1 do         { Parcourir les diff‚rentes zones }
   with PtrZ^[ Zone ] do
     MouIBufFill( x1, y1, x2, y2, Zone );

  {-- Red‚finir le curseur de la souris -------------------------------}
  ActZon := BufPtr^[ MouRow * TCol + MouCol ];          { Retirer zone }
  if ActZon = AUCUNE_ZONE then                { En dehors d'une zone ? }
    MouDefinePtr( StdPtr )        { Oui, curseur de la souris standard }
  else                                              { Non, zone connue }
    MouDefinePtr( PtrZ^[ ActZon ].PtrMask );
end;

{**********************************************************************}
{*  MouEventWait: attend l'intervention d'un ‚v‚nement d‚termin‚      *}
{*                concernant la souris                                *}
{**------------------------------------------------------------------**}
{*  Entr‚e : TYP        = type de combinaison entre les diff‚rents    *}
{*                        ‚v‚nements                                  *}
{*           WAIT_EVENT = masque bits sp‚cifiant les ‚v‚nements …     *}
{*                        attendre                                    *}
{*  Sortie : masque bits de l'‚v‚nement intervenu                     *}
{*  Infos :  - WAIT_EVENT peut ˆtre cr‚‚ par combinaison OU des       *}
{*             diverses constantes telles que EV_MOU_MOVE,            *}
{*             EV_LEFT_PRESS, etc.                                    *}
{*           - les constantes ET et OU peuvent ˆtre sp‚cifi‚es comme  *}
{*             type de combinaison. Si vous optez pour ET, la         *}
{*             fonction ne rendra la main au programme d'appel qu'une *}
{*             fois que tous les ‚v‚nements seront intervenus. Avec   *}
{*             OU, l'intervention d'un au moins des ‚v‚nements        *}
{*             sp‚cifi‚s suffira.                                     *}
{**********************************************************************}

function MouEventWait( Typ : BYTE; WaitEvent : integer ) : integer;

var ActEvent : integer;
    Ligne,
    Colonne  : byte;
    Fin      : boolean;

begin
   Colonne := MouCol;       { Ranger la position actuelle de la souris }
   Ligne   := MouRow;
   Fin     := false;

  repeat
    {-- Attendre jusqu'… ce qu'un des ‚v‚nements se produise ----------}

    if Typ = ET then                                { Combinaison ET ? }
      repeat            { Oui, tous les ‚v‚nements doivent se produire }
        ActEvent := MouEvent;            { Rechercher ‚v‚nement actuel }
      until ActEvent = WaitEvent
    else                                              { Combinaison OU }
      repeat                     { Un ‚v‚nement au moins doit survenir }
        ActEvent := MouEvent;            { Rechercher ‚v‚nement actuel }
      until ( ActEvent and WaitEvent ) <> 0;

    ActEvent := ActEvent and WaitEvent;{Laisser que les bits ‚v‚nements}

    {-- Si on attend un d‚placement de la souris, l'‚v‚nement n'est -- }
    {-- accept‚ que si le curseur de la souris a ‚t‚ d‚plac‚ vers   -- }
    {-- une autre ligne et/ou une autre colonne de l'‚cran de texte  - }

    if ( ( (WaitEvent and EV_MOU_MOVE) <> 0 )  and
          ( Colonne = MouCol ) and  ( Ligne = MouRow ) ) then
      begin                 { Souris d‚plac‚e mais mˆme position ‚cran }
        ActEvent := ActEvent and not( EV_MOU_MOVE ); { Masquer bit move }
        Fin := ( ActEvent <> 0);         { Reste-t-il des ‚v‚nements ? }
      end
    else                                         { Ev‚nement intervenu }
      Fin := TRUE;
  until Fin;

  EvCol := MouCol;                       { Conserver position et zone  }
  EvRow := MouRow;                       { actuelles de la souris dans }
  ZonEv := ZonSou;                       { des variables globales      }

  MouEventWait := ActEvent;
end;

{**********************************************************************}
{*  MouISetEventHandler: installe un gestionnaire d'‚v‚nements appel‚ *}
{*                       par le driver de la souris lorsque survien-  *}
{*                       nent certains ‚v‚nements souris.             *}
{**------------------------------------------------------------------**}
{*  Entr‚e : EVENT = masque bits d‚crivant les ‚v‚nements dont        *}
{*                   l'intervention doit entraŒner un appel du        *}
{*                   gestionnaire d'‚v‚nements                        *}
{*           FPTR  = Pointeur sur gestionnaire ‚v‚n. du type FCTPTR   *}
{*  Infos :  - EVENT peut ˆtre cr‚‚ par combinaison OU des diverses   *}
{*             constantes telles que EV_MOU_MOVE, EV_LEFT_PRESS etc.  *}
{*           - le gestionnaire d'‚v‚n. doit ˆtre une proc‚dure FAR et *}
{*             ne modifier aucun des reg. processeur re‡us            *}
{**********************************************************************}

procedure MouISetEventHandler( Event : integer; PtrC : FCTPTR );

var Regs : Registers; { Registres du processeur pour appel d'interrup. }

begin
  Regs.AX := $000C;                 { Nø fct. pour "Set Mouse Handler" }
  Regs.CX := event;                      { Charger masque d'‚v‚nements }
  Regs.DX := PTRREC( PtrC ).Ofs;    { Adresse d'offset du gestionnaire }
  Regs.ES  := PTRREC( PtrC ).Seg; { Adresse de segment du gestionnaire }
  Intr( $33,  Regs );                 { Appeler le driver de la souris }
end;

{**********************************************************************}
{*  MouIGetX: D‚termine la colonne de texte dans laquelle figure le   *}
{*            curseur de la souris                                    *}
{**------------------------------------------------------------------**}
{*  Sortie : Colonne du curseur de la souris dans l'‚cran de texte    *}
{**********************************************************************}

function MouIGetX : byte;

var Regs : Registers; { Registres du processeur pour appel d'interrup. }

begin
  Regs.AX := $0003;               { Nø fct.: pour "Get mouse position" }
  Intr( $33,  Regs );                 { Appeler le driver de la souris }
  MouIGetX := Regs.CX shr 3;           { Convertir colonne et renvoyer }
end;

{**********************************************************************}
{*  MouIGetY: D‚terminer ligne de texte du curseur de la souris       *}
{**------------------------------------------------------------------**}
{*  Sortie : Ligne du curseur de la souris dans l'‚cran de texte      *}
{**********************************************************************}

function MouIGetY : byte;

var Regs : Registers;{ Registres du processeur pour appel d'interrupt. }

begin
  Regs.AX := $0003;               { Nø fct.: pour "Get mouse position" }
  Intr( $33, Regs );                  { Appeler le driver de la souris }
  MouIGetY := Regs.DX shr 3;             { Convertir ligne et renvoyer }
end;

{**********************************************************************}
{*  MouShowMouse: Place le curseur de la souris sur l'‚cran           *}
{**------------------------------------------------------------------**}
{*  Infos : Les appels de MouShowMouse et MouHidemOuse doivent        *}
{*          s'‚quilibrer pour avoir un effet                          *}
{**********************************************************************}

procedure MouShowMouse;

var Regs : Registers;{ Registres du processeur pour appel d'interrupt. }

begin
  Regs.AX := $0001;                       { Nø fct.: pour "Show Mouse" }
  Intr( $33, Regs );                  { Appeler le driver de la souris }
end;

{**********************************************************************}
{*  MouHideMouse: Elimine le curseur de la souris de l'‚cran          *}
{**------------------------------------------------------------------**}
{*  Infos : Les appels de MouShowMouse et MouHideMouse doivent        *}
{*          s'‚quilibrer pour avoir un effet                          *}
{**********************************************************************}

procedure MouHideMouse;

var Regs : Registers;{ Registres du processeur pour appel d'interrupt. }

begin
  Regs.AX := $0002;                        { Nø fct. pour "Hide Mouse" }
  Intr( $33, Regs);                   { Appeler le driver de la souris }
end;

{**********************************************************************}
{*  MouSetMoveArea: Fixe la zone de d‚placement pour le curseur de    *}
{*                  la souris                                         *}
{**------------------------------------------------------------------**}
{*  Entr‚e :  x1, y1 = Coordonn‚es coin sup‚rieur gauche de la zone   *}
{*            x2, y2 = Coordonn‚es coin inf‚rieur droit de la zone    *}
{*  Infos :  - Les ordonn‚es se rapportent … l'‚cran de texte et non  *}
{*             … l'‚cran graphique virtuel du driver de la souris     *}
{**********************************************************************}

procedure MouSetMoveArea( x1, y1, x2, y2 : byte );

var Regs : Registers;{ Registres du processeur pour appel d'interrupt. }

begin
  Regs.AX := $0008;               { Nø fct. pour "Set vertical Limits" }
  Regs.CX := integer( y1 ) shl 3;            { Conversion vers l'‚cran }
  Regs.DX := integer( y2 ) shl 3;               { virtuel de la souris }
  Intr( $33, Regs );                  { Appeler le driver de la souris }
  Regs.AX := $0007;             { Nø fct. pour "Set horizontal limits" }
  Regs.CX := integer( x1 ) shl 3;            { Conversion vers l'‚cran }
  Regs.DX := integer( x2 ) shl 3;               { virtuel de la souris }
  Intr( $33, Regs );                  { Appeler le driver de la souris }
end;

{**********************************************************************}
{*  MouSetSpeed: Fixe le rapport entre le d‚placement de la souris et *}
{*               le mouvement du curseur de la souris qui doit en     *}
{*               r‚sulter                                             *}
{**------------------------------------------------------------------**}
{*  Entr‚e : XSpeed = vitesse dans le sens des X                      *}
{*           YSpeed = vitesse dans le sens des Y                      *}
{*  Infos :  - Les deux paramŠtres sont exprim‚s en unit‚s            *}
{*             mickey / 8 points ‚cran                                *}
{**********************************************************************}

procedure MouSetSpeed( XSpeed, YSpeed : integer );

var Regs : Registers;{ Registres du processeur pour appel d'interrupt. }

begin
  Regs.AX := $000f;             { Nø fct. "Set mickeys to pixel ratio" }
  Regs.CX := XSpeed;
  Regs.DX := YSpeed;
  Intr( $33, Regs);                   { Appeler le driver de la souris }
end;

{**********************************************************************}
{*  MouMovePtr: AmŠne le curseur de la souris dans un emplacement     *}
{*              d‚termin‚ de l'‚cran                                  *}
{**------------------------------------------------------------------**}
{*  Entr‚e : COL = la nouvelle colonne d'‚cran du curseur souris      *}
{*           ROW = la nouvelle ligne d'‚cran du curseur souris        *}
{*  Infos :  - Les ordonn‚es se rapportent … l'‚cran de texte et non  *}
{*             … l'‚cran graphique virtuel du driver de la souris     *}
{**********************************************************************}

procedure MouMovePtr( Col, Row : byte );

var Regs   : Registers;{Registres du processeur pour appel d'interrupt.}
    NouZon : byte;           { Zone dans laquelle la souris est amen‚e }

begin
  Regs.AX := $0004;             { Nø fct. "Set mouse pointer position" }
  MouCol := col;                            { Stocker coordonn‚es dans }
  MouRow := row;                              { des variables globales }
  Regs.CX := integer( col ) shl 3;          { Convertir coordonn‚es et }
  Regs.DX := integer( row ) shl 3; {stocker dans des variables globales}
  Intr( $33, Regs );                  { Appeler le driver de la souris }

  NouZon := BufPtr^[ Row * TCol + Col ];                { Retirer zone }
  if NouZon <> ZonSou then                           { Nouvelle zone ? }
    begin                                                        { Oui }
      if NouZon = AUCUNE_ZONE then            { En dehors d'une zone ? }
        MouDefinePtr( StdPtr )    { Oui, curseur de la souris standard }
      else                                          { Non, zone connue }
        MouDefinePtr( PtrZonAct^[ NouZon ].PtrMask );
    end;
  ZonSou := NouZon;      { Ranger num‚ro de zone dans variable globale }
end;

{**********************************************************************}
{*  MouSetDefaultPtr: D‚finit l'apparence du curseur de la souris     *}
{*                    pour les zones de l'‚cran qui n'ont pas ‚t‚     *}
{*                    d‚sign‚es explicitement comme des zones souris  *}
{**------------------------------------------------------------------**}
{*  Entr‚e : standard = masques curseur et ‚cran pour curseur souris  *}
{*  Infos :  - Le paramŠtre transmis doit avoir ‚t‚ cr‚‚ avec la      *}
{*             fonction MouPtrMask                                    *}
{**********************************************************************}

procedure MouSetDefaultPtr( Standard : PTRVIEW );

begin
  StdPtr := Standard;       { Ranger masque bits dans variable globale }

  {-- Si la souris ne figure actuellement dans aucune zone, on     ----}
  {-- commute directement sur nouvelle apparence                   ----}

  if ZonSou = AUCUNE_ZONE then                    { Dans aucune zone ? }
   MouDefinePtr( Standard );                                     { Non }
end;

{**********************************************************************}
{*  MouEnd: Est appel‚e pour terminer le travail avec les fonctions   *}
{*          et proc‚dures du module de la souris                      *}
{**------------------------------------------------------------------**}
{*  Infos : - La proc‚dure n'a pas besoin d'ˆtre appel‚e explicite-   *}
{*            ment par le programme d'application car la fonction     *}
{*            MouInit la d‚finit comme proc‚dure Exit                 *}
{**********************************************************************}

{$F+}     { Doit ˆtre FAR pour permettre un appel comme proc‚dure EXIT }

procedure  MouEnd;

var Regs : Registers;{ Registres du processeur pour appel d'interrupt. }

begin
  MouHideMouse;             { Eliminer curseur de la souris de l'‚cran }
  Regs.AX := 0;              { R‚initialisation du driver de la souris }
  Intr( $33, Regs);                   { Appeler le driver de la souris }

  FreeMem( BufPtr, BLen );         { Lib‚rer … nouveau m‚moire allou‚e }

  ExitProc := ExitOld;            { Installer … nouveau proc‚dure Exit }
end;

{$F-}                                      { Plus de proc‚dures FAR }

{**********************************************************************}
{*  MouInit: Dirige le travail avec les diff‚rentes fonctions et      *}
{*           proc‚dures du module de la souris et initialise les      *}
{*           diff‚rentes variables                                    *}
{**------------------------------------------------------------------**}
{*  Entr‚e : Colonnes = Nombre de colonnes de l'‚cran                 *}
{*           Lignes   = Nombre de lignes de l'‚cran                   *}
{*  Sortie : TRUE si un driver de la souris est install‚, sinon FALSE *}
{*  Infos :  - Cette fonction doit ˆtre la premiŠre des diff‚rentes   *}
{*             proc‚dures et fonctions de ce module … ˆtre appel‚e    *}
{*             par un programme d'application                         *}
{**********************************************************************}

function MouInit( Colonnes, Lignes : byte ) : boolean;

var Regs : Registers; { Registres du processeur pour appel d'interrup. }

begin
  TLine := Lignes;                    { Stocker nombre de lignes et de }
  TCol  := Colonnes;            { colonnes dans des variables globales }

  ExitOld := ExitProc;           { Ranger adresse de la proc‚dure Exit }
  ExitProc := @MouEnd;           { D‚finir MouEnd comme proc‚dure Exit }

  {-- Allouer et remplir buffer pour les zones souris -----------------}

  BLen := TLine * TCol;            { Nombre de caractŠres dans l'‚cran }
  GetMem( BufPtr, BLen );             { Allouer buffer de zone interne }
  MouIBufFill( 0, 0, TCol-1, TLine-1, AUCUNE_ZONE );

  Regs.AX := 0;                      { Initialiser driver de la souris }
  Intr( $33, Regs );                  { Appeler le driver de la souris }
  MouInit := ( Regs.AX <> 0 );        { Driver de la souris install‚ ? }

  MouSetMoveArea( 0, 0, TCol-1, TLine-1 ); { Fixer zone de d‚placement }

  MouCol   := MouIGetX;                      { Charger position souris }
  MouRow   := MouIGetY;             { actuelle dans variables globales }
  ZonSou   := AUCUNE_ZONE;     { Curseur de la souris dans aucune zone }
  MouEvent := EV_LEFT_REL or EV_RIGHT_REL;{ Pas bouton de souris appuy‚}
  StdPtr   := MouPtrMask( PTRSAMECHAR, PTRINVCOL );   { Curseur souris }
  OldPtr   := PTRVIEW( 0 );

 {-- Installer le gestionnaire d'‚v‚nements assembleur "AssHand" ------}
 MouISetEventHandler( EV_MOU_ALL, FCTPTR(@AssHand) );

end;

{***********************************************************************
*                   P R O G R A M M E   P R I N C I P A L              *
***********************************************************************}

const Zones : array[0..4] of ZONE =           { Les zones de la souris }
  (
   ( x1:  0; y1:  0; x2: 79; y2:  0 ),                 { Ligne du haut }
   ( x1:  0; y1:  1; x2:  0; y2: 23 ),             { Colonne de gauche }
   ( x1:  0; y1: 24; x2: 78; y2: 24 ),                  { Ligne du bas }
   ( x1: 79; y1:  1; x2: 79; y2: 23 ),             { Colonne de droite }
   ( x1: 79; y1: 24; x2: 79; y2: 24 )           { Coin inf‚rieur droit }
  );

var Dummy : integer;              { Re‡oit le r‚sultat de MouEventWait }

begin
  {-- Fixer curseur de la souris pour diff‚rentes zones de la souris --}
  Zones[ 0 ].PtrMask := MouPtrMask( PtrDifChar($18), PtrInvCol);
  Zones[ 1 ].PtrMask := MouPtrMask( PtrDifChar($1b), PtrInvCol);
  Zones[ 2 ].PtrMask := MouPtrMask( PtrDifChar($19), PtrInvCol);
  Zones[ 3 ].PtrMask := MouPtrMask( PtrDifChar($1a), PtrInvCol);
  Zones[ 4 ].PtrMask := MouPtrMask( PtrDifChar($58), PtrDifCol($40));

  writeln(#13#10,'SOURIS - (c) 1989 by MICHAEL TISCHER'#13#10);
  if MouInit( 80, 25 ) then          { Initialiser module de la souris }
   begin           { Tout va bien, un driver de la souris est install‚ }
    writeln('Si vous d‚placez le curseur de la souris sur',ZV,
            'l''‚cran, surtout le long des bords, vous constaterez',ZV,
            'que l''apparence du curseur de la souris se modifie en',ZV,
            'fonction de sa position.',ZV,ZV,
            'Pour mettre fin … cette d‚mo, amenez le curseur de la',ZV,
            'souris dans le coin inf‚rieur droit de l''‚cran et appuyez'
        ,ZV,'alors simultan‚ment sur les boutons gauche et droit de',ZV,
            'la souris.' );

    MouSetDefaultPtr( MouPtrMask( PtrDifChar( $DB ), PtrDifCol( 3 ) ) );
    ZoneMouDef( 5, @Zones );                              { D‚f. zones }
    MouShowMouse;          { Afficher curseur de la souris sur l'‚cran }

    {-- Attendre que boutons gauche et droit soient appuy‚s en      ---}
    {-- mˆme temps et que le curseur de la souris se trouve … ce    ---}
    {-- moment dans la zone 4                                       ---}

    repeat                                            { Boucle de test }
     Dummy := MouEventWait( ET, EV_LEFT_PRESS or EV_RIGHT_PRESS );
    until ZonEv = 4;
   end
  else                { Pas de souris ou pas de driver souris install‚ }
    writeln('Aucun driver souris n''est install‚ !');
end.


