{***********************************************************************
*                          V 3 2 4 0 P . P A S                         *
**--------------------------------------------------------------------**
*  Fonction         : Montre comment programmer la carte VGA dans le   *
*                     mode graphique 320*400 en 256 couleurs avec deux *
*                     pages d'�cran. Le programme utilise les routines *
*                     en assembleur du module V3240PA.ASM              *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D�velopp� le     : 08.09.1990                                       *
*  Derni�re MAJ     : 14.01.1991                                       *
***********************************************************************}

program V3240P;

uses dos, crt;

{-- D�clarations de types ---------------------------------------------}

type BPTR = ^byte;

{-- R�f�rences externes aux routines en assembleur --------------------}

{$L v3240pa}         { Int�gre le module en assembleur }

procedure init320400; external;
procedure setpix( x, y : integer; couleur : byte ); external;
function  getpix( x, y: integer ) : byte ; external;
procedure setpage( page : byte ); external;
procedure showpage( page : byte ); external;

{-- Constantes --------------------------------------------------------}

const MAXX = 319;                              { Coordonn�es maximales }
      MAXY = 399;

{***********************************************************************
*  IsVga : Teste la pr�sence d'une carte VGA.                          *
**--------------------------------------------------------------------**
*  Entr�e  : n�ant                                                     *
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
*  PrintChar : Affiche un caract�re en mode graphique                  *
**--------------------------------------------------------------------**
*  Entr�e : caractere = le caract�re � afficher                        *
*           x, y      = Coordonn�es du coin sup gauche                 *
*           cc        = Couleur du caract�re                           *
*           cf        = Couleur du fond                                *
*  Info   : Le caract�re est dessin� dans une matrice de 8*8 pixels    *
*           sur la base du jeu de caract�res 8*8 en ROM                *
***********************************************************************}

procedure PrintChar( caractere : char; x, y : integer; cc, cf : byte );

type CARADEF = array[0..255,0..7] of byte; {Structure jeu de caract�res}
     CARAPTR = ^CARADEF;             { Pointe sur le jeu de caract�res }

var  Regs  : Registers;       { Registres pour g�rer les interruptions }
     ch    : char;                                { Pixel du caract�re }
     i, k,                                     { Compteur d'it�rations }
     Masque : byte;         { Masque binaire pour dessiner le caract�re}

const fptr : CARAPTR = NIL;   { Pointe sur le jeu de caract�res en ROM }

begin
  if fptr = NIL then             { A-t-on d�j� d�termin� ce pointeur ? }
    begin                                                         { Non}
      Regs.AH := $11;                   { Appelle l'option $1130 de la }
      Regs.AL := $30;                         { fonction vid�o du BIOS }
      Regs.BH := 3;          { pour obtenir un pointeur sur le jeu 8*8 }
      intr( $10, Regs );
      fptr := ptr( Regs.ES, Regs.BP );            { Compose le pointeur}
    end;

  if ( cf = 255 ) then                       { Caract�re transparent ? }
    for i := 0 to 7 do  { Oui ne dessine que les pixels du premier plan}
      begin
        Masque := fptr^[ord(caractere),i];{Motif binaire pour une ligne}
        for k := 0 to 7 do
          begin
            if ( Masque and 128 <> 0 ) then        { Pixel � dessiner? }
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
*  Line : Trace un segment dans la fen�tre graphique en appliquant     *
*         l'algorithme de Bresenham                                    *
**--------------------------------------------------------------------**
*  Entr�e : X1, Y1  = Coordonn�es de l'origine (0 - ...)               *
*           X2, Y2  = Coordonn�es de l'extr�mit� terminale             *
*           COULEUR = couleur du segment                               *
***********************************************************************}

procedure Line( x1, y1, x2, y2 : integer; couleur : byte );

var d, dx, dy,
    aincr, bincr,
    xincr, yincr,
    x, y                 : integer;

{-- Proc�dure accessoire pour �changer deux variables enti�res --------}

procedure SwapInt( var i1, i2: integer );

var dummy : integer;

begin
  dummy := i2;
  i2    := i1;
  i1    := dummy;
end;

{-- Proc�dure principale --------------------------------------------}

begin
  if ( abs(x2-x1) < abs(y2-y1) ) then    { Parcours : axe des X ou Y ? }
    begin                                            { par l'axe des Y }
      if ( y1 > y2 ) then                         { y1 sup�rieur � y2? }
        begin
      SwapInt( x1, x2 );                      { Oui, �change X1 et X2, }
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
      if ( x1 > x2 ) then                      { x1 plus grand que x2? }
        begin
      SwapInt( x1, x2 );                       { Oui, �change X1 et X2 }
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
*  GrafPrint: Affiche une cha�ne format�e sur l'�cran graphique        *
**--------------------------------------------------------------------**
*  Entr�es : X, Y   = Coordonn�es de d�part (0-...)                    *
*            CC     = Couleur des caract�res                           *
*            CF     = Couleur du fond    (255 = transparent)           *
*            STRING = Cha�ne avec indications de formatage             *
***********************************************************************}

procedure GrafPrint( x, y : integer; cc, cf : byte; strt : string );

var i : integer;                               { Compteur d'it�rations }

begin
 for i:=1 to length( strt ) do
   begin
     printchar( strt[i], x, y, cc, cf );       { Affiche par printchar }
     inc( x, 8 );               { x � la position du caract�re suivant }
   end;
end;

{***********************************************************************
*  ColorBox : Dessine un rectangle et le remplit avec un motif compos� *
*             de lignes.                                               *
**--------------------------------------------------------------------**
*  Entr�es  : X1, Y1 = Coordonn�es du coin sup gauche de la fen�tre    *
*             X2, Y2 = Coordonn�es du coin inf droit de la fen�tre     *
*             COULMAX= Code de couleur maximal                         *
*  Info     : Les couleurs des lignes sont r�p�t�es dans un cycle de 0 *
*             � COULMAX                                                *
***********************************************************************}

procedure ColorBox( x1, y1, x2, y2 : integer; coulmax : byte );

var x, y,                                      { Compteur d'it�rations }
    sx, sy : integer;          { Point de d�part de la derni�re boucle }

begin
 Line( x1, y1, x1, y2, 15 );                { Cadre autour du rectangle}
 Line( x1, y2, x2, y2, 15 );
 Line( x2, y2, x2, y1, 15 );
 Line( x2, y1, x1, y1, 15 );

 for y := y2-1 downto y1+1 do       { Du coin inf gauche au bord droit }
   Line( x1+1, y2-1, x2-1, y, y mod coulmax );

 for y := y2-1 downto y1+1 do       { Du coin inf droit au bord gauche }
  Line( x2-1, y2-1, x1+1, y, y mod coulmax );

 {-- Du milieu du rectangle au bord sup�rieur -------------------------}

 sx := x1+ (x2-x1) div 2;
 sy := y1+ (y2-y1) div 2;
 for x := x1+1 to x2-1 do
  Line( sx, sy, x, y1+1, x mod coulmax );
end;

{***********************************************************************
*  DrawAxis: Dessine des axes en haut et � gauche de l'�cran           *
**--------------------------------------------------------------------**
*  Entr�es : XSTEP = Pas selon l'axe X                                 *
*            YSTEP = Pas selon l'axe Y                                 *
*            CC    = Couleur des caract�res                            *
*            CF    = Couleur de fond (255 = transparent)               *
***********************************************************************}

procedure DrawAxis( stepx, stepy : integer; cc, cf : byte );

var x, y     : integer;                        { Variables d'it�ration }
    grad : string[3];

begin
 Line( 0, 0, MAXX, 0, cc );                            { Trace l'axe X }
 Line( 0, 0, 0, MAXY, cc );                            { Trace l'axe Y }

 x := stepx;                                          { Gradue l'axe X }
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

 y := stepy;                                          { Gradue l'axe Y }
 while ( y < MAXY ) do
   begin
     Line( 0, y, 5, y, cc );
     str( y:3, grad );
     GrafPrint( 8, y-4, cc, cf, grad );
     inc( y, stepy );
  end;
end;


{***********************************************************************
*  Demo : D�montre l'usage des diff�rentes fonxtions de ce module      *
**--------------------------------------------------------------------**
*  Entr�es : n�ant                                                     *
***********************************************************************}

procedure Demo;

const PAUSE = 100;                         { Compteur de millisecondes }

var page : byte;                                   { Compteur de pages }

begin
 ColorBox( 80, 50, 308, 350, 16 );       { Dessine un rectangle color� }
 DrawAxis( 30, 40, 15, 255 );                         { Trace des axes }
 GrafPrint( 46, MAXY-10, 15, 255, 'V3240P  -  (c) by MICHAEL TISCHER');

 setpage( 1 );                                       { Passe en page 1 }
 ColorBox( 80, 50, 308, 350, 255 );      { Dessine un rectangle color� }
 DrawAxis( 30, 40, 15, 255 );                         { Trace des axes }
 GrafPrint( 46, MAXY-10, 15, 255, 'V3240P  -  (c) by MICHAEL TISCHER');

{-- Affiche alternativement les deux pages graphiques------------------}

 for page := 0 to 50 do                                  { 50 passages }
   begin
     showpage( page mod 2 );                        { Affiche une page }
     delay( PAUSE );                                     { Petite pause}
   end;

end;

{----------------------------------------------------------------------}
{--                       PROGRAMME PRINCIPAL                        --}
{----------------------------------------------------------------------}

begin
 if IsVga then                                 { A-t-on une carte VGA? }
   begin                                            { Oui, c'est parti }
     init320400;                        { Initialise le mode graphique }
     Demo;
     repeat until keypressed;
     Textmode( CO80 );                        { Retourne au mode texte }
   end
 else
   writeln( 'V3240P  -  (c) 1990 by MICHAEL TISCHER'#13#10#10 +
            'Attention: ce programme exige une carte VGA' +
            ''#13#10 );
end.
