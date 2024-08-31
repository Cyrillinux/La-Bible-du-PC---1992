{***********************************************************************
*                           V 8 0 6 0 P . P A S                        *
**--------------------------------------------------------------------**
*  Fonction : Montre comment exploiter le mode 800*600 16 couleurs de  *
*             la carte Super VGA.                                      *
*             Ce programme utilise les routines en assembleur du       *
*             module V8060PA.ASM                                       *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le : 14.01.1991                                           *
*  DerniŠre MAJ : 14.01.1991                                           *
***********************************************************************}

program V8060P;

uses dos, crt;

{-- D‚clarations de types ---------------------------------------------}

type BPTR = ^byte;

{-- R‚f‚rences externes aux routines en assembleur --------------------}

{$L v8060pa}                         { IntŠgre le module en assembleur }

function  init800600 : boolean; external;
procedure setpix( x, y : integer; couleur : byte ); external;
function  getpix( x, y: integer ) : byte ; external;

{-- Constantes --------------------------------------------------------}

const MAXX     = 799;                          { Coordonn‚es maximales }
      MAXY     = 599;
      NBLINE  = 2500;                              { Nombre de lignes  }
      XDISTANCE = 40;         { Distance entre le rectangle et le bord }
      YDISTANCE = 30;
      X1       = ( 2 * XDISTANCE );         { Coordonn‚es du rectangle }
      Y1       = ( 2 * YDISTANCE );
      X2       = ( MAXX-XDISTANCE );
      Y2       = ( MAXY-YDISTANCE );

{***********************************************************************
*  IsVga : Teste la pr‚sence d'une carte VGA.                          *
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
      fptr := ptr( Regs.ES, Regs.BP );           { Compose le pointeur }
    end;

  if ( cf = 255 ) then                       { CaractŠre transparent ? }
    for i := 0 to 7 do { Oui ne dessine que les pixels du premier plan }
      begin
        Masque := fptr^[ord(caractere),i];{Motif binaire pour une ligne}
        for k := 0 to 7 do
          begin
            if ( Masque and 128 <> 0 ) then       { Pixel … dessiner ? }
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
  if ( abs(x2-x1) < abs(y2-y1) ) then  { Parcours : par l'axe X ou Y ? }
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
*  GrafPrint: Affiche une chaŒne format‚e sur l'‚cran graphique        *
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
     printchar( strt[i], x, y, cc, cf );     { Affiche par printchar   }
     inc( x, 8 );              { x … la position du caractŠre suivant  }
   end;
end;

{***********************************************************************
*  DrawAxis: Dessine des axes en haut et … gauche de l'‚cran           *
**--------------------------------------------------------------------**
*  Entr‚es : XSTEP = Pas selon l'axe X                                 *
*            YSTEP = Pas selon l'axe Y                                 *
*            CC    = Couleur des caractŠres                            *
*            CF    = Couleur de fond (255 = transparent)               *
***********************************************************************}

procedure DrawAxis( stepx, stepy : integer; cc, cf : byte );

var x, y     : integer;                        { Variables d'it‚ration }
    grad : string[3];

begin
 Line( 0, 0, MAXX, 0, cc );                           { Trace l'axe X  }
 Line( 0, 0, 0, MAXY, cc );                           { Trace l'axe Y  }

 x := stepx;                                       { Gradue l'axe X    }
 while ( x < MAXX ) do
   begin
     Line( x, 0, x, 5, cc );
     str( x, grad );
     if ( x < 100 ) then
       GrafPrint( x - 8 , 8, cc, cf, grad )
     else
       GrafPrint( x - 12, 8, cc, cf, grad );
     inc( x, stepx );
  end;

 y := stepy;                                       { Gradue l'axe Y    }
 while ( y < MAXY ) do
   begin
     Line( 0, y, 5, y, cc );
     str( y:3, grad );
     GrafPrint( 8, y-4, cc, cf, grad );
     inc( y, stepy );
  end;
end;


{***********************************************************************
*  Demo : D‚montre l'usage des diff‚rentes fonctions de ce module      *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************}

procedure Demo;

var i : integer;                               { Compteur d'it‚rations }

begin
  Randomize;          { Initialise le g‚n‚rateur de nombres al‚atoires }
  DrawAxis( 30, 20, 15, 255 );                        { Trace des axes }
  GrafPrint( X1, MAXY-10, 15, 255,
             'V8060P.PAS  -  (c) by MICHAEL TISCHER' );

  Line( X1, Y1, X1, Y2, 15 );                   { Dessine le rectangle }
  Line( X1, Y2, X2, Y2, 15 );
  Line( X2, Y2, X2, Y1, 15 );
  Line( X2, Y1, X1, Y1, 15 );

    {-- TRace des segments al‚atoires … l'int‚rieur du rectangle ------}

  for i := 1 to NBLINE do
   Line( random( X2 - X1 - 1 ) + X1 + 1,
         random( Y2 - Y1 - 1 ) + Y1 + 1,
         random( X2 - X1 - 1 ) + X1 + 1,
         random( Y2 - Y1 - 1 ) + Y1 + 1,
         i mod 16 );
end;

{----------------------------------------------------------------------}
{--                       PROGRAMME PRINCIPAL                      ----}
{----------------------------------------------------------------------}

begin
  writeln( 'V8060P.PAS  - (c) 1991 by MICHAEL TISCHER'#13#10 );
  if IsVga then                       { Dispose-t-on d'une carte VGA ? }
    begin                    { Oui mais permet-elle le mode 800*600  ? }
      if init800600 then
    begin                                                    { Mode ok }
      Demo;                                         { Effectue la d‚mo }
      repeat until keypressed;           { Attend une frappe de touche }
      Textmode( CO80 );                        { Revient en mode texte }
        end
      else
    writeln( 'Attention! Le mode 800*600 '+
                                  'n''a pas pu ˆtre initialis‚');
    end
  else
   writeln( 'Attention! Ce programme exige une carte VGA');
end.
