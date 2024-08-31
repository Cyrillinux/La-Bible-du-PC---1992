{***********************************************************************
*                           S 3 2 4 0 P . P A S                        *
**--------------------------------------------------------------------**
*  Fonction : Monte comment travailler avec des sprites dans le mode   *
*             graphique VGA 320*200 avec 256 couleurs et deux pages    *
*             d'‚cran. Ce programme utilise les routines en assembleur *
*             des modules V3240PA.ASM et S3240PA.ASM                   *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le : 12.09.1990                                           *
*  DerniŠre MAJ : 14.01.1991                                           *
***********************************************************************}

program S3240P;

uses dos, crt;

{-- R‚f‚rences externes aux routines en assembleur -------------------}

{$L v3240pa}   { IntŠgre le module en assembleur }

procedure init320400; external;
procedure setpix( x, y : integer; couleur : byte ); external;
function  getpix( x, y: integer ) : byte ; external;
procedure setpage( page : byte ); external;
procedure showpage( page : byte ); external;

{$L s3240pa}   { IntŠgre le module en assembleur }

procedure CopyPlane2Buf( bufptr : pointer;
                         page   : byte;
                         dex,
                         dey   : integer;
                         largeur,
                         hauteur  : byte    ); external;

procedure CopyBuf2Plane( bufptr : pointer;
                         page   : byte;
                         ax,
                         ay  : integer;
                         largeur,
                         hauteur  : byte;
                         bg     : boolean ); external;

{-- Constantes --------------------------------------------------------}

const MAXX = 319;                              { Coordonn‚es maximales }
      MAXY = 399;

      OUT_LEFT   = 1;     { Indicateurs de collision dans SpriteMove() }
      OUT_TOP    = 2;
      OUT_RIGHT  = 4;
      OUT_BOTTOM = 8;
      OUT_NO     = 0;                               { Pas de collision }

{-- D‚clarations de types ---------------------------------------------}

type PIXBUF = record          { Informations pour GetVideo et PutVideo }
        bitptr : array[0..3] of pointer;         {Ptr sur plans de bits}
        oparl  : array[0..3] of byte;           { Nb d'octets … copier }
        hauteur: byte;                              { Nombre de lignes }
                                {-- Ici les octets des plans de bits --}
              end;
     PIXPTR = ^PIXBUF;              { Pointeur sur un buffer de pixels }

     SPLOOK = record                               { Image d'un sprite }
        largeur,                                      { Largeur totale }
        hauteur  : byte;                 { Hauteur en lignes de pixels }
        pixbp  : PIXPTR;                 { Pointeur sur bloc de pixels }
          end;
     SPLP = ^SPLOOK;                          { Pointeur sur une image }

     SPID = record                        { Descripteur de sprite (ID) }
          splookp : SPLP;                       { Pointeur sur l'image }
          x, y    : array [0..1] of integer;      { Coord pages 0 et 1 }
          fondptr   : array [0..1] of PIXPTR;      { Ptr sur le buffer }
        end;                                                 { du fond }
     SPIP = ^SPID;             { Pointeur sur le descripteur du sprite }

     PTRREC = record   { Pour d‚composer un pointeur ou un entier long }
                ofs,
                seg : word;
              end;

     BYTEAR = array[0..10000] of byte;  { Pour adresser les diff‚rents }
     BARPTR = ^BYTEAR;                                     { buffers   }

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
*  Info  : Le caractŠre est dessin‚ dans une matrice de 8*8 pixels     *
*          sur la base du jeu de caractŠres 8*8 en ROM                 *
***********************************************************************}

procedure PrintChar( caractere : char; x, y : integer; cc, cf : byte );

type CARADEF = array[0..255,0..7] of byte;{ Structure jeu de caractŠres}
     CARAPTR = ^CARADEF;             { Pointe sur le jeu de caractŠres }

var  Regs  : Registers;       { Registres pour g‚rer les interruptions }
     ch    : char;                                { Pixel du caractŠre }
     i, k,                                     { Compteur d'it‚rations }
     Masque : byte;        { Masque binaire pour dessiner le caractŠre }

const fptr : CARAPTR = NIL;   { Pointe sur le jeu de caractŠres en ROM }

begin
  if fptr = NIL then             { A-t-on d‚j… d‚termin‚ ce pointeur ? }
    begin                                                         { Non}
      Regs.AH := $11;                 { Appelle l'option $1130 de la   }
      Regs.AL := $30;                 { fonction vid‚o du BIOS         }
      Regs.BH := 3;      { pour obtenir un pointeur sur le jeu 8*8     }
      intr( $10, Regs );
      fptr := ptr( Regs.ES, Regs.BP );           { Compose le pointeur }
    end;

  if ( cf = 255 ) then                       { CaractŠre transparent ? }
    for i := 0 to 7 do { Oui ne dessine que les pixels du premier plan }
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
              setpix( x+k, y+i, cf );                      { Non, fond }
            Masque := Masque shl 1;
         end;
      end;
end;

{***********************************************************************
*  Line : Trace un segment dans la fenˆtre graphique en appliquant     *
*        l'algorithme de Bresenham                                     *
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
  if ( abs(x2-x1) < abs(y2-y1) ) then    { Parcours : par axe X ou Y ? }
    begin                                            { par l'axe des Y }
      if ( y1 > y2 ) then                         { y1 sup‚rieur … y2? }
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
      if ( x1 > x2 ) then                      { x1 plus grand que x2? }
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
*  GetVideo : Charge le contenu d'une zone rectangulaire de la m‚moire *
*             d'‚cran dans un buffer                                   *
**--------------------------------------------------------------------**
*  Entr‚es : PAGE     = Page d'‚cran  (0 ou  1)                        *
*            X1, Y1   = Coordonn‚es de d‚part                          *
*            LARGEUR  = Largeur de la zone rectangulaire en pixels     *
*            HAUTEUR  = Hauteur de la zone rectangulaire en pixels     *
*            BUFPTR   = Pointeur sur un buffer de pixels qui va        *
*                       m‚moriser les informations                     *
*  Sortie  : Pointeur sur le buffer de pixels qui contient la zone     *
*            indiqu‚e                                                  *
*  Info    : Si on donne au paramŠtre BUFPTR la valeur NIL , un        *
*            nouveau buffer de pixels est allou‚ sur le tas et retourn‚*
*            Ce buffer peut ˆtre transmis lors d'un nouvel appel si    *
*            l'ancien contenu est effa‡able et si la taille de la zone *
*            n'a pas chang‚                                            *
***********************************************************************}

function GetVideo( page : byte; x1, y1 : integer;
                   largeur, hauteur : byte; bufptr : PIXPTR ) : PIXPTR;

var i,                                         { Compteur d'it‚rations }
    plancour,                                   { Plan de bits courant }
    sb,                        { Plan de bits des coordonn‚es de d‚but }
    eb,                          { Plan de bits des coordonn‚es de fin }
    b,                          { Nombre d'octets dans un plan de bits }
    am  : byte;  { Nombre d'octet au milieu des deux groupes de quatre }
    rptr : pointer;                    { Pointeur courant sur l'offset }

begin
  if ( bufptr = NIL ) then                   { Pas de buffer transmis ?}
    getmem( bufptr, sizeof(PIXBUF) + largeur*hauteur);{ Non, on alloue }

   {-- Calcule le nombre d'octets par plan de bits --------------------}

  am := ( ( (x1+largeur-1) and not(3) ) -  {Nombre d'octets au milieu  }
        ( (x1+4) and not(3) ) ) div 4;
  sb := x1 mod 4;                               { Plan de bit de d‚but }
  eb := (x1+largeur-1) mod 4;                     { Plan de bit de fin }

  rptr := ptr( seg(bufptr^), ofs(bufptr^) + sizeof( PIXBUF ));

  {-- Parcourt les quatre plans de bits -------------------------------}

  for i:=0 to 3 do
    begin
      plancour := (sb+i) mod 4;
      b := am;                  { Nombre de base des octets … copier   }
      if ( plancour >= sb ) then
                        { ‚galement dans le bloc des quatre du d‚but ? }
    inc( b );                 { Oui, ajoute un octet dans ce plan      }
      if ( plancour <= eb ) then
                       { ‚galement dans le bloc des quatre de la fin ? }
    inc( b );                      { Oui, ajoute un octet dans ce plan }
      bufptr^.bitptr[i] := rptr;
                    { M‚morise dans le buffer un pointeur sur le d‚but }
      bufptr^.oparl[i] := b;             { M‚morise le nombre d'octets }
      CopyPlane2Buf( rptr, page, x1+i,               { Lit le contenu  }
             y1, b, hauteur );                             { des plans }
      inc( PTRREC(rptr).ofs, b * hauteur );  { Positionne le pointeur  }
                                  { sur le plan suivant dans le buffer }
    end;
  bufptr^.hauteur := hauteur;                    { m‚morise la hauteur }

  GetVideo := bufptr; { Renvoie … l'appelant le pointeur sur le buffer }
end;

{***********************************************************************
*  PutVideo : R‚‚crit dans la m‚moire d'‚cran le contenu d'une zone    *
*             d'‚cran rectangulaire pr‚alablement sauvegard‚e par      *
*             GetVideo                                                 *
**--------------------------------------------------------------------**
*  Entr‚e : BUFPTR = Pointeur renvoy‚ par GetVideo et r‚f‚ren‡ant un   *
*                    buffer de pixels                                  *
*           PAGE   = Page d'‚cran (0 ou 1)                             *
*           X1, Y1 = Coordonn‚es de d‚but                              *
*           BG     = Indique si les pixels du fond (code couleur 255)  *
*                     doivent ˆtre ‚crits dans la m‚moire d'‚cran      *
*  Info   : Le buffer de pixels n'est pas effac‚ par cette proc‚dure   *
*           cette tƒche ‚tant remplie par FreeBixBuf()                 *
***********************************************************************}

procedure PutVideo( bufptr : PIXPTR; page : byte; x1, y1 : integer;
                    bg     : boolean );

var plancour,                                   { Plan de bits courant }
    hauteur : byte;

begin
  hauteur := bufptr^.hauteur;                     { Hauteur de la zone }
  for plancour:=0 to 3 do          { Parcourt les quatre plans de bits }
    CopyBuf2Plane( bufptr^.bitptr[plancour], page, x1+plancour,
                   y1, bufptr^.oparl[plancour], hauteur, bg );
end;

{***********************************************************************
*  FreePixBuf : Efface un buffer de pixels allou‚ sur le tas par       *
*              GetVideo                                                *
**--------------------------------------------------------------------**
*  Entr‚e : BUFPTR  = Pointeur renvoy‚ par Getvideo et r‚f‚ren‡ant     *
*                     un buffer de pixels                              *
*           LARGEUR = Largeur de la zone rectangulaire en pixels       *
*           HAUTEUR = Hauteur de la zone rctangulaire en pixels        *
***********************************************************************}

procedure FreePixBuf( bufptr : PIXPTR; largeur, hauteur : byte );

begin
  freemem( bufptr, sizeof( PIXBUF ) + largeur*hauteur );
end;

{***********************************************************************
*  CreateSprite : Cr‚e un sprite … l'aide d'un motif de pixels         *
*                 pr‚alablement compil‚                                *
**--------------------------------------------------------------------**
*  Entr‚e  : SPLOOKP = Pointeur sur la structure de donn‚es produite   *
*                      par CompileSprite()                             *
*  Sortie  : Pointeur sur la structure du sprite cr‚‚e                 *
***********************************************************************}

function CreateSprite( splookp : SPLP ) : SPIP;

var spidp : SPIP;                { Pointe sur la structure du sprite   }

begin
  new( spidp );           { Alloue de la m‚moire pour la structure     }
  spidp^.splookp := splookp;

 {-- Cr‚e deux buffers de fond dans lesquels GetVideo va sauvegarder   }
                                   {-- des zones de la m‚moire d'‚cran }

  spidp^.fondptr[0] := GetVideo( 0, 0, 0, splookp^.largeur,
                               splookp^.hauteur, NIL );
  spidp^.fondptr[1] := GetVideo( 0, 0, 0, splookp^.largeur,
                               splookp^.hauteur, NIL );
  CreateSprite := spidp;   { Renvoie un ptr sur la structure du sprite }
end;

{***********************************************************************
*  CompileSprite : Cr‚e le motif binaire d'un sprite … l'aide d'une    *
*                 d‚finition connue au moment de l'ex‚cution           *
**--------------------------------------------------------------------**
*  Entr‚e  : BUFP      = Pointeur sur un tableau de pointeurs          *
*                        r‚f‚ren‡ant des chaŒnes de caractŠres qui     *
*                        repr‚sente le motif du sprite                 *
*            HAUTEUR   = Hauteur du sprite et nombre de chaŒnes de     *
*                        caractŠres                                    *
*            PAGE      = Page graphique pour construire le sprite      *
*            CLR       = CaractŠre ASCII associ‚ … la plus petite coul.*
*            COULEURPP = Premier code de couleur pour CLR              *
*  Info    : Les sprites sont dessin‚s … partir du bord gauche de la   *
*            ligne indiqu‚e                                            *
***********************************************************************}

function CompileSprite( var buf; hauteur, page : byte;
            clr: char; couleurpp : byte ) : SPLP;

type BYPTR  = ^byte;                           { Pointeur sur un octet }

var  largeur,                { Longueur des chaŒnes = largeur du motif }
     c,                                        { M‚morise un caractŠre }
     couleur,                                     { Couleur d'un pixel }
     i, k, l  : byte;                          { Variables d'it‚ration }
     splookp  : SPLP;{ Ptr sur la structure de l'image du sprite cr‚‚e }
     bptr     : barptr; {Sert … adresser le buffer de l'image du sprite}
     pbptr    : PIXPTR;                   { M‚morise le fond du sprite }

begin
  {-- Cr‚e la structure de l'image du sprite et la remplit ------------}

  new( splookp );
  bptr := @buf;                         { Pointe sur le buffer du logo }
  largeur := bptr^[0]; { Lit la longueur des chaŒnes = largeur du logo }
  splookp^.largeur := largeur;
  splookp^.hauteur  := hauteur;

      {-- Construit le sprite dans la page indiqu‚e … partir de (0,0)--}

  setpage( page );                          { Fixe la page de dessin   }
  pbptr := GetVideo( page, 0, 0, largeur, hauteur, nil );{ Lit le fond }

  for i := 0 to hauteur-1 do                     { Parcourt les lignes }
    for k := 0 to largeur-1 do                 { Parcourt les colonnes }
      begin
    c := bptr^[i*(largeur+1)+k+1];                       { Lit un pixel}
    if ( c = 32 ) then                                        { Fond ? }
      setpix( k, i, 255 )            { Oui, choisit le code couleur 255}
    else                                  { Non, met la couleur pr‚vue }
          setpix( k, i, couleurpp+(c-ord(clr)) );
      end;

  {-- Lit le sprite dans le buffer et restaure le fond    -------------}

  splookp^.pixbp := GetVideo( page, 0, 0, largeur, hauteur, NIL );
  PutVideo( pbptr, page, 0, 0, false );
  FreePixBuf( pbptr, largeur, hauteur );            { LibŠre le buffer }

  CompileSprite := splookp; { Renvoie une ptr sur le buffer de l'image }
end;

{***********************************************************************
*  PrintSprite : Affiche un sprite dans une page donn‚e                *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE  = Page concern‚e  (0 ou 1)                          *
***********************************************************************}

procedure PrintSprite( spidp : SPIP; page : byte );

begin
  PutVideo( spidp^.splookp^.pixbp,
                page, spidp^.x[page], spidp^.y[page], true );
end;

{***********************************************************************
*  GetSpriteBg : Lit le fond du sprite et le m‚morise … l'emplacement  *
*                pr‚vu                                                 *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
             PAGE  = Page d'o— est tir‚ le fond (0 ou 1)               *
***********************************************************************}

procedure GetSpriteBg( spidp : SPIP; page : BYTE );

var dummy : PIXPTR;

begin
 dummy := GetVideo( page, spidp^.x[page],  spidp^.y[page],
                    spidp^.splookp^.largeur, spidp^.splookp^.hauteur,
                    spidp^.fondptr[page] );
end;

{***********************************************************************
*  RestoreSpriteBg : R‚tablit dans la page d'origine le fond d'un      *
*                    sprite sauvegard‚ au pr‚alable                    *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE  = Page o— doit ˆtre recopi‚ le fond (0 ou 1)        *
***********************************************************************}

procedure RestoreSpriteBg( spidp : SPIP; page : BYTE );

begin
 PutVideo( spidp^.fondptr[page], page,
           spidp^.x[page],  spidp^.y[page], false );
end;

{***********************************************************************
*  MoveSprite : D‚place un sprite dans sa page                         *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP  = Pointeur sur la structure du sprite              *
*            PAGE   = Page o— doit ˆtre recopi‚ le fond (0 ou 1)       *
*            DELTAX = D‚placement dans les directions X etY            *
*            DELTAY                                                    *
*  Sortie  : Indicateur de collision, cf constantes OUT_...            *
***********************************************************************}

function MoveSprite( spidp : SPIP; page : byte;
                     deltax, deltay : integer    ) : byte;

var nouvx, nouvy : integer;          { Nouvelles coordonn‚es du sprite }
    out        : byte; { Indique une collision avec le bord de l'‚cran }

begin
                   {-- D‚cale l'abscisse X et d‚tecte les collisions --}

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

                      {  D‚cale l'ordonn‚e Y et d‚tecte les collisions }

 nouvy := spidp^.y[page] + deltay;
 if ( nouvy < 0 ) then                              { Bord sup‚rieur ? }
   begin                              { Oui , deltay doit ˆtre n‚gatif }
     nouvy := 0 - deltay - spidp^.y[page];
     out := out or OUT_TOP;
   end
 else
   if ( nouvy + spidp^.splookp^.hauteur > MAXY+1  ) then   { Bord inf ?}
     begin                             { Oui, deltay doit ˆtre positif }
       nouvy := (2*(MAXY+1))-nouvy-2*(spidp^.splookp^.hauteur);
       out := out or OUT_BOTTOM;
     end;

{Ne fixe une nouvelle position que si elle est diff‚rente de l'ancienne}

 if ( nouvx <> spidp^.x[page] ) or  ( nouvy <> spidp^.y[page] ) then
   begin                                           { Nouvelle position }
     RestoreSpriteBg( spidp, page );                { Restaure le fond }
     spidp^.x[page] := nouvx;     { M‚morise les nouvelles coordonn‚es }
     spidp^.y[page] := nouvy;
     GetSpriteBg( spidp, page );                 { Lit le nouveau fond }
     PrintSprite( spidp, page );{ Dessine sprite dans la page indiqu‚e }
   end;

 MoveSprite := out;
end;

{***********************************************************************
*  SetSprite : Place le sprite … une position donn‚e                   *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP  = Pointeur sur la structure du sprite              *
*            x0, y0 = Coordonn‚es du sprite en page 0                  *
*            x1, y1 = Coordonn‚es du sprite en page 1                  *
*  Info    : Cette fonction doit ˆtre d‚clench‚e avant le premier      *
*            appel … MoveSprite()                                      *
***********************************************************************}

procedure SetSprite( spidp : SPIP; x0, y0, x1, y1 : integer );

begin
 spidp^.x[0] := x0;       { M‚morise les coordonn‚es dans la structure }
 spidp^.x[1] := x1;
 spidp^.y[0] := y0;
 spidp^.y[1] := y1;

 GetSpriteBg( spidp, 0 );                      { Lit le fond du sprite }
 GetSpriteBg( spidp, 1 );                            { en pages 0 et 1 }
 PrintSprite( spidp, 0 );                           { Dessine le sprite}
 PrintSprite( spidp, 1 );                          { en pages 0 et 1   }
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

  NBSPR = 6;                                      { Nombre de sprites  }
  LARGEUR = 37;          { Nombre de caractŠres de l'avis de copyright }
  HAUTEUR  = 6;                     { Nombre de lignes de ce mˆme avis }
  SX     = (MAXX-(LARGEUR*8)) div 2;            { Abscisse de d‚part X }
  SY     = (MAXY-(HAUTEUR*8)) div 2;            { Ordonn‚e de d‚part Y }

type SPRITE = record                         { Pour g‚rer les sprites  }
                spidp : SPIP;            { Pointe sur l'identificateur }
                deltax,      { D‚placement horizontal pour pages 0 et 1}
                deltay : array [0..1] of integer;{ D‚placement vertical}
              end;

var sprites    : array [1..nbspr] of SPRITE;
    page,                                              { Page courante }
    lc,                                            { CaractŠre courant }
    out        : byte;            { M‚morise l'indicateur de collision }
    x, y, i,                                  { Compteurs d'it‚rations }
    dx, dy     : integer;                               { D‚placements }
    vaisseauupp,
    vaisseaudnp : SPLP;                     { Pointeur sur les sprites }
    ch         : char;
begin

  Randomize;          { Initialise le g‚n‚rateur de nombres al‚atoires }

           {-- Construit les motifs binaires des sprites --------------}

  vaisseauupp := CompileSprite( VaisseauMontant,   20, 0, 'A', 1 );
  vaisseaudnp := CompileSprite( VaisseauDescendant, 20, 0, 'A', 1 );

       {-- Remplit de caractŠres les deux pages graphiques ------------}

  for page := 0 to 1 do
    begin
      setpage( page );
      lc := 0;
      y := 0;
      while ( y < (MAXY+1)-8 ) do
        begin
          x := 0;
          while ( x < (MAXX+1)-8 ) do
            begin
              PrintChar( chr(lc and 127), x, y, lc mod 255, 0 );
              inc( lc );
              inc( x, 8 );
            end;
          inc( y, 12 );
        end;

     {-- Affiche l'avis de copyright ----------------------------------}

      Line( SX-1, SY-1, SX+LARGEUR*8, SY-1, 15 );
      Line( SX+LARGEUR*8, SY-1, SX+LARGEUR*8, SY+HAUTEUR*8,15 );
      Line( SX +LARGEUR*8, SY+HAUTEUR*8, SX-1, SY+HAUTEUR*8, 15 );
      Line( SX-1, SY+HAUTEUR*8, SX-1, SY-1, 15 );
      GrafPrint( SX, SY,    15, 4,
                   '                                     '  );
      GrafPrint( SX, SY+8,  15, 4,
                   ' S3240P.PAS - (c) 1990 by M. TISCHER ' );
      GrafPrint( SX, SY+16, 15, 4,
                   '                                     '  );
      GrafPrint( SX, SY+24, 15, 4,
                   '  D‚monstration de sprites dans le   ' );
      GrafPrint( SX, SY+32, 15, 4,
                   '    mode 320*400 de la carte VGA     '  );
      GrafPrint( SX, SY+40, 15, 4,
                   '                                     '  );
    end;

    {-- Fabrique les diff‚rents sprites -------------------------------}

  for i := 1 to NBSPR do
    begin
      sprites[ i ].spidp := CreateSprite( vaisseauupp );
      repeat                                { Choisir les d‚placements }
        dx := 0;
        dy := random(10) - 5;
      until ( dx <> 0 ) or ( dy <> 0 );

      sprites[ i ].deltax[0] := dx * 2;
      sprites[ i ].deltay[0] := dy * 2;
      sprites[ i ].deltax[1] := dx * 2;
      sprites[ i ].deltay[1] := dy * 2;

      x := ( (320 div NBSPR) * (i-1) ) + ((320 div NBSPR)-40) div 2;
      y := random( 200 - 40 );
      SetSprite( sprites[ i ].spidp, x, y, x - dx, y - dy );
    end;

{-- D‚place les sprites et les fait rebondir aux extr‚mit‚s de l'‚cran }

  page := 1;                                      { Commence en page 1 }
  while ( not keypressed ) do{Une frappe de touche interrompt la boucle}
    begin
      showpage( 1 - page );                     { Affiche l'autre page }

      for i := 1 to nbspr do                    { Parcourt les sprites }
        begin          { Daplace les sprites et d‚tecte les collisions }
          out := MoveSprite( sprites[i].spidp, page,
                             sprites[i].deltax[page],
                             sprites[i].deltay[page] );
          if ( ( out and OUT_TOP ) <> 0 ) or{ Contact en haut/en bas ? }
             ( ( out and OUT_BOTTOM ) <> 0 ) then
            begin
                   {-- Oui, inverse le d‚placement et change l'image --}

              sprites[i].deltay[page] := -sprites[i].deltay[page];
              if ( ( out and OUT_TOP ) <> 0 ) then
                sprites[i].spidp^.splookp := vaisseaudnp
              else
                sprites[i].spidp^.splookp := vaisseauupp;
            end;
          if ( ( out and OUT_LEFT ) <> 0 ) or{Contact … gauche/droite ?}
             ( ( out and OUT_RIGHT ) <> 0 ) then
            sprites[i].deltax[page] := -sprites[i].deltax[page];
        end;
      page := (page+1) and 1;           { Passe de 1 … 0 et vice versa }
    end;

  ch := readkey;                         { Attend une frappe de touche }
end;

{----------------------------------------------------------------------}
{--                         PROGRAMME PRINCIPAL                      --}
{----------------------------------------------------------------------}

begin
 if ( IsVga ) then                      { Dispose-t-on d'une carte VGA }
   begin                                                { Oui, on y va }
     init320400;                        { Initialise le mode graphique }
     Demo;
     Textmode( CO80 );                         { Ratblit le mode texte }
   end
 else
   writeln( 'S3240P.PAS  -  (c) 1990 by MICHAEL TISCHER'#13#10#10 +
            'Attention! Ce programme n‚cessite une carte VGA ');
end.

