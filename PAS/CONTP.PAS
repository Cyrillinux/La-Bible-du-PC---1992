{***********************************************************************
*                              C O N T P                               *
**--------------------------------------------------------------------**
*  Fonction : montre comment programmer un d‚filement continu de texte *
*             avec une carte EGA ou VGA                                *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     : 23.01.1990                                       *
*  DerniŠre MAJ     : 14.01.1991                                       *
***********************************************************************}

program TextContinu;

uses dos,                                          { Inclut les unit‚s }
     crt;

const SLOW      = 1;           { Valeurs de SPEED pour ShowDefilText() }
      MEDIUM    = 2;
      FAST      = 3;

const COULEUR     = $5E;                        { Jaune sur fond lilas }
      COULEUR1    = $5F;                        { Blanc sur fond lilas }
      LARGEUR     = 8;              { Largeur des caractŠres en pixels }
      HAUTEUR     = 14;    { Hauteur des caractŠres en lignes de trame }
      COLONNES    = 216;      { Nb colonnes par ligne en m‚moire ‚cran }
      BANDSIZE    = 10800;                        { Taille d'une bande }
      BANDES      = 3;                              { Nombre de bandes }
      MAXLEN      = 61;                 { Nombre maximal de caractŠres }
      STARTL      = 6;  { Ligne o— commencent les caractŠres sur ‚cran }

      CrtAttr     = $3C0;          { Registre du contr“leur d'attribut }
      CrtStatus   = $3da;                                { Port d'‚tat }
      CrtAdr      = $3d4;                { Port d'adresses du moniteur }


type VRAM = array[1..BANDES,1..25,1..COLONNES] of word;{ M‚moire ‚cran }
     VPTR = ^VRAM;                   { Pointeur sur la m‚moire d'‚cran }

var vp         : vptr;                 { Pointe sur la m‚moire d'‚cran }

type CARTE = ( EGA, VGA, NINI );                 { Type de carte vid‚o }

procedure CLI; inline( $FA );               { Inhibe les interruptions }
procedure STI; inline( $FB );             { R‚tablit les interruptions }

{***********************************************************************
*  SetOrigin : Fixe la partie visible de la m‚moire d'‚cran par        *
*              programmation du contr“leur vid‚o                       *
**--------------------------------------------------------------------**
*  Entr‚es :   Band    = Num‚ro de la bande … afficher  (1-5)          *
*              Colonne = Num‚ro de la colonne et de la ligne           *
*              Ligne     affich‚es en haut … gauche (Origine= 0,0)     *
*              PixX,   = Offset en pixels                              *
*              PixY                                                    *
***********************************************************************}

procedure SetOrigin( band, colonne, ligne, pixx, pixy : byte );

var offset : integer;          { Offset de d‚but de la m‚moire d'‚cran }
ch : char;

begin
  offset := ( BANDSIZE div 2 ) * (band-1) + ligne * COLONNES + colonne;

        {-- Attend un retour vertical du faisceau puis sa fin ---------}

  repeat until port[CrtStatus] and 8 = 8;
  repeat until port[CrtStatus] and 8 = 0;

{ Ecrit dans les registres $0C et $0D l'offset de d‚but de m‚m. ‚cran  }
{  N'est pris en compte qu'aprŠs le prochain retour faisceau vertical  }

  CLI;                                      { Inhibe les interruptions }
  portw[ CrtAdr ] := hi( offset ) shl 8 + $0c;
  portw[ CrtAdr ] := lo( offset ) shl 8 + $0d;
  STI;

    {-- Attend le d‚but du retour vertical du faisceau pour fixer le --}
 {-- nouvel offset en pixels et la nouvelle adresse de d‚but d'‚cran --}

  repeat until port[CrtStatus] and 8 = 8;

      {-- Ecrit l'offset en pixels dans les registres $08 / $13 du  ---}
                                          {-- contr“leur d'attribut ---}

  CLI;
  portw[ CrtAdr ] := pixy shl 8 + $08;
  port[ CrtAttr ] := $13 or $20;        { N'accŠde que octet par octet }
  port[ CrtAttr ] := pixx;                  { au contr“leur d'attribut }
  STI;                                    { R‚tablit les interruptions }

                                                      { ch := readkey; }
end;

{***********************************************************************
*  PrintChar : Ecrit un caractŠre en dehors de la zone visible de      *
*              la m‚moire d'‚cran                                      *
**--------------------------------------------------------------------**
*  Entr‚es :   Caractere= CaractŠre … ‚crire                           *
*              Band    = Num‚ro de la bande (0-4)                      *
*              Colonne = Colonne en m‚moire d'‚cran o— doit commencer  *
*                        le caractŠre                                  *
*  Info    :   Le caractŠre ‚crit ne peut ˆtre rendu visible que par   *
*              d‚filement continu de l'‚cran                           *
*              Le motif binaire du caractŠre est tir‚ du jeu de        *
*              caractŠres 14*8 pixels de la ROM EGA ou VGA             *
***********************************************************************}

procedure PrintChar( caractere : char; band, colonne : byte );

type CARDEF = array[0..255,1..14] of byte;  { Struct. du jeu de caract }
     CARPTR = ^CARDEF;               { Pointe sur le jeu de caractŠres }

var  Regs  : Registers;       { Registres pour g‚rer les interruptions }
     ch    : char;                                { Pixel du caractŠre }
     i, k,                                    { Compteurs d'it‚rations }
     masque : byte;        { Masque binaire pour dessiner le caractŠre }

const fptr : CARPTR = NIL;     { Pointeur sur jeu de caractŠres en ROM }

begin
  if fptr = NIL then         { Le pointeur a-t-il d‚j… ‚t‚ d‚termin‚ ? }
    begin                                                        { Non }
      Regs.AH := $11;                   { Appelle l'option $30 de      }
      Regs.AL := $30;                   { l'interruption $11 du BIOS   }
      Regs.BH := 2;             { Renvoie un pointeur sur le jeu  8*14 }
      intr( $10, Regs );
      fptr := ptr( Regs.ES, Regs.BP );           { Compose le pointeur }
    end;

     {-- Parcourt et dessine le caractŠre ligne par ligne  ------------}

  for i := 1 to HAUTEUR do
    begin
      masque := fptr^[ord(caractere),i]; { Motif binaire pour une ligne}
      for k := 1 to LARGEUR do    { Passe en revue les diff‚rents bits }
        begin
          if masque and 128 = 128 then ch := #219   { Dessine un pixel }
                                  else ch := #32;     { Efface un pixel}
          vp^[band, STARTL+i, (colonne-1)*LARGEUR+k] :=
                                                ord(ch) + COULEUR shl 8;
          masque := masque shl 1;               { Passe au bit suivant }
        end;
    end;
end;

{***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : EGA, VGA ou NINI                                          *
***********************************************************************}

function IsEgaVga : CARTE;

var Regs : Registers;         { Registres pour g‚rer les interruptions }

begin
  Regs.AX := $1a00;               { La fonction 1Ah n'existe qu'en VGA }
  Intr( $10, Regs );
  if ( Regs.AL = $1a ) then          { La fonction est-elle disponible }
    IsEgaVga := VGA
  else
    begin
      Regs.ah := $12;                      { Appelle l'option $10 de   }
      Regs.bl := $10;                                { la fonction $12 }
      intr($10, Regs);                            { Interruption vid‚o }
      if ( Regs.bl <> $10 ) then IsEgaVga := EGA
                            else IsEgaVga := NINI;
    end;
end;

{***********************************************************************
*  ShowDefilText : Fait d‚filer un texte sur l'‚cran                   *
**--------------------------------------------------------------------**
*  Entr‚es : DTEXT = Texte … faire d‚filer sous forme de chaŒne        *
*            SPEED = Vitesse de d‚filement (Constantes SLOW, FAST etc.)*
*            VC    = Type de carte vid‚o (EGA ou VGA)                  *
***********************************************************************}

procedure ShowDefilText( dtext : string; speed : byte; vc : carte );

var band,                                             { Bande courante }
    colonne,                                        { Colonne courante }
    index,               { Indice courant dans la chaŒne de caractŠres }
    len,                                { Longueur du texte … afficher }
    i, k : integer;                           { Compteurs d'it‚rations }
    step,                                          { Pas de d‚filement }
    uplimit : byte;                              { Nombre d'it‚rations }
    Regs : Registers;               { Registres pour les interruptions }

const steptable : array [EGA..VGA,1..3,1..10] of byte =
        (
          (                               { Pas de d‚filement pour EGA }
            (   0,   1,   2,   3,   4,   5,   6,   7, 255, 255 ),
            (   0,   2,   4,   6, 255, 255, 255, 255, 255, 255 ),
            (   0,   4, 255, 255, 255, 255, 255, 255, 255, 255 )
          ),
          (                               { Pas de d‚filement pour VGA }
            (   8,   0,   1,   2,   3,   4,   5,   6,   7, 255 ),
            (   8,   2,   5, 255, 255, 255, 255, 255, 255, 255 ),
            (   8,   3, 255, 255, 255, 255, 255, 255, 255, 255 )
          )
        );

begin
  vp := ptr( $B800, $0000 );           { Pointe sur la m‚moire d'‚cran }

{-- Remplit toute la m‚moire d'‚cran avec des espaces --}

  for index := 1 to BANDES do
    for i := 1 to 25 do
      for k := 1 to COLONNES do
        vp^[ index, i, k ] := COULEUR shl 8 + 32;

        {-- Trace des guides horizontaux ------------------------------}

  for k := 1 to BANDES do
    for i := 1 to COLONNES do
      begin
        vp^[ k, STARTL-2, i ] := ord('Í') + COULEUR1 shl 8;
        vp^[ k, STARTL + HAUTEUR + 2, i ] := ord('Í') + COULEUR1 shl 8;
      end;

  gotoxy( 1, 1 );                 { Le curseur disparaŒt au d‚filement }

          {-- Fixe la couleur du cadre d'‚cran ------------------------}

  Regs.AH := $10; { Num‚ro de la fonction  "Fixer la couleur du cadre "}
  Regs.AL := $01;                                    { Num‚ro d'option }
  Regs.BH := COULEUR shr 4;                         { Couleur du cadre }
  intr( $10, Regs );

      {-- Fixe le nombre de colonnes par ligne dans la m‚moire ‚cran --}

  portw[ CrtAdr ] := ( COLONNES div 2 ) shl 8 + $13;

            {-- Ecrit le texte d‚filant dans la m‚moire d'‚cran -------}

  if length( dtext ) > MAXLEN then len := MAXLEN
                              else len := length ( dtext );
  colonne := 1;
  band   := 1;
  index  := 1;
  while ( index <= len ) do
    begin
      PrintChar( dtext[index], band, colonne ); { Dessine le caractŠre }
      inc( colonne );                              { Colonne suivante  }
      inc( index );                                { CaractŠre suivant }
      if ( colonne > ( COLONNES div LARGEUR ) ) then  { Change bande ? }
        begin                                                    { Oui }
          colonne := 1;                         { revient en colonne 1 }
          inc( band );                     { Passe … la bande suivante }
          dec( index, ( 80 div LARGEUR ) );      { Une page en arriŠre }
        end
    end;

          {-- Fait d‚filer le texte de droite … gauche sur l'‚cran - --}


  colonne := 0;                     { Commence en colonne 0 et bande 1 }
  band   := 1;
  for i := 1 to (len-( 80 div LARGEUR )) * LARGEUR do
    begin
      k := 1;
      while ( steptable[vc, speed, k] <> 255 ) do
        begin
          SetOrigin( band, colonne, 0, steptable[vc, speed, k], 0 );
          inc( k );
        end;

      inc( colonne );                             { Colonne suivante ? }
      if ( colonne = COLONNES - 80 ) then      { Changement de bande ? }
        begin                                                    { Oui }
          colonne := 0;                      { Recommence en colonne 0 }
          inc( band );                           { Incr‚mente la bande }
        end
    end;

  {-- Remet 80 caractŠres par ligne en m‚moire d'‚cran    -------------}

  portw[ CrtAdr ] := 40 shl 8 + $13;

                    {-- R‚tablit le cadre d'‚cran ---------------------}

  Regs.AH := $10;   { Num‚ro de la fonction "Fixer la couleur du cadre"}
  Regs.AL := $01;                                    { Num‚ro d'option }
  Regs.BH := 0;                                        { Cadre en noir }
  intr( $10, Regs );

  if ( vc = EGA ) then                        { Param‚trage par d‚faut }
    SetOrigin( 1, 0, 0, 0, 0 )                              { pour EGA }
  else
    SetOrigin( 1, 0, 0, 8, 0 );                             { pour VGA }
  ClrScr;
end;

{-- PROGRAMME PRINCIPAL }

var  ch : char; i : integer;
     vc : carte;

begin
  vc := IsEgaVga;                   { D‚termine le type de carte vid‚o }
  if vc = EGA then halt;
  if ( vc = NINI ) then
    begin
      writeln( 'TEXTE CONTINU - (c) 1990 by MICHAEL TISCHER'#13#10 );
      writeln( 'Attention: aucune carte EGA ou VGA n''est install‚e !');
    end
  else
    ShowDefilText('+++ BIBLE PC (c) 1987-1991 par Micro Application +++'
                 + '       ', FAST, vc );
  while keypressed do
   ch := readkey;
end.
