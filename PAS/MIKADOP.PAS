{***********************************************************************
*                            M I K A D O P                             *
**--------------------------------------------------------------------**
*  Fonction : Montre comment mettre en service le mode 512 caractŠres  *
*             des cartes EGA et VGA. La routine de d‚monstration       *
*             installe une fenˆtre graphique en mode texte.            *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le :  2.04.1990                                           *
*  DerniŠre MAJ : 14.01.1991                                           *
***********************************************************************}

program MikadoP;

uses DOS, CRT;     { Inclut les unit‚s DOS et CRT }

{-- Constantes --------------------------------------------------------}

const EGAVGA_SEQUENCER = $3C4; { Port d'adresses/donn‚es du s‚quenceur }
      EGAVGA_MONCTR    = $3D4;                    { Contr“leur d'‚cran }
      EGAVGA_GRAPHCTR  = $3CE;{Port d'adr./donn‚es du contr“leur graph.}
      CHAR_LARGEUR     = 8;
      CHAR_BYTES       = 32;
      MIKADOS          = 5; { Nombre de mikados visibles en mˆme temps }

{-- D‚clarations de types ---------------------------------------------}

type VEL      = record         { D‚crit un couple caractŠre - attribut }
                  case boolean of                 { en m‚moire d'‚cran }
                    true  : ( Caractere, Attribut : byte );
                    false : ( Contenu             : word );
                end;
     VPTR     = ^VEL;               { Pointe sur un caractŠre/attribut }
     VELARRAY = array [1..25,1..80] of VEL; {Reproduit la m‚moire ‚cran}
     VELARPTR = ^VELARRAY;             { Pointe sur la m‚moire d'‚cran }

     FONT = array[0..255,0..CHAR_BYTES-1] of byte;{Reproduit une police}
     FPTR = ^font;                             { Pointe sur une police }

     PALARY = array[ 1..16] of BYTE;    { Jeu de registres de palettes }

{-- Variables globales ------------------------------------------------}

const vioptr : VELARPTR = ptr( $B800, $0000 ); { Pointe sur m‚m. ‚cran }

var CharHauteur,
    lenx    : byte;        { Largeur en pixels de la fenˆtre graphique }
    xmax,          { Coordonn‚es max en pixels de la fenˆtre graphique }
    ymax    : integer;
    fontptr : fptr;               { Pointe sur la police de caractŠres }

procedure CLI; inline( $FA );
procedure STI; inline( $FB );

{***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA/VGA.                   *
*             M‚morise en mˆme temps le nombre de lignes de trame      *
*             par caractŠre dans la variable CharHauteur               *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie : TRUE, si carte EGA ou VGA , sinon FALSE                    *
***********************************************************************}

function IsEgaVga : boolean;

var Regs : Registers;            { Registres pour g‚rer l'interruption }

begin
  Regs.AX := $1a00;               { La fonction 1Ah n'existe qu'en VGA }
  Intr( $10, Regs );
  if ( Regs.AL = $1a ) then     { Cette fonction est-elle disponible ? }
    begin
      IsEgaVGa := TRUE;
      CharHauteur := 16;                          { 16 lignes de trame }
    end
  else
    begin
      Regs.ah := $12;            { AppelLe l'option 10h de la fonction }
      Regs.bl := $10;
      intr($10, Regs);          { Appelle l'interruption vid‚o du BIOS }
      IsEgaVga := ( Regs.bl <> $10 );
      CharHauteur := 14;                          { 14 lignes de trame }
    end;
end;

{***********************************************************************
*  SetCharWidth : Fixe … 8 ou 9 pixels la largeur des caractŠres des   *
*                 cartes VGA.                                          *
**--------------------------------------------------------------------**
*  Entr‚e: LARGEUT : Largeur des caractŠres ( 8 ou 9 )                 *
***********************************************************************}

procedure SetCharWidth( largeur : byte );

var Regs : Registers;            { Registres pour g‚rer l'interruption }
    x    : byte;                                 { Variable de travail }

begin
  if ( largeur = 8 ) then Regs.BX := $0001    { BH = alignement horiz. }
                     else Regs.BX := $0800;   { BL = Valeur pour
                                             le registre du s‚quenceur }

  x := port[ $3CC ] and not(4+8);    { Passe de la r‚solution de 720 … }
  if ( largeur = 9 ) then                  { 640 pixels ou vice-versa  }
    x := x or 4;
  port[ $3C2 ] := x;

  CLI;                        { Programme le s‚quenceur en cons‚quence }
  portw[ EGAVGA_SEQUENCER ] := $0100;
  portw[ EGAVGA_SEQUENCER ] := $01 + Regs.BL shl 8;
  portw[ EGAVGA_SEQUENCER ] := $0300;
  STI;

  Regs.AX := $1000;                   { Ajuste l'alignement de l'‚cran }
  Regs.BL := $13;
  intr( $10, Regs );
end;

{***********************************************************************
*  SelectMaps : S‚lectionne les jeux de caractŠres accessibles par le  *
*               bit 3 de l'attribut de caractŠres                      *
**--------------------------------------------------------------------**
*  Entr‚es : MAP0 = Num‚ro du premier jeu de caractŠres (bit 3 = 0 )   *
*            MAP1 = Num‚ro du deuxiŠme jeu de caractŠres (bit 3 = 1 )  *
*  Info    : - Avec une carte EGA on peut choisir les jeux 0 … 3,      *
*              avec une carte VGA les jeux 0 … 7                       *
***********************************************************************}

procedure SelectMaps( map0, map1 : byte );

var Regs : Registers;         { Registres pour g‚rer les interruptions }

begin
  Regs.AX := $1103;{Prog. le registre de s‚lection du jeu de caractŠres}
  Regs.BL := ( ( map0 and 3 ) + ( map0 and 4 ) shl 2 ) +
             ( ( map1 and 3 ) shl 2 + ( map1 and 4 ) shl 3 );
  Intr( $10, Regs ); { Appelle l'option 03 de la fonction $11 }
end;

{***********************************************************************
*  GetFontAccess : Permet d'acc‚der directement … la deuxiŠme zone     *
*                  de m‚moire o— sont stock‚s les jeux de caractŠres   *
*                  par l'adresse A000:0000                             *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Info    : - A l'issue de cette proc‚dure, il n'est plus possible    *
*              d'acc‚der … la m‚moire d'‚cran par B800:0000            *
***********************************************************************}

procedure GetFontAccess;

const SeqRegs : array[1..4] of word = ( $0100, $0402, $0704, $0300 );
      GCRegs  : array[1..3] of word = ( $0204, $0005, $0406 );

var i : byte;                                  { Compteur d'it‚rations }

begin
  CLI;
  for i := 1 to 4 do              { Charge les registres du s‚quenceur }
    portw[ EGAVGA_SEQUENCER ] := SeqRegs[ i ];

  for i := 1 to 3 do    { Charge les registres du contr“leur graphique }
    portw[ EGAVGA_GRAPHCTR ] := GCRegs[ i ];
  STI;
end;

{***********************************************************************
*  ReleaseFontAccess : LibŠre l'accŠs … la m‚moire d'‚cran par         *
*                      B800:0000 empˆchent en mˆme temps l'accŠs aux   *
*                      jeux de caractŠre situ‚s en page m‚moire Nø2    *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************}

procedure ReleaseFontAccess;

const SeqRegs : array[1..4] of word = ( $0100, $0302, $0304, $0300 );
      GCRegs  : array[1..3] of word = ( $0004, $1005, $0E06 );

var i : byte;                                  { Compteur d'it‚rations }

begin
  for i := 1 to 4 do   { Charge les diff‚rents registres du s‚quenceur }
    portw[ EGAVGA_SEQUENCER ] := SeqRegs[ i ];
  for i := 1 to 3 do     { Charge les registres du contr“leur graphique}
    portw[ EGAVGA_GRAPHCTR ] := GCRegs[ i ];
end;

{***********************************************************************
*  ClearGraphArea : Efface la zone graphique en y mettant … 0 les      *
*                   motifs des caractŠres.                             *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************}

procedure ClearGraphArea;

var caracteres,                               { CaractŠres … parcourir }
    ligne    : byte;        { Lignes … l'int‚rieur de chaque caractŠre }

begin
  for caracteres := 0 to 255 do              { Parcourt les caractŠres }
    for ligne := 0 to CharHauteur-1 do           { Parcourt les lignes }
      fontptr^[ caracteres, ligne ] := 0;             { et les met … 0 }
end;

{***********************************************************************
*  InitGraphArea : Pr‚pare une zone d'‚cran … recevoir un affichage    *
*                  graphique.                                          *
**--------------------------------------------------------------------**
*  Entr‚e : X       = Colonne o— d‚bute la zone (1-80)                 *
*           Y       = Ligne o— d‚bute la zone (1-25)                   *
*           XLEN    = Largeur de la zone en caractŠres                 *
*           YLEN    = Profondeur de la zone en caractŠres              *
*           MAP     = Num‚ro du jeu de caractŠres graphiques           *
*           COULEUR = Couleur de la zone graphique (0 … 7 ou $FF)      *
*  Info   : - Si la couleur indiqu‚e est $FF , elle est variable       *
*             ce qui donne une effet de "mikado"                       *
***********************************************************************}

procedure InitGraphArea( x, y, xlen, ylen, map, couleur : byte );

var colonne, ligne : integer;                  { Compteur d'it‚rations }
    codec         : byte;                          { Code de caractŠre }

begin
  if ( xlen * ylen > 256 ) then                   { Zone trop grande ? }
    writeln( 'Erreur: La zone graphique ne doit pas englober ' +
             ' plus de 256 caracteres !' )
  else
    begin
      if ( CharHauteur = 16 ) then                             { VGA ? }
       SetCharWidth( 8 );   { Oui, on change la largeur des caractŠres }
      SelectMaps( 0, map );         { S‚lectionne le jeu de caractŠres }
      xmax := xlen*CHAR_LARGEUR;           { Coordonn‚es max en pixels }
      ymax := ylen*CharHauteur;
      lenx := xlen;
      fontptr := ptr( $A000, map * $4000 ); { Pointe sur m‚m graphique }
      GetFontAccess;         { Autorise l'accŠs aux jeux de caractŠres }
      ClearGraphArea;                                 { Efface la zone }
      ReleaseFontAccess;       { r‚tablit l'accŠs … la m‚moire d'‚cran }

      {-- Remplit la zone graphique avec des caractŠres ---------------}

      codec := 0;
      for ligne := ylen-1 downto 0 do          { Lignes de bas en haut }
        for colonne := 0 to xlen-1 do    { Colonnes de gauche … droite }
          begin              { Fixe le code et l'attribut du caractŠre }
            vioptr^[ligne+y,colonne+x].Caractere := codec;
            if ( couleur = $ff ) then
              vioptr^[ligne+y,colonne+x].Attribut := codec mod 6 + 1 + 8
            else
              vioptr^[ligne+y,colonne+x].Attribut := couleur or $08;
            inc( codec );                          { CaractŠre suivant }
          end;
    end;
end;

{***********************************************************************
*  CloseGraphArea : Cl“ture l'accŠs … la zone graphique                *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************}

procedure CloseGraphArea;

begin
  ReleaseFontAccess;             { LibŠre l'accŠs … la m‚moire d'‚cran }
  SelectMaps( 0, 0 );                 { Choisit le jeu de caractŠres 0 }
  if ( CharHauteur = 16 ) then                                 { VGA ? }
   SetCharWidth( 9 );            { Oui, fixe la largeur des caractŠres }
end;

{***********************************************************************
*  SetPixel: Dessine ou efface un pixel dans la fenˆtre graphique      *
**--------------------------------------------------------------------**
*  Entr‚e : X,Y   = Coordonn‚es du pixel (0-...)                       *
*            ON   = TRUE pour dessiner et FALSE pour effacer           *
***********************************************************************}

procedure SetPixel( x, y : integer; on : boolean );

var charnum,                                     { Num‚ro du caractŠre }
    line     : byte;                 { Line … l'int‚rieur du caractŠre }

begin
  if ( x < xmax ) and ( y < ymax ) then            { Coordonn‚es o.k.? }
    begin             { Oui calcule le num‚ro du caractŠre et la ligne }
      charnum := ((x div CHAR_LARGEUR) + (y div CharHauteur * lenx));
      line    := CharHauteur - ( y mod CharHauteur ) - 1;
      if on then                               { Dessiner ou effacer ? }
        fontptr^[charnum, line] := fontptr^[charnum, line] or
             1 shl (CHAR_LARGEUR - 1 - ( x mod CHAR_LARGEUR ) )
      else
        fontptr^[charnum, line] := fontptr^[charnum, line] and
           not( 1 shl (CHAR_LARGEUR - 1 - ( x mod CHAR_LARGEUR ) ) );
    end;
end;

{***********************************************************************
*  Line : Trace un segment dans la fenˆtre graphique en appliquant     *
*         l'algorithme de Bresenham                                    *
**--------------------------------------------------------------------**
*  Entr‚e : X1, Y1 = Coordonn‚es de l'origine (0 - ...)                *
*           X2, Y2 = Coordonn‚es de l'extr‚mit‚ terminale              *
*           ON     = TRUE pour dessiner et FALSE pour effacer          *
***********************************************************************}

procedure Line( x1, y1, x2, y2 : integer; on : boolean );

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

{-- Proc‚dure principale ----------------------------------------------}

begin
  if ( abs(x2-x1) < abs(y2-y1) ) then{ Sens : par l'axe des X ou des Y }
    begin                                            { par l'axe des Y }
      if ( y1 > y2 ) then                        { y1 sup‚rieur … y2 ? }
        begin
          SwapInt( x1, x2 );                  { Oui, ‚change X1 et X2, }
          SwapInt( y1, y2 );                                { Y1 et Y2 }
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

      SetPixel( x, y, on );                 { Dessine le premier point }
      for y:=y1+1 to y2 do                      { Parcourt l'axe des Y }
        begin
          if ( d >= 0 ) then
            begin
              inc( x, xincr );
              inc( d, aincr );
            end
          else
            inc( d, bincr );
          SetPixel( x, y, on );
        end;
    end
  else                                               { par l'axe des X }
    begin
      if ( x1 > x2 ) then                     { x1 plus grand que x2 ? }
        begin
          SwapInt( x1, x2 );                   { Oui, ‚change X1 et X2 }
          SwapInt( y1, y2 );                                { Y1 et Y2 }
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

      SetPixel( x, y, on );                 { Dessine le premier point }
      for x:=x1+1 to x2 do                      { Parcourt l'axe des X }
        begin
          if ( d >= 0 ) then
            begin
              inc( y, yincr );
              inc( d, aincr );
            end
          else
            inc( d, bincr );
          SetPixel( x, y, on );
       end;
    end;
end;

{***********************************************************************
*  SetPalCol : d‚finit une couleur dans une des 16 palettes            *
*              ou la couleur du cadre d'‚cran (Overscan-Color)         *
**--------------------------------------------------------------------**
*  Entr‚e : RegNr = Num‚ro du registre de palette (0 … 15) ou 16       *
*                   pour la couleur du cadre d'‚cran                   *
*           Col   = Code de couleur entre 0 et 15                      *
***********************************************************************}

procedure SetPalCol( RegNr : byte; Col : byte );

var Regs   : Registers;       { Registres pour g‚rer les interruptions }

begin
  Regs.AX := $1000;              { Option $00 de la fonction vid‚o $10 }
  Regs.BH := Col;                                       { Code couleur }
  Regs.BL := RegNr;      { Num‚ro du registre du contr“leur d'attribut }
  intr( $10, Regs );            { Appelle l'interruption vid‚o du BIOS }
end;

{***********************************************************************
*  SetPalAry : Installe une nouvelle palette de 16 couleurs            *
*              sans changer la couleur du cadre d'‚cran.               *
**--------------------------------------------------------------------**
*  Entr‚e : NewCol = Table de palettes du type PALARY                  *
***********************************************************************}

procedure SetPalAry( NewCol : PALARY );

var i : byte;   { Compteur d'it‚rations }

begin
  for i := 1 to 16 do  { Parcourt les 16 ‚l‚ments de la table }
    SetPalCol( i-1, NewCol[ i ] ); { Fixe une couleur }
end;

{***********************************************************************
*  GetPalCol: D‚termine le contenu d'un registre de palette            *
**--------------------------------------------------------------------**
*  Entr‚e : RegNr = Num‚ro du registre de palette (0 … 15) ou 16       *
*                   pour la couleur du cadre d'‚cran                   *
*  Sortie : Code de couleur                                            *
*  Info   : Avec les cartes EGA il n'est pas possible de lire le       *
*           contenu des registres de palette. On suppose que dans ce   *
*           cas les registres de palette sont en disposition standard, *
*           la fonction retourne alors le num‚ro correspondant         *
***********************************************************************}

function GetPalCol( RegNr : byte ) : byte;

var Regs   : Registers;                { Registres pour l'interruption }

begin
  if ( CharHauteur = 14 ) then                           { Carte EGA ? }
   GetPalCol := RegNr{ Oui impossible de lire les registres de palette }
  else                                                     { Non , VGA }
    begin
      Regs.AX := $1007;          { Option $07 de la fonction vid‚o $10 }
      Regs.BL := RegNr;  { Num‚ro du registre du contr“leur d'attribut }
      intr( $10, Regs );      { D‚clenche l'interruption vid‚o du BIOS }
      GetPalCol := Regs.BH;       { C'est ici que se trouve le contenu }
    end;                                      { du registre de palette }
end;

{***********************************************************************
*  GetPalAry : Lit les contenus des 16 registres de palette et les     *
*              transfŠre dans une table                                *
**--------------------------------------------------------------------**
*  Entr‚e : ColAry = Table de palettes de type PALARY, qui va recevoir *
*                    qui va recevoir les codes des couleurs            *
***********************************************************************}

procedure GetPalAry( var ColAry : PALARY );

var i : byte;                                  { Compteur d'it‚rations }

begin    for i := 1 to 16 do     { Parcourt les 16 ‚l‚ments du tableau }
    ColAry[ i ] := GetPalCol( i-1 );   { Lit une couleur … chaque fois }
end;

{***********************************************************************
*  Mikado : D‚monstration du maniement des routines pr‚sent‚es         *
*           dans ce programme                                          *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                     *
***********************************************************************}

procedure Mikado;

type linie = record                         { Coordonn‚es d'un segment }
               x1, y1,
               x2, y2  : integer;
             end;

const NewCols : PALARY =
( {--------- Couleurs des caractŠres de texte ordinaires --------------}
          BLACK,                                                { noir }
          BLUE,                                                  { bleu}
          GREEN,                                                { vert }
          RED,                                                 { rouge }
          CYAN,                                                 { cyan }
          MAGENTA,                                           { magenta }
          YELLOW,                                               { brun }
          WHITE,                                               { blanc }
                  {------------- Couleurs des graphiques --------------}
          LIGHTBLUE,                                      { bleu clair }
          LIGHTGREEN,                                     { vert clair }
          LIGHTRED,                                      { rouge clair }
          LIGHTCYAN,                                      { cyan clair }
          LIGHTMAGENTA,                                { magenta clair }
          BLUE,                                                 { bleu }
          YELLOW,                                              { jaune }
          WHITE );                                             { blanc }

var i,                                         { Compteur d'it‚rations }
    first,                           { Indice du mikado le plus r‚cent }
    last   : integer;                { Indice du mikado le plus ancien }
    clear  : boolean;                             { Efface les mikados }
    lar    : array[1..MIKADOS] of linie;           { Table des mikados }
    OldCols: PALARY;                    { Table des anciennes couleurs }

begin
  GetPalAry( OldCols );             { D‚termine les couleurs pr‚sentes }
  SetPalAry( NewCols );                { Installe une nouvelle palette }
  TextColor( 7 );
  TextBackGround( 1 );
  ClrScr;                                             { Efface l'‚cran }
  GotoXY(1,1);                           { Et le remplit de caractŠres }
  for i:=1 to 25*80-1 do                             { du jeu standard }
   write( chr(32 + i mod 224) );

  {-- Initialise la zone graphique et fait tomber les mikados ---------}

  GotoXY(27,6);
  TextColor( 7 );
  TextBackGround( 3 );
  write('       M I K A D O       ' );
  GotoXY(27,6);
  InitGraphArea( 27, 7, 25, 10, 1,  $FF );
  GetFontAccess;               { Assure l'accŠs aux jeux de caractŠres }

  clear := false;                           { Pour effacer les mikados }
  first := 1;                          { Commence au d‚but de la table }
  last := 1;
  repeat                                          { Boucle des mikados }
    if first = MIKADOS+1 then first := 1;              { Wrap-Around ? }
    lar[first].x1 := random( xmax-1 );                { Cr‚e un mikado }
    lar[first].x2 := random( xmax-1 );
    lar[first].y1 := random( ymax-1 );
    lar[first].y2 := random( ymax-1 );
    line( lar[first].x1, lar[first].y1,                { et le dessine }
          lar[first].x2, lar[first].y2, true );
    inc( first );                                     { Mikado suivant }
    if first = MIKADOS+1 then clear := true;       { faut-il effacer ? }
    if clear then                                       { maintenant ? }
      begin                                                      { Oui }
        line( lar[last].x1, lar[last].y1,
              lar[last].x2, lar[last].y2, false );
        inc( last );    { Mikado suivant }
        if last = MIKADOS+1 then last := 1;
      end;
  until keypressed;            { R‚pŠte jusqu'… d‚tection d'une frappe }

  {-- Termine le programme --------------------------------------------}

  CloseGraphArea;
  SetPalAry( OldCols );                  { R‚tablit l'ancienne palette }
  GotoXY(1, 25 );
  TextColor( 7 );
  TextBackGround( 0 );
  ClrEol;
  writeln( 'Le jeu de caractŠres standard est … nouveau en place.');
end;

{----------------------------------------------------------------------}
{------------------------ PROGRAMME PRINCIPAL -------------------------}
{----------------------------------------------------------------------}

begin
  if IsEgaVga then                     { A-t-on une carte EGA ou VGA ? }
    Mikado                             { Oui, c'est parti pour la d‚mo }
  else                 { Non, impossible de faire tourner le programme }
    writeln( 'Attention: aucune carte EGA ou VGA n''est install‚e !' );
end.
