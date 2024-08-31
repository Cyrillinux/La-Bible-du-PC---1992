{***********************************************************************
*                           S 3 2 2 0 P . P A S                        *
**--------------------------------------------------------------------**
*  Fonction : Montre comment travailler avec des sprites dans le mode  *
*             graphique VGA 320*200 en 256 couleurs avec quatre pages  *
*             d'‚cran. Le programme utilise les routines en assembleur *
*             des modules V3220PA.ASM et S3220PA.ASM                   *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le : 12.09.1990                                           *
*  DerniŠre MAJ : 14.01.1991                                           *
***********************************************************************}

program S3220P;

uses dos, crt;

{-- R‚f‚rences externes aux routines en assembleur --------------------}

{$L v3220pa}                         { IntŠgre un module en assembleur }

procedure init320200; external;
procedure setpix( x, y : integer; couleur : byte ); external;
function  getpix( x, y: integer ) : byte ; external;
procedure setpage( page : byte ); external;
procedure showpage( page : byte ); external;

{$L s3220pa}    { IntŠgre un module en assembleur }

procedure blockmove( depage : byte; dex, dey : integer;
                     apage : byte; ax, ay : integer;
                     largeur, hauteur: byte; bmskp : pointer ); external;

{-- Constantes --------------------------------------------------------}

const MAXX = 319;                              { Coordonn‚es maximales }
      MAXY = 199;

      OUT_LEFT   = 1;     { Indicateurs de collision pour SpriteMove() }
      OUT_TOP    = 2;
      OUT_RIGHT  = 4;
      OUT_BOTTOM = 8;
      OUT_NO     = 0;                                     { no problem }

{-- D‚clarations de types ---------------------------------------------}

type SPLOOK = record                               { Image d'un sprite }
                largeur,                              { Largeur totale }
                hauteur,                 { Hauteur en lignes de pixels }
                page,                       { Page de m‚morisation ... }
                msklen : byte;                 { Longueur d'une entr‚e }
                bmskp  : pointer;     { Pointeur sur le masque binaire }
                ligne  : integer;    { Ligne de m‚morisation du sprite }
              end;                                      { dans sa page }
     SPLP = ^SPLOOK;                            { Pointeur sur l'image }

     SPID = record                        { Descripteur de sprite (ID) }
              fondpage :byte;                           { Page de fond }
              x, y : array [0..1] of integer;    { Coord. pages 0 et 1 }
              fondx, fondy : integer;            { Buffer pour le fond }
              splookp : SPLP;                   { Pointeur sur l'image }
            end;
     SPIP = ^SPID;                          { Pointeur sur descripteur }

     BYTEAR = array[0..10000] of byte;  { Pour adresser les diff‚rents }
     BARPTR = ^BYTEAR;                                       { buffers }

     PTRREC = record       { Pour d‚composer un pointeur ou un LONGINT }
                ofs,
                seg : word;
              end;

{***********************************************************************
*  IsVga : Teste la pr‚sence d'une carte VGA.                          *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : TRUE ou FALSE                                             *
***********************************************************************}

function IsVga : boolean;

var Regs : Registers;                  { Registres pour l'interruption }

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
      fptr := ptr( Regs.ES, Regs.BP );           { Compose le pointeur }
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
*  Entr‚e : X1, Y1 = Coordonn‚es de l'origine (0 - ...)                *
*           X2, Y2 = Coordonn‚es de l'extr‚mit‚ terminale              *
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
  if ( abs(x2-x1) < abs(y2-y1) ) then    { Parcours : par axe X ou Y ? }
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
*  Entr‚es : X, Y   = Coordonn‚es de d‚part (0-...)                    *
*            CC     = Couleur des caractŠres                           *
*            CF     = Couleur du fond (255 = transparent)              *
*            STRING = ChaŒne avec indications de formatage             *
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
*  CreateSprite : Cr‚e un sprite … l'aide d'un motif de pixels         *
*                 pr‚alablement compil‚                                *
**--------------------------------------------------------------------**
*  Entr‚es : SPLOOKP  = Pointeur sur la structure de donn‚es produite  *
*                       par CompileSprite                              *
*            FONDPAGE = Page d'‚cran qui doit m‚moriser le fond du     *
*                       sprite                                         *
*            FONDX,   = Coordonn‚es dans la page de fond o— doit ˆtre  *
*            FONDY      m‚moris‚ le fond du sprite                     *
*  Sortie  : Pointeur sur la structure du sprite cr‚‚e                 *
*  Info    : La m‚morisation du fond du sprite n‚cessite deux zones    *
*            contigu‰s de la taille du sprite.                         *
***********************************************************************}

function CreateSprite( splookp : SPLP; fondpage : byte;
                       fondx, fondy : integer              ) : SPIP;

var spidp : SPIP;                     { Pointeur sur la structure cr‚‚e}

begin
  new( spidp );               { Alloue de la m‚moire pour la structure }
  spidp^.splookp := splookp;                   { Y reporte les donn‚es }
  spidp^.fondpage := fondpage;
  spidp^.fondx := fondx;
  spidp^.fondy := fondy;

  CreateSprite := spidp;       { Retourne un pointeur sur la structure }
end;

{***********************************************************************
*  CompileSprite : Cr‚e le motif binaire d'un sprite … l'aide d'une    *
*                  d‚finition connue au moment de l'ex‚cution          *
**--------------------------------------------------------------------**
*  Entr‚e : BUFP      = Pointeur sur un tableau de pointeurs           *
*                       r‚f‚ren‡ant des chaŒnes de caractŠres qui      *
*                       repr‚sentent le motif du sprite                *
*           HAUTEUR   = Hauteur sprite et nb de chaŒnes de caractŠres  *
*           PAGE      = Page graphique pour dessiner le sprite         *
*           Y         = Ligne o— commence le dessin                    *
*           CLR       = CaractŠre ASCII associ‚ … plus petite couleur  *
*           COULEURPP = Premier code de couleur pour CLR               *
*  Info   : Les sprites sont dessin‚s en partant du bord gauche de la  *
*           ligne indiqu‚e                                             *
***********************************************************************}

function CompileSprite( var buf; hauteur, page : byte;
                     y : integer; clr : char; couleurpp : byte ) : SPLP;

type BYPTR  = ^byte;                           { Pointeur sur un octet }

var  largeur,                { Longueur des chaŒnes = largeur du motif }
     c,                                        { m‚morise un caractŠre }
     couleur,                                     { Couleur d'un pixel }
     i, k, l,                                 { Compteurs d'it‚rations }
     pixc,       { Compteurs de pixels pour compiler le masque binaire }
     pixm     : byte;                               { Masque de pixels }
     distance,                            { Distance entre les sprites }
     lx, ly   : integer;                       { Coordonn‚es courantes }
     splookp  : SPLP;                { Pointeur sur la structure cr‚‚e }
     lspb     : BYPTR;   { Pointeur courant dans le buffer des sprites }
     bptr     : barptr;          {Pour adresser le buffer avec l'image }

begin
         {-- Cr‚e un structure Sprite Look et la remplit --------------}

  new( splookp );
  bptr := @buf;                       { Pointeur sur le buffer du logo }
  largeur := bptr^[0];       { Longueur des chaŒnes ou largeur du logo }
  distance := ( ( largeur + 3 + 3 ) div 4 ) * 4;
  splookp^.largeur := distance;
  splookp^.msklen := (distance*hauteur+7) div 8;
  getmem( splookp^.bmskp, splookp^.msklen * 4 );
  splookp^.hauteur  := hauteur;
  splookp^.ligne  := y;
  splookp^.page  := page;

{-- Replit le fond du sprite dans sa page d'origine avec les codes --}
                          {-- pour le fond de caractŠres transparent --}

  setpage( page );                            { Fixe la page de dessin }
  lx := 4 * distance - 1;
  for ly:=y+hauteur-1 downto y do
    Line( 0, ly, lx, ly, 255 );

            {-- Dessine quatre fois le sprite dans sa page d'origine --}

  lx := 0;                                   { Commence au bord gauche }
  for l := 1 to 4 do                             { Dessine quatre fois }
    begin
      for i := 0 to hauteur-1 do                 { Parcourt les lignes }
        for k := 0 to largeur-1 do             { Parcourt les colonnes }
          begin
            c := bptr^[i*(largeur+1)+k+1];            { Lit la couleur }
            if ( c = 32 ) then                       { Pixel de fond ? }
              setpix( lx+k, y+i, 255 ){ Oui met le code de couleur 255 }
            else                  { Non met le code de couleur indiqu‚ }
              setpix( lx+k, y+i, couleurpp+(c-ord(clr)) );
          end;
      inc( lx, distance+1 );                        { Colonne suivante }
    end;

{ Parcourt les quatre sprites dessin‚s et g‚nŠre les masques binaires }
{-- pour copier les sprites dans les plans de bits --}

  pixm := 0;
  pixc := 0;
  lx := 0;
  for l := 0 to 3 do
    begin
      lspb := splookp^.bmskp;
      inc( PTRREC( lspb ).ofs, splookp^.msklen * l );

      for i := 0 to hauteur-1 do
        for k := 0 to distance-1 do
          begin
            pixm := pixm shr 1;{ D‚cale masque d'un bit vers la droite }
            if ( getpix( lx+k, y+i ) <> 255 ) then    {Pixel de fond ? }
              pixm := pixm or 128;        { Non, fixe un bit du masque }
            inc( pixc, 1 );
            if ( pixc = 8 ) then      { A-t-on d‚j… trait‚ huit pixels }
              begin{ Oui m‚morise le masque dans le buffer des sprites }
                lspb^ := pixm;
                inc( PTRREC( lspb ).ofs, 1 );
                pixc := 0; { Remet … 0 le compteur de pixels et masque }
                pixm := 0;
              end;
          end;

      if ( pixc <> 0 ) then         { Dernier quartet dans le buffer ? }
        begin                                                     { Non}
          lspb^ := pixm shr 4;      { Quartet haut dans le quartet bas }
          pixc := 0; { R‚initialise le compteur de pixels et le masque }
          pixm := 0;
        end;

      inc( lx, distance );  { LX pointe sur le d‚but du sprite suivant }
    end;

  CompileSprite := splookp; { Renvoie un ptr sur le buffer des sprites }
end;

{***********************************************************************
*  PrintSprite : AFfiche un sprite dans une page donn‚e                *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE  = Page concern‚e (0 ou 1)                           *
***********************************************************************}

procedure PrintSprite( spidp : SPIP; page : byte );

var largeur  : byte;                        { Largeur totale du sprite }
    x       : integer;             { Abscisse X du sprite dans sa page }
    splookp : SPLP;                   { Pointeur sur l'image du sprite }

begin
  splookp := spidp^.splookp;
  largeur  := splookp^.largeur;
  x       := spidp^.x[page];
  blockmove( splookp^.page, largeur * (x mod 4), splookp^.ligne, page,
             x and not(3), spidp^.y[page], largeur, splookp^.hauteur,
             @BARPTR(splookp^.bmskp)^[(x mod 4) * splookp^.msklen] );
end;

{***********************************************************************
*  GetSpriteBg : Lit le fond du sprite et le m‚morise … l'emplacement  *
*                pr‚vu                                                 *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*           PAGE  = Page d'o— est tir‚ le fond (0 ou 1)                *
***********************************************************************}

procedure GetSpriteBg( spidp : SPIP; page : BYTE );

var splookp : SPLP;                   { Pointeur sur l'image du sprite }

begin
 splookp := spidp^.splookp;
 blockmove( page, spidp^.x[page], spidp^.y[page],
            spidp^.fondpage, spidp^.fondx + ( splookp^.largeur * page ),
            spidp^.fondy, splookp^.largeur, splookp^.hauteur, NIL );
end;

{***********************************************************************
*  RestoreSpriteBg : R‚tablit dans la page d'origine le fond d'un      *
*                    sprite sauvegard‚ au pr‚alable                    *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE  = Page o— doit ˆtre recopi‚ le fond (0 ou 1)        *
***********************************************************************}

procedure RestoreSpriteBg( spidp : SPIP; page : BYTE );

var splookp : SPLP;                   { Pointeur sur l'image du sprite }

begin
 splookp := spidp^.splookp;
 blockmove( spidp^.fondpage, spidp^.fondx + ( splookp^.largeur * page ),
            spidp^.fondy, page, spidp^.x[page], spidp^.y[page],
            splookp^.largeur, splookp^.hauteur, NIL );
end;

{***********************************************************************
*  MoveSprite : D‚place un sprite                                      *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP  = Pointeur sur la structure du sprite               *
*           PAGE   = Page o— doit ˆtre r‚tabli le fond (0 ou 1)        *
*           DELTAX = D‚placement dans les directions X et Y            *
*           DELTAY                                                     *
*  Sortie : Indicateurs de collision cf constantes OUT_...             *
***********************************************************************}

function MoveSprite( spidp : SPIP; page : byte;
                     deltax, deltay : integer    ) : byte;

var nouvx, nouvy : integer;          { nouvelles coordonn‚es du sprite }
    out        : byte;           { Indique les collisions avec le bord }

begin
     {-- D‚cale l'abscisse X et teste s'il y a collision avec le bord--}

 nouvx := spidp^.x[page] + deltax;
 if ( nouvx  < 0 ) then
   begin
     nouvx := 0 - deltax - spidp^.x[page];
     out := OUT_LEFT;
   end
 else
   if ( nouvx > MAXX - spidp^.splookp^.largeur ) then
     begin
       nouvx := (2*(MAXX+1))-nouvx-2*(spidp^.splookp^.largeur);
       out := OUT_RIGHT;
     end
  else
     out := OUT_NO;

    {-- D‚cale l'ordonn‚e Y et teste s'il y a collision avec le bord --}

 nouvy := spidp^.y[page] + deltay;                                   { }
 if ( nouvy < 0 ) then                                    { Bord sup ? }
   begin                                { Oui deltay doit ˆtre n‚gatif }
     nouvy := 0 - deltay - spidp^.y[page];
     out := out or OUT_TOP;
   end
 else
   if ( nouvy + spidp^.splookp^.hauteur > MAXY+1  ) then  { bord inf ? }
     begin                              { Oui deltay doit ˆtre positif }
       nouvy := (2*(MAXY+1))-nouvy-2*(spidp^.splookp^.hauteur);
       out := out or OUT_BOTTOM;
     end;

{Ne fixe une nouvelle position que si elle est diff‚rente de l'ancienne}

 if ( nouvx <> spidp^.x[page] ) or  ( nouvy <> spidp^.y[page] ) then
   begin                                           { Nouvelle position }
     RestoreSpriteBg( spidp, page );                { R‚tablit le fond }
     spidp^.x[page] := nouvx;        { Prend les nouvelles coordonn‚es }
     spidp^.y[page] := nouvy;
     GetSpriteBg( spidp, page );                 { Lit le nouveau fond }
     PrintSprite( spidp, page );      { Dessine le sprite dans la page }
   end;

 MoveSprite := out;
end;

{***********************************************************************
*  SetSprite : Place le sprite … une position donn‚e                   *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP  = Pointeur sur la structure du sprite               *
*           x0, y0 = Coordonn‚es du sprite en page 0                   *
*           x1, y1 = Coordonn‚es du sprite en page 1                   *
*  Info   : Cette fonction doit ˆtre d‚clench‚e avant le premier       *
*           appel … MoveSprite()                                       *
***********************************************************************}

procedure SetSprite( spidp : SPIP; x0, y0, x1, y1 : integer );

begin
 spidp^.x[0] := x0;       { M‚morise les coordonn‚es dans la structure }
 spidp^.x[1] := x1;
 spidp^.y[0] := y0;
 spidp^.y[1] := y1;

 GetSpriteBg( spidp, 0 );              { Lit le fond du sprite en page }
 GetSpriteBg( spidp, 1 );                                     { 0 et 1 }
 PrintSprite( spidp, 0 );                { Dessine le sprite en page 0 }
 PrintSprite( spidp, 1 );                                       { et 1 }
end;

{***********************************************************************
*  RemoveSprite : Retire un sprite de l'emplacement qu'il occupe       *
*                le rendant ainsi invisible                            *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*  Info    : A l'issue de cette fonction il faut appeler la fonction   *
*            SetSprite() avant de d‚placer le sprite par MoveSprite()  *
***********************************************************************}

procedure RemoveSprite( spidp : SPIP );

begin
 RestoreSpriteBg( spidp, 0 );             { R‚tablit le fond du sprite }
 RestoreSpriteBg( spidp, 1 );                         { en pages 0 et 1}
end;

{***********************************************************************
*  Demo : D‚montre l'usage des diff‚rentes fonctions de ce module      *
***********************************************************************}

procedure Demo;

const VaisseauMontant :array [1..20] of string[32] =
                ( '               AA               ',
                  '              AAAA              ',
                  '              AAAA              ',
                  '               AA               ',
                  '             GGBBGG             ',
                  '            GBBCCBBG            ',
                  '           GBBBCCBBBG           ',
                  '          GBBBBBBBBBBG          ',
                  '          GBBBBBBBBBBG          ',
                  ' G       GBBBBBBBBBBBBG       G ',
                  'GCG     GGDBBBBBBBBBBDGG     GCG',
                  'GCG   GGBBBDBBB  BBBDBBBGG   GCG',
                  'GCBGGGBBBBBDBB    BBDBBBBBGGGBCG',
                  'GCBBBBBBBBBBDB    BDBBBBBBBBBBCG',
                  'BBBBBBBBBBBBDB BB BDBBBBBBBBBBBB',
                  'GGCBBBBBBBDBBBBBBBBBBDBBBBBBBCG ',
                  '  GGCCBBBDDDDDDDDDDDDDDBBBCCG   ',
                  '    GGBBDDDDDGGGGGDDDDDDBBG     ',
                  '      GDDDDGGG    GGGDDDDG      ',
                  '       DDDD          DDDD       '  );

const VaisseauDescendant :array [1..20] of string[32] =
                ( '       DDDD          DDDD       ',
                  '      GDDDDGGG    GGGDDDDG      ',
                  '    GGBBDDDDDGGGGGDDDDDDBBG     ',
                  '  GGCCBBBDDDDDDDDDDDDDDBBBCCG   ',
                  'GGCBBBBBBBDBBBBBBBBBBDBBBBBBBCG ',
                  'BBBBBBBBBBBBDB BB BDBBBBBBBBBBBB',
                  'GCBBBBBBBBBBDB    BDBBBBBBBBBBCG',
                  'GCBGGGBBBBBDBB    BBDBBBBBGGGBCG',
                  'GCG   GGBBBDBBB  BBBDBBBGG   GCG',
                  'GCG     GGDBBBBBBBBBBDGG     GCG',
                  ' G       GBBBBBBBBBBBBG       G ',
                  '          GBBBBBBBBBBG          ',
                  '          GBBBBBBBBBBG          ',
                  '           GBBBCCBBBG           ',
                  '            GBBCCBBG            ',
                  '             GGBBGG             ',
                  '               AA               ',
                  '              AAAA              ',
                  '              AAAA              ',
                  '               AA               ' );

  NBSPR = 6;                                       { Nombre de sprites }
  LARGEUR = 37;      { Largeur de la notice de copyright en caractŠres }
  HAUTEUR  = 6;                        { Hauter en lignes de la notice }
  SX     = (MAXX-(LARGEUR*8)) div 2;                  { Coordonn‚es de }
  SY     = (MAXY-(HAUTEUR*8)) div 2;                          { d‚part }

type SPRITE = record                          { Pour g‚rer les sprites }
                spidp : SPIP;            { Pointeur sur identificateur }
                deltax,     { D‚placement horizontal pour pages 0 et 1 }
                deltay : array [0..1] of integer;{ D‚placement vertical}
              end;

var sprites    : array [1..NBSPR] of SPRITE;
    page,                                  { Page pr‚sentement trait‚e }
    lc,                                            { CaractŠre courant }
    out        : byte;         { M‚morise les indicateurs de collision }
    x, y, i,                                  { Compteurs d'it‚rations }
    dx, dy     : integer;                               { D‚placements }
    Vaisseauupp,
    Vaisseaudnp : SPLP;                     { Pointeur sur les sprites }
    ch         : char;
begin

  Randomize;          { Initialise le g‚n‚rateur de nombres al‚atoires }

                  {-- Remplit de caractŠres les deux premiŠres pages --}

  for page := 0 to 1 do
    begin
      setpage( page );
      lc := 0;
      y := 0;
      while ( y < 200-8 ) do
        begin
          x := 0;
          while ( x < 320-8 ) do
            begin
              PrintChar( chr(lc and 127), x, y, lc mod 255, 0 );
              inc( lc );
              inc( x, 8 );
            end;
          inc( y, 12 );
        end;

      {-- Affiche l'avis de copyright ---------------------------------}

      Line( SX-1, SY-1, SX+LARGEUR*8, SY-1, 15 );
      Line( SX+LARGEUR*8, SY-1, SX+LARGEUR*8, SY+HAUTEUR*8,15 );
      Line( SX+LARGEUR*8, SY+HAUTEUR*8, SX-1, SY+HAUTEUR*8, 15 );
      Line( SX-1, SY+HAUTEUR*8, SX-1, SY-1, 15 );
      GrafPrint( SX, SY,    15, 4,
                   '                                     '  );
      GrafPrint( SX, SY+8,  15, 4,
                   ' S3220P.PAS - (c) 1990 by M. TISCHER ' );
      GrafPrint( SX, SY+16, 15, 4,
                   '                                     '  );
      GrafPrint( SX, SY+24, 15, 4,
                   ' D‚monstration de sprite dans le     '  );
      GrafPrint( SX, SY+32, 15, 4,
                   ' mode 320*200 de la carte VGA        '  );
      GrafPrint( SX, SY+40, 15, 4,
                   '                                     '  );
    end;

        {-- Construit les motifs binaires des sprites -----------------}

  Vaisseauupp := CompileSprite( VaisseauMontant,   20, 2, 0, 'A', 1 );
  Vaisseaudnp := CompileSprite( VaisseauDescendant, 20, 2, 40, 'A', 1 );

    {-- Fabrique les diff‚rents sprites -------------------------------}

  for i := 1 to NBSPR do
    begin
      sprites[ i ].spidp := CreateSprite( Vaisseauupp, 3, (i mod 3)*100,
                                         (i div 3) * 30 );
    repeat                              { S‚lectionne les d‚placements }
      dx := 0;
      dy := random(8) - 4;
    until ( dx <> 0 ) or ( dy <> 0 );

    sprites[ i ].deltax[0] := dx * 2;
    sprites[ i ].deltay[0] := dy * 2;
    sprites[ i ].deltax[1] := dx * 2;
    sprites[ i ].deltay[1] := dy * 2;

    x := ( (320 div NBSPR) * (i-1) ) + ((320 div NBSPR) - 40) div 2 ;
    y := random( 200 - 40 );
    SetSprite( sprites[ i ].spidp, x, y, x - dx, y - dy );
  end;

{ D‚place les sprites et les fait rebondir aux extr‚mit‚s de l'‚cran }

  page := 1;                                      { Commence en page 1 }
  while ( not keypressed ) do{Une frappe de touche interrompt la boucle}
    begin
      showpage( 1 - page );                     { Affiche l'autre page }

      for i := 1 to NBSPR do                    { Parcourt les sprites }
        begin            { D‚place les sprites et teste les collisions }
          out := MoveSprite( sprites[i].spidp, page,
                             sprites[i].deltax[page],
                             sprites[i].deltay[page] );
          if ( ( out and OUT_TOP ) <> 0 ) or { Contact en haut/en bas ?}
             ( ( out and OUT_BOTTOM ) <> 0 ) then
            begin
                       {-- Oui change la direction du d‚placement et --}
                       {-- l'image                                   --}
              sprites[i].deltay[page] := -sprites[i].deltay[page];
              if ( ( out and OUT_TOP ) <> 0 ) then
                sprites[i].spidp^.splookp := Vaisseaudnp
              else
                sprites[i].spidp^.splookp := Vaisseauupp;
            end;
          if ( ( out and OUT_LEFT ) <> 0 ) or{ Contact droite/gauche ? }
             ( ( out and OUT_RIGHT ) <> 0 ) then
            sprites[i].deltax[page] := -sprites[i].deltax[page];
        end;
      page := (page+1) and 1;           { Passe de 1 … 0 et vice-versa }
    end;
  ch := readkey;               { Retire la touche du buffer du clavier }
end;

{----------------------------------------------------------------------}
{-- PROGRAMME PRINCIPAL                                            ----}
{----------------------------------------------------------------------}

begin
 if ( IsVga ) then                            { A-t-on une carte VGA ? }
   begin                                                { Oui, on y va }
     init320200;                        { Initialise le mode graphique }
     Demo;
     Textmode( CO80 );                         { Revient au mode texte }
   end
 else
   writeln( 'S3220P.PAS  -  (c) 1990 by MICHAEL TISCHER'#13#10#10 +
            'Attention ! Ce programme exige une carte VGA ! ' +
            ''#13#10 );

end.
