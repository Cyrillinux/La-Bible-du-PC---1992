{***********************************************************************
*                          S 6 4 3 5 P . P A S                         *
**--------------------------------------------------------------------**
*  Fonction : Montre comment travailler avec des sprites dans le mode  *
*             graphique 640*350 EGA ou VGA en 16 couleurs sur deux     *
*             pages d'‚cran.                                           *
*             Ce programme utilise les routines en assembleur des      *
*             modules  V16COLPA.ASM et S6435PA.ASM.                    *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le :  5.12.1990                                           *
*  DerniŠre MAJ : 14.01.1991                                           *
***********************************************************************}

program S6435P;

uses dos, crt;

{-- R‚f‚rences externes aux routines en assembleur --------------------}

{$L v16colpa}                        { IntŠgre le module en assembleur }

procedure init640350; external;
procedure setpix( x, y : integer; couleur : byte ); external;
function  getpix( x, y: integer ) : byte ; external;
procedure setpage( page : integer ); external;
procedure showpage( page : integer ); external;

{$L s6435pa}                         { IntŠgre le module en assembleur }

procedure CopyVideo2Buf( bufptr : pointer;
                         page   : byte;
                         dex,
                         dey   : integer;
                         largeur,
                         hauteur  : byte    ); external;

procedure CopyBuf2Video( bufptr : pointer;
                         page   : byte;
                         ax,
                         ay  : integer;
                         largeur,
                         hauteur  : byte ); external;

procedure MergeAndCopyBuf2Video( spribufptr,
                                 hgbufptr,
                                 andbufptr  : pointer;
                                 page       : byte;
                                 ax,
                                 ay      : integer;
                                 largeur,
                                 hauteur      : byte ); external;

{-- Constantes --------------------------------------------------------}

const MAXX = 639;                              { Coordonn‚es maximales }
      MAXY = 349;

      OUT_LEFT   = 1;     { Indicateurs de collision pour SpriteMove() }
      OUT_TOP    = 2;
      OUT_RIGHT  = 4;
      OUT_BOTTOM = 8;
      OUT_NO     = 0;                               { Pas de collision }

{-- D‚clarations de types ---------------------------------------------}

type PIXBUF = record          { Informations pour GetVideo et PutVideo }
        largeurbyte,                    { Largeur de la zone en octets }
        hauteur  : byte;                            { Nombre de lignes }
        pixblen: integer;                 { Taille du buffer de pixels }
        pixbptr: pointer;           { Pointeur sur le buffer de pixels }
              end;
     PIXPTR = ^PIXBUF;              { Pointeur sur un buffer de pixels }

     SPLOOK = record                               { Image d'un sprite }
        largeur,                                      { Largeur totale }
        hauteur  : byte;                           { Hauteur en pixels }
        bmskp  : array [0..7] of pointer;         { Ptr sur buffer AND }
        pixmp  : array [0..7] of PIXPTR;         {Ptr sur d‚fin pixels }
          end;
     SPLP = ^SPLOOK;                            { Pointeur sur l'image }

     SPID = record                        { Descripteur de sprite (ID) }
          splookp : SPLP;                       { Pointeur sur l'image }
          x, y    : array [0..1] of integer;     { Coord. pages 0 et 1 }
          fondptr   : array [0..1] of PIXPTR;    { Pointeur sur buffer }
        end;                                                 { du fond }
     SPIP = ^SPID;                { Pointeur sur descripteur de sprite }

     BYTEAR = array[0..10000] of byte;  { Pour adresser les diff‚rents }
     BARPTR = ^BYTEAR;                                       { buffers }

     CARTE = ( EGA, VGA, NINI );

{***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : EGA, VGA ou NINI                                          *
***********************************************************************}

function IsEgaVga : CARTE;

var Regs : Registers;         { Registres pour g‚rer les interruptions }

begin
  Regs.AX := $1a00;               { La fonction 1AH n'existe qu'en VGA }
  Intr( $10, Regs );
  if ( Regs.AL = $1a ) then        { La fonction est-elle disponible ? }
    IsEgaVga := VGA
  else
    begin
      Regs.ah := $12;                        { Appelle l'option $10 de }
      Regs.bl := $10;                                { la fonction $12 }
      intr($10, Regs);        { D‚clenche l'interruption vid‚o du BIOS }
      if ( Regs.bl <> $10 ) then IsEgaVga := EGA
                            else IsEgaVga := NINI;
    end;
end;

{***********************************************************************
*  PrintChar : Affiche un caractŠre en mode graphique                  *
**--------------------------------------------------------------------**
*  Entr‚e :  caractere = le caractŠre … afficher                       *
*            x, y    = Coordonn‚es du coin sup gauche                  *
*            cc      = Couleur du caractŠre                            *
*            cf      = Couleur du fond                                 *
*  Info   : Le caractŠre est dessin‚ dans une matrice de 8*8 pixels    *
*           sur la base du jeu de caractŠres 8*8 en ROM                *
***********************************************************************}

procedure PrintChar( caractere : char; x, y : integer; cc, cf : byte );

type CARADEF = array[0..255,0..7] of byte;{Structure jeu de caractŠres }
     CARAPTR = ^CARADEF;             { Pointe sur le jeu de caractŠres }

var  Regs  : Registers;       { Registres pour g‚rer les interruptions }
     ch    : char;                                { Pixel du caractŠre }
     i, k,                                     { Compteur d'it‚rations }
     Masque : byte;        { Masque binaire pour dessiner le caractŠre }

const fptr : CARAPTR = NIL;   { Pointe sur le jeu de caractŠres en ROM }

begin
  if fptr = NIL then             { A-t-on d‚j… d‚termin‚ ce pointeur ? }
    begin                                                        { Non }
      Regs.AH := $11;                   { Appelle l'option $1130 de la }
      Regs.AL := $30;                         { fonction vid‚o du BIOS }
      Regs.BH := 3;          { pour obtenir un pointeur sur le jeu 8*8 }
      intr( $10, Regs );
      fptr := ptr( Regs.ES, Regs.BP );            { Compose le pointeur}
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
     printchar( strt[i], x, y, cc, cf );       { Affiche par printchar }
     inc( x, 8 );               { x … la position du caractŠre suivant }
   end;
end;

{***********************************************************************
*  GetVideo : Charge le contenu d'une zone rectangulaire de la m‚moire *
*             d'‚cran dans un buffer                                   *
**--------------------------------------------------------------------**
*  Entr‚es : PAGE    = Page d'‚cran (0 ou 1)                           *
*            X1, Y1  = Coordonn‚es de d‚part                           *
*            LARGEUR = Largeur de la zone rectangulaire en pixels      *
*            HAUTEUR = Hauteur de la zone rectangulaire en pixels      *
*            BUFPTR  = Pointeur sur le buffer de pixels qui va         *
*                      m‚moriser les informations                      *
*  Sortie  : Pointeur sur le buffer cr‚‚ qui contient la zone indiqu‚e *
*  Info    : Si on donne au paramŠtre BUFPTR la valeur NIL  un nouveau *
*            buffer de pixels est allou‚ sur le tas et retourn‚.       *
*            Ce buffer peut ˆtre transmis lors d'un nouvel appel si    *
*            l'ancien contenu est effa‡able et si la taille de la zone *
*            n'a pas chang‚. La zone indiqu‚e doit commencer … une     *
*            abscisse divisible par huit et s'‚tendre sur un nombre de *
*            pixels multiple de huit.                                  *
***********************************************************************}

function GetVideo( page : byte; x1, y1 : integer;
                   largeur, hauteur : byte; bufptr : PIXPTR ) : PIXPTR;

begin
  if ( bufptr = NIL ) then                  { Pas de buffer transmis ? }
    begin                                             { Non, on alloue }
      new( bufptr );                        { Cr‚e le buffer de pixels }
      getmem( bufptr^.pixbptr, (largeur*hauteur) div 2 );
      bufptr^.hauteur := hauteur;        { Hauteur du buffer en lignes }
      bufptr^.largeurbyte := largeur div 8;{Largeur une ligne en octets}
      bufptr^.pixblen:=(largeur*hauteur) div 2;{Taille totale du buffer}
    end;

  CopyVideo2Buf( bufptr^.pixbptr, page, x1, y1, largeur div 8, hauteur );
  GetVideo := bufptr;             { Retourne un pointeur sur le buffer }
end;

{***********************************************************************
*  PutVideo : R‚‚crit dans la m‚moire d'‚cran le contenu d'une zone    *
*             rectangualire pr‚alablement sauvegard‚e par GetVideo()   *
**--------------------------------------------------------------------**
*  Entr‚e : BUFPTR  = Pointeur renvoy‚ par Getvideo et r‚f‚ren‡ant un  *
*                     buffer de pixels                                 *
*            PAGE   = Page d'‚cran (0 ou 1)                            *
*            X1, Y1 = Coordonn‚es de d‚but                             *
*  Info    : Le buffer de pixels n'est pas effac‚ par cette proc‚dure  *
*            cette tƒche ‚tant remplie par FreePixBuf()                *
*            L'abscisse X indiqu‚e doit ˆtre un multiple de huit       *
***********************************************************************}

procedure PutVideo( bufptr : PIXPTR; page : byte; x1, y1 : integer );

begin
  CopyBuf2Video( bufptr^.pixbptr, page, x1, y1,
                 bufptr^.largeurbyte, bufptr^.hauteur );
end;

{***********************************************************************
*  FreePixBuf : Efface un buffer de pixels allou‚ sur le tas par       *
*               GetVideo                                               *
**--------------------------------------------------------------------**
*  Entr‚e  : BUFPTR = Pointeur renvoy‚ par Getvideo et r‚f‚ren‡ant un  *
*                     buffer de pixels                                 *
***********************************************************************}

procedure FreePixBuf( bufptr : PIXPTR );

begin
  freemem( bufptr^.pixbptr, bufptr^.pixblen );
  dispose( bufptr );
end;

{***********************************************************************
*  CreateSprite : Cr‚e un sprite … l'aide d'un motif de pixels         *
*                 pr‚alablement compil‚                                *
**--------------------------------------------------------------------**
*  Entr‚e : SPLOOKP = Pointeur sur la structure de donn‚es produite    *
*                     par CompileSprite()                              *
*  Sortie : Pointeur sur la structure du sprite cr‚‚e                  *
***********************************************************************}

function CreateSprite( splookp : SPLP ) : SPIP;

var spidp : SPIP;          { Pointeur sur la structure du sprite cr‚‚e }

begin
  new( spidp );             { Alloue de la m‚moire pour le descripteur }
  spidp^.splookp := splookp;                 { Y transfŠre les donn‚es }

          {-- Cr‚e deux buffers de fond en sauvegardant par GetVideo  -}
                                  {--  une zone de la m‚moire d'‚cran -}

  spidp^.fondptr[0] := GetVideo( 0, 0, 0, splookp^.largeur,
                               splookp^.hauteur, NIL );
  spidp^.fondptr[1] := GetVideo( 0, 0, 0, splookp^.largeur,
                               splookp^.hauteur, NIL );
  CreateSprite := spidp;   { Renvoie un ptr sur la structure du sprite }
end;

{***********************************************************************
*  CompileSprite : Cr‚e le motif binaire d'un sprite … l'aide d'une    *
*                  d‚finition connue au moment de l'ex‚cution          *
**--------------------------------------------------------------------**
*  Entr‚es : BUFP    = Pointeur sur un tableau de pointeurs r‚f‚ren‡ant*
*                      des chaŒnes de caractŠres qui repr‚sentent le   *
*                      motif du sprite                                 *
*            HAUTEUR = Hauteur du sprite et nombre de chaŒnes de       *
*                      caractŠres                                      *
*  Info    : Dans le motif transmis un espace correspond … un pixel du *
*            fond A au code de couleur 0,  B … 1, C … 2 etc.           *
***********************************************************************}

function CompileSprite( var buf; hauteur : byte ) : SPLP;

type BYPTR  = ^byte;                           { Pointeur sur un octet }

var  slargeur,               { Longueur des chaŒnes = largeur du motif }
     largeurt,                                   { Largeur des sprites }
     c,                                        { M‚morise un caractŠre }
     i, k, l, y,                              { Variables d'it‚rations }
     andc,                                        { Compteur de pixels }
     andm     : byte;                               { Masque de pixels }
     andindex : integer;                    { Index dans le buffer AND }
     splookp  : SPLP;              { Pointeur sur la structure g‚n‚r‚e }
     lspb     : BYPTR;     { Pointeur courant dans le buffer du sprite }
     andp,                                { Pointeur sur le buffer AND }
     bptr     : BARPTR;            {Pour adresser le buffer de l'image }
     tpix     : PIXPTR;  { Pointeur sur un buffer de pixels temporaire }

{-- Sous proc‚dure AndBufInit: Initialise un buffer AND ----------}

procedure AndBufInit( bufp : BARPTR );

begin
  andp := bufp;                   { m‚morise un pointeur sur le buffer }
  andindex := 0;                         { Commence au d‚but du buffer }
  andm := 0;                       { Au d‚part le masque binaire est 0 }
  andc := 0;                 { Pas encore de bit dans le premier octet }
end;

{-- Sous-proc‚dure AndBufAppendBit: accroche un bit au buffer AND -----}

procedure AndBufAppendBit( bit : byte );

begin
  andm := andm or bit;                { Introduit le bit en position 0 }
  if andc = 7 then                                    { Octet rempli ? }
    begin                                                        { Oui }
      andp^[andindex] := andm;       { M‚morise l'octet dans le buffer }
      inc( andindex );                       { Adresse l'octet suivant }
      andm := 0;                         { Remet le masque binaire … 0 }
      andc := 0;     { Poursuit avec le premier bit de l'octet suivant }
    end
  else                                              { Octet non rempli }
    begin
      inc( andc );                             { Traite un bit de plus }
      andm := andm shl 1;                   { D‚cale le masque binaire }
    end;
end;

{-- Sous-proc‚dure AndBufEnd: Cl“ture le buffer AND--------------------}

procedure AndBufEnd;

begin
  if ( andc <> 0 ) then                       { Dernier octet rempli ? }
    andp^[andindex] := andm shl (7 - andc);          { Non, on termine }
end;

begin
            {-- Cr‚e une structure d'image et la remplit --------------}

  new( splookp );
  bptr := @buf;                         { Pointe sur le buffer du logo }
  slargeur := bptr^[0];{ Lit la longueur des chaŒnes = largeur du logo }
  largeurt := ( ( slargeur + 7 + 7 ) div 8 ) * 8;     { Largeur totale }
  splookp^.largeur := largeurt;          { M‚morise largeur et hauteur }
  splookp^.hauteur := hauteur;

  setpage( 1 );                      { Construit les sprites en page 1 }
  showpage( 0 );                              { mais affiche la page 0 }
  tpix := GetVideo( 1, 0, 0, largeurt, hauteur, NIL );   { Lit le fond }

        {-- Elabore et code huit fois le sprite -----------------------}

  for l := 0 to 7 do
    begin                    { Remplit d'abord le fond de pixels noirs }
      for y := 0 to hauteur-1 do
        Line( 0, y, largeurt-1, y, 0 );

                    {-- Alloue un buffer AND et l'initialise ----------}

      getmem( splookp^.bmskp[ l ], (largeurt*hauteur) div 8 );
      AndBufInit( splookp^.bmskp[ l ] );

      for i := 0 to hauteur-1 do                 { Parcourt les lignes }
        begin
      for y := 1 to l do        { Cr‚e les bits AND pour le bord gauche}
            AndBufAppendBit( 1 );

      for k := 0 to slargeur-1 do              { Parcourt les colonnes }
            begin
          c := bptr^[i*(slargeur+1)+k+1];             { Lit la couleur }
          if ( c = 32 ) then                         { Pixel de fond ? }
        begin                             { Oui, met le code couleur 0 }
                  setpix( k+l, i, 0 );
          AndBufAppendBit( 1 );               { Le pixel de fond reste }
                end
          else                      { Non, met le code couleur indiqu‚ }
                begin
          setpix( k+l, i, c-ord('@') );
          AndBufAppendBit( 0 );                { EnlŠve le bit de fond }
                end;
            end;
      for y := largeurt-slargeur-l downto 1 do   { Ajoute les bits AND }
        AndBufAppendBit( 1 );                     { pour le bord droit }
        end;
      AndBufEnd;                               { Referme le buffer AND }

    {-- Cherche le motif de pixels du sprite dans la m‚moire d'‚cran --}
      splookp^.pixmp[ l ] := GetVideo( 1, 0, 0, largeurt, hauteur, nil);

    end;                                     { Passe au sprite suivant }

  PutVideo( tpix, 1, 0, 0 );    { Restaure le fond du sprite en page 1 }
  FreePixBuf( tpix );                            { et efface le buffer }

  CompileSprite := splookp; { Renvoie un pointeur sur buffer du sprite }
end;

{***********************************************************************
*  PrintSprite : Affiche un sprie dans une page donn‚e                 *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*           PAGE  = Page concern‚e (0 ou 1 )                           *
***********************************************************************}

procedure PrintSprite( spidp : SPIP; page : byte );

var x : integer;                                { Abscisse X du sprite }

begin
  x := spidp^.x[page];
  MergeAndCopyBuf2Video( spidp^.splookp^.pixmp[x mod 8]^.pixbptr,
                         spidp^.fondptr[page]^.pixbptr,
                         spidp^.splookp^.bmskp[x mod 8],
                         page,
                         x and not(7),
                         spidp^.y[page],
                         spidp^.splookp^.largeur div 8,
                         spidp^.splookp^.hauteur );
end;

{***********************************************************************
*  GetSpriteBg : Lit le fond du sprite et le m‚morise … l'emplacement  *
*                pr‚vu                                                 *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*           PAGE  = Page d'o— est tir‚ le fond (0 ou 1)                *
***********************************************************************}

procedure GetSpriteBg( spidp : SPIP; page : BYTE );

var dummy : PIXPTR;

begin
  dummy := GetVideo( page, spidp^.x[page] and not(7), spidp^.y[page],
                     spidp^.splookp^.largeur, spidp^.splookp^.hauteur,
                     spidp^.fondptr[page] );
end;

{***********************************************************************
*  RestoreSpriteBg : R‚tablit dans la page d'origine le fond d'un      *
*                    sprite sauvegard‚ au pr‚alable                    *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*           PAGE  = Page o— doit ˆtre recopi‚ le fond (0 ou 1)         *
***********************************************************************}

procedure RestoreSpriteBg( spidp : SPIP; page : BYTE );

begin
 PutVideo( spidp^.fondptr[page], page,
           spidp^.x[page] and not(7), spidp^.y[page] );
end;

{***********************************************************************
*  MoveSprite : D‚place un sprite dans sa page d'‚cran                 *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP  = Pointeur sur la structure du sprite              *
*            PAGE   = Page o— doit ˆtre recopi‚ le fond (0 ou 1)       *
*            DELTAX = D‚placement dans les directions X et Y           *
*            DELTAY                                                    *
*  Sortie  : Indicateur de collision, cf constantes OUT_...            *
***********************************************************************}

function MoveSprite( spidp : SPIP; page : byte;
                     deltax, deltay : integer    ) : byte;

var nouvx, nouvy : integer;          { Nouvelles coordonn‚es du sprite }
    out        : byte;  { Indique une collision avec le bord de l'‚cran}

begin
          {-- D‚cale l'abscisse X et d‚tecte les collisions -----------}

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

        {-- D‚cale l'ordonn‚e Y et d‚tecte les collisions   -----------}

 nouvy := spidp^.y[page] + deltay;
 if ( nouvy < 0 ) then                                     { Bord sup? }
   begin                               { Oui, deltay doit ˆtre n‚gatif }
     nouvy := 0 - deltay - spidp^.y[page];
     out := out or OUT_TOP;
   end
 else
   if ( nouvy + spidp^.splookp^.hauteur > MAXY+1  ) then  { Bord inf ? }
     begin                            { Oui , deltay doit ˆtre positif }
       nouvy := (2*(MAXY+1))-nouvy-2*(spidp^.splookp^.hauteur);
       out := out or OUT_BOTTOM;
     end;

{Ne fixe une nouvelle position que si elle est diff‚rente de l'ancienne}

 if ( nouvx <> spidp^.x[page] ) or  ( nouvy <> spidp^.y[page] ) then
   begin                                           { Nouvelle position }
     RestoreSpriteBg( spidp, page );                { Restaure le fond }
     spidp^.x[page] := nouvx;                 { M‚morise les nouvelles }
     spidp^.y[page] := nouvy;                            { coordonn‚es }
     GetSpriteBg( spidp, page );                 { Lit le nouveau fond }
     PrintSprite( spidp, page );{ Dessine le sprite dans page indiqu‚e }
   end;

 MoveSprite := out;
end;

{***********************************************************************
*  SetSprite : Place un sprite … une position donn‚e                   *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP  = Pointeur sur la structure du sprite              *
*            x0, y0 = Coordonn‚es du sprite en page 0                  *
*            x1, y1 = Coordonn‚es du sprite en page 1                  *
*  Info    : Cette fonction doit ˆtre d‚clench‚e avant le premier      *
*            appel … MoveSprite()                                      *
***********************************************************************}

procedure SetSprite( spidp : SPIP; x0, y0, x1, y1 : integer );

begin
 spidp^.x[0] := x0;       { M‚morise les coordonn‚es dans la strcuture }
 spidp^.x[1] := x1;
 spidp^.y[0] := y0;
 spidp^.y[1] := y1;

 GetSpriteBg( spidp, 0 );                   { Lit le fond du sprite en }
 GetSpriteBg( spidp, 1 );                               { pages 0 et 1 }
 PrintSprite( spidp, 0 );                          { Dessine le sprite }
 PrintSprite( spidp, 1 );                             { en page 0 et 1 }
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
  LARGEUR = 42;          { Nombre de caractŠres de l'avis de copyright }
  HAUTEUR  = 6;                        { Nombre de lignes du mˆme avis }
  SX     = (MAXX-(LARGEUR*8)) div 2;           { Coordonn‚es de d‚part }
  SY     = (MAXY-(HAUTEUR*8)) div 2;

type SPRITE = record                          { Pour g‚rer les sprites }
        spidp : SPIP;                  { Pointeur sur l'identificateur }
        deltax,              { D‚placement horizontal  en page 0 und 1 }
        deltay : array [0..1] of integer;       { D‚placement vertical }
              end;

var sprites    : array [1..nbspr] of SPRITE;
    page,                                              { page courante }
    lc,                                            { caractŠre courant }
    out        : byte;                       { Indicateur de collision }
    x, y, i,                                  { Compteurs d'it‚rations }
    dx, dy     : integer;                               { D‚placements }
    vaisseauupp,
    vaisseaudnp : SPLP;                    { Pointeurs sur les sprites }
    ch         : char;

begin
  Randomize;          { Initialise le g‚n‚rateur de nombres al‚atoires }

        {-- Construit les motifs binaires des sprites -----------------}

  vaisseauupp := CompileSprite( VaisseauMontant,   20 );
  vaisseaudnp := CompileSprite( VaisseauDescendant, 20 );

       {-- Remplit de caractŠres les deux pages graphiques ------------}

  for page := 0 to 1 do
    begin
      setpage( page );
      showpage( page );
      lc := 0;
      y := 0;
      while ( y < (MAXY+1)-8 ) do
        begin
          x := 0;
          while ( x < (MAXX+1)-8 ) do
            begin
              PrintChar( chr(lc and 127), x, y, lc and 15, 0 );
              inc( lc );
              inc( x, 8 );
            end;
          inc( y, 12 );
        end;

     {-- Affiche l'avis de copyright ----------------------------------}

      Line( SX-1, SY-1, SX+LARGEUR*8, SY-1, 15 );
      Line( SX+LARGEUR*8, SY-1, SX+LARGEUR*8, SY+HAUTEUR*8,15 );
      Line( SX+LARGEUR*8, SY+HAUTEUR*8, SX-1, SY+HAUTEUR*8, 15 );
      Line( SX-1, SY+HAUTEUR*8, SX-1, SY-1, 15 );
      GrafPrint( SX, SY,    15, 4,
                   '                                          '  );
      GrafPrint( SX, SY+8,  15, 4,
                   ' S6435P.PAS - (c) 1990 by Michael Tischer ' );
      GrafPrint( SX, SY+16, 15, 4,
                   '                                          '  );
      GrafPrint( SX, SY+24, 15, 4,
           '   D‚monstration de sprites dans le mode  '  );
      GrafPrint( SX, SY+32, 15, 4,
           '       640*350 des cartes EGA et VGA      '  );
      GrafPrint( SX, SY+40, 15, 4,
                   '                                          '  );
    end;

      {-- R‚alise les diff‚rents sprites ------------------------------}

  for i := 1 to NBSPR do
    begin
      sprites[ i ].spidp := CreateSprite( vaisseauupp );
      repeat                      { Choisit les valeurs de d‚placement }
        dx := 0;
        dy := random(10) - 5;
      until ( dx <> 0 ) or ( dy <> 0 );

      sprites[ i ].deltax[0] := dx * 2;
      sprites[ i ].deltay[0] := dy * 2;
      sprites[ i ].deltax[1] := dx * 2;
      sprites[ i ].deltay[1] := dy * 2;

      x := ( ((MAXX+1) div NBSPR) * (i-1) )
           + (((MAXX+1) div NBSPR)-40) div 2;
      y := random( (MAXY+1) - 40 );
      SetSprite( sprites[ i ].spidp, x, y, x - dx, y - dy );
    end;

{- D‚place les sprites et les fait rebondir aux extr‚mit‚s de l'‚cran -}

  page := 1;                                  { Commence par la page 1 }
  while ( not keypressed ) do{Une frappe de touche interrompt la boucle}
    begin
      showpage( 1-page );                       { Affiche l'autre page }
                                                      { ch := readkey; }                 {                                                    ATtend une frappe }
      for i := 1 to nbspr do                    { Parcourt les sprites }
    begin              { D‚place les sprites et d‚tecte les collisions }
          out := MoveSprite( sprites[i].spidp, page,
                             sprites[i].deltax[page],
                             sprites[i].deltay[page] );
      if ( ( out and OUT_TOP ) <> 0 ) or     {Contact en haut/en bas ? }
             ( ( out and OUT_BOTTOM) <> 0) then
            begin
                 {-- Oui inverse le d‚placement et change l'image - ---}

              sprites[i].deltay[page] := -sprites[i].deltay[page];
              if ( ( out and OUT_TOP ) <> 0 ) then
                sprites[i].spidp^.splookp := vaisseaudnp
              else
                sprites[i].spidp^.splookp := vaisseauupp;
            end;
      if ( ( out and OUT_LEFT ) <> 0 ) or    {contact … gauche/droite ?}
             ( ( out and OUT_RIGHT ) <> 0 ) then
            sprites[i].deltax[page] := -sprites[i].deltax[page];
        end;
      page := (page+1) and 1;            { Passe de 1 … 0 et vice versa}
    end;
  ch := readkey;                         { Attend une frappe de touche }
end;

{----------------------------------------------------------------------}
{--                       PROGRAMME PRINCIPAL                        --}
{----------------------------------------------------------------------}

begin
 if ( IsEgaVga <> NINI ) then  { Dispose-t-on d'une carte EGA ou VGA ? }
   begin                                            { Oui, c'est parti }
     init640350;                        { Initialise le mode graphique }
     Demo;
     Textmode( CO80 );                        { R‚tablit le mode texte }
   end
 else
   writeln( 'S6435P.PAS - (c) 1990 by MICHAEL TISCHER'#13#10#10 +
        'Attention! Ce programme n‚cessite une carte EGA ou VGA');
end.
