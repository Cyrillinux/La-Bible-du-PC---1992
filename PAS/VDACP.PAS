{***********************************************************************
*                            V D A C P . P A S                         *
**--------------------------------------------------------------------**
*  Fonction         : Montre comment programmer les registres DAC      *
*                     dans les 256 couleurs du mode graphique de la    *
*                     carte VGA. Le programme utilise les routines     *
*                     en assembleur du module V3240PA.ASM              *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     : 02.01.1991                                       *
*  DerniŠre MAJ     : 14.01.1991                                       *
***********************************************************************}

program VDACP;

uses dos, crt;

{-- D‚clarations de types ---------------------------------------------}

type DACREG = record                          { D‚crit un registre DAC }
                case integer of
                 0 : ( Rouge, Vert, Bleu : BYTE );    { Composants RGB }
                 1 : ( RGB : array[ 1..3] of BYTE );
              end;
     DACARRAY = array [0..255] of DACREG;          {Table DAC complŠte }

{-- R‚f‚rences externes aux routines en assembleur  -------------------}

{$L v3240pa}        { IntŠgre le module en assembleur }

procedure init320400; external;
procedure setpix( x, y : integer; couleur : byte ); external;
function  getpix( x, y: integer ) : byte ; external;
procedure setpage( page : byte ); external;
procedure showpage( page : byte ); external;

{-- Constantes --------------------------------------------------------}

const MAXX = 319;                              { Coordonn‚es maximales }
      MAXY = 399;

      LARGEUR  = 10;          { Largeur d'un bloc de couleur en pixels }
      HAUTEUR = 20;           { Hauteur d'un bloc de couleur en pixels }
      DISTANCE = 2;                         { Distance entre les blocs }
      LARGEURT = 16 * LARGEUR + ( 15 * DISTANCE );     { Largeur totale}
      HAUTEURT  = 16 * HAUTEUR + ( 15 * DISTANCE );   { Hauteur totale }
      STARTX  = ( MAXX - LARGEURT ) div 2;      { Coin bloc sup gauche }
      STARTY  = ( MAXY - HAUTEURT ) div 2;

{***********************************************************************
*  IsVga   : Teste la pr‚sence d'une carte VGA.                        *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : TRUE ou FALSE                                             *
***********************************************************************}

function IsVga : boolean;

var Regs : Registers;                   { Registres pour l'interruption}

begin
  Regs.AX := $1a00;               { La fonction 1Ah n'existe qu'en VGA }
  Intr( $10, Regs );
  IsVga := ( Regs.AL = $1a );
end;

{***********************************************************************
*  PrintChar : Affiche un caractŠre en mode graphique                  *
**--------------------------------------------------------------------**
*  Entr‚e : caractere = le caractŠre … afficher                        *
*           x, y      = Coordonn‚es du coin sup gauche                 *
*           cc        = Couleur du caractŠre                           *
*           cf        = Couleur du fond                                *
*  Info   : Le caractŠre est dessin‚ dans une matrice de 8*8 pixels    *
*           sur la base du jeu de caractŠres 8*8 en ROM                *
***********************************************************************}

procedure PrintChar( caractere : char; x, y : integer; cc, cf : byte );

type CARADEF = array[0..255,0..7] of byte; {Structure jeu de caractŠres}
     CARAPTR = ^CARADEF;             { Pointe sur le jeu de caractŠres }

var  Regs  : Registers;       { Registres pour g‚rer les interruptions }
     ch    : char;                                { Pixel du caractŠre }
     i, k,                                     { Compteur d'it‚rations }
     Masque : byte;         { Masque binaire pour dessiner le caractŠre}

const fptr : CARAPTR = NIL;   { Pointe sur le jeu de caractŠres en ROM }

begin
  if fptr = NIL then             { A-t-on d‚j… d‚termin‚ ce pointeur ? }
    begin                                                         { Non}
      Regs.AH := $11;                   { Appelle l'option $1130 de la }
      Regs.AL := $30;                         { fonction vid‚o du BIOS }
      Regs.BH := 3;          { pour obtenir un pointeur sur le jeu 8*8 }
      intr( $10, Regs );
      fptr := ptr( Regs.ES, Regs.BP );            { Compose le pointeur}
    end;

  if ( cf = 255 ) then                       { CaractŠre transparent ? }
    for i := 0 to 7 do  { Oui ne dessine que les pixels du premier plan}
      begin
        Masque := fptr^[ord(caractere),i];{Motif binaire pour une ligne}
        for k := 0 to 7 do
          begin
            if ( Masque and 128 <> 0 ) then        { Pixel … dessiner? }
              setpix( x+k, y+i, cc );                            { Oui }
            Masque := Masque shl 1;
          end;
      end
  else                                     { Non, tient compte du fond }
    for i := 0 to 7 do                           { Parcourt les lignes }
      begin
        Masque := fptr^[ord(caractere),i];{Motif binaire pour une ligne}
        for k := 0 to 7 do
          begin
            if ( Masque and 128 <> 0 ) then           { Premier plan ? }
              setpix( x+k, y+i, cc )                             { Oui }
            else
              setpix( x+k, y+i, cf );                       { Non, fond}
            Masque := Masque shl 1;
         end;
      end;
end;

{***********************************************************************
*  Line : Trace un segment dans la fenˆtre graphique en appliquant     *
*         l'algorithme de Bresenham                                    *
**--------------------------------------------------------------------**
*  Entr‚e : X1, Y1  = Coordonn‚es de l'origine (0 - ...)               *
*           X2, Y2  = Coordonn‚es de l'extr‚mit‚ terminale             *
*           COULEUR = couleur du segment                               *
***********************************************************************}

procedure Line( x1, y1, x2, y2 : integer; couleur : byte );

var d, dx, dy,
    aincr, bincr,
    xincr, yincr,
    x, y                 : integer;

{-- Proc‚dure accessoire pour ‚changer deux variables entiŠres --------}

procedure SwapInt( var i1, i2: integer );

var dummy : integer;

begin
  dummy := i2;
  i2    := i1;
  i1    := dummy;
end;

{-- Proc‚dure principale --------------------------------------------}

begin
  if ( abs(x2-x1) < abs(y2-y1) ) then     {Parcours : par axe X ou Y ? }
    begin                                            { par l'axe des Y }
      if ( y1 > y2 ) then                        { y1 sup‚rieur … y2 ? }
        begin
      SwapInt( x1, x2 );                      { Oui, ‚change X1 et X2, }
      SwapInt( y1, y2 );                                    { Y1 et Y2 }
        end;

      if ( x2 > x1 ) then xincr := 1          { Fixe le pas horizontal }
                     else xincr := -1;

      dy := y2 - y1;
      dx := abs( x2-x1 );
      d  := 2 * dx - dy;
      aincr := 2 * (dx - dy);
      bincr := 2 * dx;
      x := x1;
      y := y1;

      Setpix( x, y, couleur );              { Dessine le premier point }
      for y:=y1+1 to y2 do                      { Parcourt l'axe des Y }
        begin
          if ( d >= 0 ) then
            begin
              inc( x, xincr );
              inc( d, aincr );
            end
          else
            inc( d, bincr );
          Setpix( x, y, couleur );
        end;
    end
  else                                               { par l'axe des X }
    begin
      if ( x1 > x2 ) then                     { x1 plus grand que x2 ? }
        begin
      SwapInt( x1, x2 );                       { Oui, ‚change X1 et X2 }
      SwapInt( y1, y2 );                                    { Y1 et Y2 }
        end;

      if ( y2 > y1 ) then yincr := 1            { Fixe le pas vertical }
                     else yincr := -1;

      dx := x2 - x1;
      dy := abs( y2-y1 );
      d  := 2 * dy - dx;
      aincr := 2 * (dy - dx);
      bincr := 2 * dy;
      x := x1;
      y := y1;

      Setpix( x, y, couleur );              { Dessine le premier point }
      for x:=x1+1 to x2 do                      { Parcourt l'axe des X }
        begin
          if ( d >= 0 ) then
            begin
              inc( y, yincr );
              inc( d, aincr );
            end
          else
            inc( d, bincr );
          Setpix( x, y, couleur );
       end;
    end;
end;

{***********************************************************************
*  GrafPrint : Affiche une chaŒne format‚e sur l'‚cran graphique       *
**--------------------------------------------------------------------**
*  Entr‚es: X, Y   = Coordonn‚es de d‚part (0-...)                     *
*           CC     = Couleur des caractŠres                            *
*           CF     = Couleur du fond (255 = transparent)               *
*           STRING = ChaŒne avec indications de formatage              *
***********************************************************************}

procedure GrafPrint( x, y : integer; cc, cf : byte; strt : string );

var i : integer;                               { Compteur d'it‚rations }

begin
 for i:=1 to length( strt ) do
   begin
     printchar( strt[i], x, y, cc, cf );       { Affiche par printchar }
     inc( x, 8 );               { x … la position du caractŠre suivant }
   end;
end;


{***********************************************************************
*  GetDac: D‚termine les contenus d'un certain nombre de registres DAC *
**--------------------------------------------------------------------**
*  Entr‚es : FIRST = Num‚ro du premier registre (0-255)                *
*            NBR   = Nombre de registres DAC                           *
*            BUF   = buffer qui doit recevoir les contenus des         *
*                    registres DAC. Ce doit ˆtre une variable du type  *
*                    DACREG ou un tableau de variables de ce type      *
*  Info    : Le buffer transmis doit comporter trois octets par        *
*            registre DAC … lire (pour la composante rouge, verte et   *
*            bleue de chaque couleur)                                  *
***********************************************************************}

procedure GetDac( First, Nbr : integer; var Buf );

var Regs : Registers;             { Registres pour g‚rer l'interruption}

begin
  Regs.AX := $1017;             { Num‚ro de la fonction et de l'option }
  Regs.BX := First;                    { Num‚ro du premier registre DAC}
  Regs.CX := Nbr;                     { Nombre des registres … charger }
  Regs.ES := seg( Buf );            { Charge un pointeur sur le buffer }
  Regs.DX := ofs( Buf );
  intr( $10, Regs );                  { D‚clenche l'interruption vid‚o }
end;

{***********************************************************************
*  SetDac  : Charge un certain nombre de registres DAC                 *
**--------------------------------------------------------------------**
*  Entr‚es : FIRST = Num‚ro du premier registre DAC  (0-255)           *
*            NBR   = Nombre de registres                               *
*            BUF   = Buffer, d'o— sont tir‚es les valeurs … transf‚rer *
*                    dans les registres DAC. Il doit s'agir d'une      *
*                    variable de type DACREG ou d'un tableau de        *
*                    variables de ce type                              *
*  Info    : cf GetDac                                                 *
***********************************************************************}

procedure SetDac( First, Nbr : integer; var Buf );

var Regs : Registers;            { Registres pour g‚rer l'interruption }

begin
  Regs.AX := $1012;             { Num‚ro de la fonction et de l'option }
  Regs.BX := First;                   { Num‚ro du premier registre DAC }
  Regs.CX := Nbr;                      { Nombre de registres … charger }
  Regs.ES := seg( Buf );            { Charge un pointeur sur le buffer }
  Regs.DX := ofs( Buf );
  intr( $10, Regs );          { D‚clenche l'interruption vid‚o du BIOS }
end;

{***********************************************************************
*  PrintDac : Affiche le contenu d'un registre DAC et rŠgle la couleur *
*             dans le registre DAC 255                                 *
**--------------------------------------------------------------------**
*  Entr‚es : DREG    = Registre DAC                                    *
*            NUM     = Num‚ro de ce registre                           *
*            COULEUR = Couleur d'affichage                             *
***********************************************************************}

procedure PrintDac( DReg : DACREG; Num, Couleur : BYTE );

var numstr,                           { ChaŒne pour num‚ro de registre }
    rstr,                               { ChaŒne pour composante rouge }
    vstr,                               { ChaŒne pour composante verte }
    bstr : string[3];                   { ChaŒne pour composante bleue }

begin
  SetDac( 255, 1, DReg );           { Couleur dans le registre DAC 255 }
  str( Num : 3, numstr );     { Convertit en chaŒnes couleurs et num‚ro}
  str( DReg.Rouge : 2, rstr );
  str( DReg.Vert : 2, vstr );
  str( DReg.Bleu : 2, bstr );
  GrafPrint( 60, MAXY-10, Couleur, 0, 'DAC:' + numstr + '  R:' + rstr +
                                    '  V:' + vstr + '  B:' + bstr);
end;

{***********************************************************************
*  Encadre : Trace un cadre autour d'un champ de couleur               *
**--------------------------------------------------------------------**
*  Entr‚es : X       = Abscisse X du champ de couleur (0-15)           *
*            Y       = Ordonn‚e Y du champ de couleur (0-15)           *
*            COULEUR = Couleur du cadre                                *
*  Info    : L'‚paisseur du cadre est de 1 pixel ind‚pendamment        *
*            de la distance qui s‚pare les champs.                     *
***********************************************************************}

procedure Encadre( X, Y, Couleur : BYTE );

var sx, sy,                                  { Coin sup gauche du cadre}
    ex, ey : integer;                        { Coin inf droit du cadre }

begin
  sx := STARTX + X * (LARGEUR + DISTANCE) - 1;{calcule les coordonn‚es }
  ex := sx + LARGEUR + 1;                                   { du cadre }
  sy := STARTY + Y * (HAUTEUR + DISTANCE) - 1;
  ey := sy + HAUTEUR + 1;
  Line( sx, sy, ex, sy, Couleur );                  { Dessine le cadre }
  Line( ex, sy, ex, ey, Couleur );
  Line( ex, ey, sx, ey, Couleur );
  Line( sx, ey, sx, sy, Couleur );
end;

{***********************************************************************
*  ChangeDacReg : Modifie le contenu d'un registre DAC en m‚moire et   *
*                 dans la table DAC de la carte vid‚o, puis l'affiche  *
*                 sur l'‚cran                                          *
**--------------------------------------------------------------------**
*  Entr‚es : DREG  = Registre DAC … modifier                           *
*            NUM   = Num‚ro du registre DAC                            *
*            COMP  = Num‚ro de la composante … modifier    (1-3)       *
*                    1 = Rouge, 2 = Vert, 3 = Bleu                     *
*            INCR  = Incr‚ment pour cette composante                   *
***********************************************************************}

procedure ChangeDacReg( var DReg : DACREG; Num, Comp : BYTE;
                            Incr : integer );

begin
  inc( DReg.RGB[ Comp ], Incr );             { Incr‚mente la composante}
  if DReg.RGB[ Comp ] > 63 then                           { Sup … 63 ? }
    DReg.RGB[ Comp ] := 0;                            { Oui, remet … 0 }
  SetDac( Num, 1, DReg );                     { Charge le registre DAC }
  PrintDac( DReg, Num, 15 );               { Affiche le nouveau contenu}
end;

{***********************************************************************
*  Demo : Pr‚sente la programmation des registres DAC et le systŠme de *
*         couleur de la carte VGA                                      *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************}

procedure Demo;

var x,  y,
    ix, jx,
    iy, jy,
    k,  f  : integer;                          { Compteur d'it‚rations }
    ch     : char;                                            { Touche }
    dacbuf : DACARRAY;                            { Table DAC complŠte }
    DReg   : DACREG;                            { Registre DAC courant }

begin
{-- Dessine l'‚cran ---------------------------------------------------}

  SetPage( 0 );                                     { Traite la page 0 }
  ShowPage( 0 );                                   { Affiche la page 0 }
  GetDac( 0, 256, dacbuf );             { Charge la table DAC complŠte }

  GrafPrint( 10, 0, 255, 0,
             'VDACP  -  (c) 1991 by MICHAEL TISCHER' );

{-- Construit le bloc de 16*16 champs de couleur ----------------------}

  iy := STARTY;                          { Point de d‚part sur l'‚cran }
  jy := STARTY + HAUTEUR - 1;
  f  := 0;
  for y := 0 to 15 do                { Parcourt les 16 lignes de blocs }
    begin
      ix := STARTX;
      jx := STARTX + LARGEUR - 1;
      for x := 0 to 15 do           { Parcourt les 16 colonnes de blocs}
        begin
          for k := iy to jy do   { Dessine les blocs avec des segments }
            Line( ix, k, jx, k, f );
          inc( ix, LARGEUR + DISTANCE );       { Prochain bloc … droite}
          inc( jx, LARGEUR + DISTANCE );
          inc( f );                                 { Couelur suivante }
        end;
      inc( iy, HAUTEUR + DISTANCE );               { Position suivante }
      inc( jy, HAUTEUR + DISTANCE );
    end;

{-- Lit les entr‚es de l'utilisateur et r‚agit en cons‚quence ---------}
  ix := 0;               { Commence en haut … gauche avec la couleur 0 }
  iy := 0;
  jx := 0;
  jy := 0;
  k := 0;
  GetDac( 0, 1, DReg );                             { Lit la couleur 0 }
  Encadre( 0, 0, 15 );                              { Encadre le champ }
  PrintDac( DReg, 0, 15 );                     { et affiche le contenu }
  repeat
    ch := ReadKey;                                 { Attend une frappe }
    if ( ch <> #0 ) then                             { Code ‚tendu ? ? }
      case ch of                                    { Non, on exploite }
        'r' : ChangeDacReg( DReg, k, 1, +1 );            { r = Rouge + }
        'v' : ChangeDacReg( DReg, k, 2, +1 );             { v = Vert + }
        'b' : ChangeDacReg( DReg, k, 3, +1 );             { b = Bleu + }
        'R' : ChangeDacReg( DReg, k, 1, -1 );            { R = Rouge - }
        'V' : ChangeDacReg( DReg, k, 2, -1 );             { V = Vert - }
        'B' : ChangeDacReg( DReg, k, 3, -1 );             { B = Bleu - }
        ' ' : begin             { Space = r‚tablit la valeur d'origine }
                DReg := dacbuf[ k ];
                ChangeDacReg( DReg, k, 1, 0 );
              end;
      end
    else                                                 { Code ‚tendu }
      case ReadKey of
        #72 : if ( iy = 0 ) then                { Curseur vers le haut }
                jy := 15
              else
                jy := iy - 1;

        #80 : if ( iy = 15 ) then                { Curseur vers le bas }
                jy := 0
              else
                jy := iy + 1;

        #75 : if ( ix = 0  ) then                   { Curseur … gauche }
                jx := 15
              else
                jx := ix - 1;

        #77 : if ( ix = 15 ) then                   { Curseur … droite }
                jx := 0
              else
                jx := ix + 1;
      end;

    if ( ix <> jx ) or ( iy <> jy ) then         { Nouvelle position ? }
      begin                                                      { Oui }
        Encadre( ix, iy, 0 );                  { EnlŠve l'ancien cadre }
        Encadre( jx, jy, 15 );                { Trace un nouveau cadre }
        ix := jx;               { M‚morise le nouveau champ de couleur }
        iy := jy;
        k := iy*16+ix;                           { Calcule son  num‚ro }
        GetDac( k, 1, DReg );                  { Charge le registre DAC}
        PrintDac( DReg, k, 15 );                        { et l'affiche }
      end;
  until ch = #13;            { On recommence jusqu'… frappe de <Entr‚e>}

  SetDac( 0, 256, dacbuf );                     { restaure la table DAC}
end;

{----------------------------------------------------------------------}
{--                        Programme principal                     ----}
{----------------------------------------------------------------------}

begin
 if IsVga then                                { A-t-on une carte VGA ? }
   begin                                            { Oui, c'est parti }
     init320400;                        { Initialise le mode graphique }
     Demo;
     Textmode( CO80 );                        { R‚tablit le mode texte }
   end
 else
   writeln( 'VDACP  -  (c) 1991 by MICHAEL TISCHER'#13#10#10 +
            'Attention ce programme exige une carte VGA ' +
            '.'#13#10 );
end.
