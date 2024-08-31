{***********************************************************************
*                          L O G O P . P A S                           *
**--------------------------------------------------------------------**
*  Fonction       : Montre comment d‚finir des jeux de caractŠres      *
*                   personnalis‚s avec une carte VGA ou EGA en donnant *
*                   comme exemple une routine repr‚sentant un logo en  *
*                   mode texte.                                        * 
**--------------------------------------------------------------------**
*  Auteur         : MICHAEL TISCHER                                    *
*  D‚velopp‚ le   : 05.08.1990                                         *
*  DerniŠre MAJ   : 14.01.1991                                         *
***********************************************************************}

Program Logop;

uses DOS, CRT;

{-- Constantes --------------------------------------------------------}

const EGAVGA_SEQUENCER = $3C4;   { Port adresses/donn‚es du s‚quenceur }
      EGAVGA_MONCTR    = $3D4;            { Adresse contr“leur d'‚cran }
      EGAVGA_GRAPHCTR  = $3CE;{Port adr./donn‚e du contr“leur graphique}
      EV_STATC         = $3DA;       { Registre d'‚tat couleur EGA/VGA }
      EV_STATM         = $3BA;          { Registre d'‚tat mono EGA/VGA }
      EV_ATTR          = $3C0;         { Contr“leur d'attribut EGA/VGA }

{-- D‚clarations de types ---------------------------------------------}

type CARTE = ( EGA, VGA, NINI);

procedure CLI; inline( $FA );               { Inhibe les interruptions }
procedure STI; inline( $FB );              { r‚tablit les interruptions}

{***********************************************************************
*  SetCharWidth : Fixe la largeur des caractŠres … 8 ou 9 pixels       *
*                 pour les cartes VGA.                                 *
**--------------------------------------------------------------------**
*  Entr‚e       : LARGEUR = Largeur des caractŠres (8 ou 9)            *
***********************************************************************}

procedure SetCharWidth( largeur : byte );

var Regs : Registers;         { Registres pour g‚rer les interruptions }
    x    : byte;                                 { Variable de travail }

begin
  if ( largeur = 8 ) then Regs.BX := $0001      { BH = Alignem. horiz. }
                     else Regs.BX := $0800;{ BL=valeur pour reg du s‚q }

  x := port[ $3CC ] and not(4+8);    { R‚solution horizontale de 720 … }
  if ( largeur = 9 ) then                   { 640 pixels ou vice-versa }
    x := x or 4;
  port[ $3C2 ] := x;

  CLI;                         { Programme le s‚quenceur en con‚quence }
  portw[ EGAVGA_SEQUENCER ] := $0100;
  portw[ EGAVGA_SEQUENCER ] := $01 + Regs.BL shl 8;
  portw[ EGAVGA_SEQUENCER ] := $0300;
  STI;

  Regs.AX := $1000;                                   { Ajuste l'‚cran }
  Regs.BL := $13;
  intr( $10, Regs );
end;

{***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA.                *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie : EGA, VGA ou NINI                                           *
***********************************************************************}

function IsEgaVga : CARTE;

var Regs : Registers;         { Registres pour g‚rer les interruptions }

begin
  Regs.AX := $1a00; { La fonction 1Ah n'existe que pour les cartes VGA }
  Intr( $10, Regs );
  if ( Regs.AL = $1a ) then        { La fonction est-elle disponible ? }
    IsEgaVga := VGA
  else
    begin
      Regs.ah := $12;                           { Appelle l'option 10h }
      Regs.bl := $10;                             { de la fonction 12h }
      intr($10, Regs);                { D‚clenche l'interruption vid‚o }
      if ( Regs.bl <> $10 ) then IsEgaVga := EGA
                            else IsEgaVga := NINI;
    end;
end;

{***********************************************************************
*  BuildLogo : Dessine un logo compos‚ de diff‚rents caractŠres        *
*              red‚finis qui ne sont pas utilis‚s en fran‡ais          *
**--------------------------------------------------------------------**
*  Entr‚e :  COLONNE    = Colonne o— d‚bute le logo (1-80)             *
*            LIGNE      = Ligne o— d‚bute le logo (1-25)               *
*            PROFONDEUR = Nombre de lignes de trame du logo            *
*            COULEUR    = Couleur d'affichage du logo                  *
*            BUF        = Pointeur sur un tableau de pointeurs         *
*                         qui r‚f‚rencent le motif du logo             *
*  Info    : - La proc‚dure test montre comment -                      *
*              r‚aliser le buffer … transmettre .                      *
*            - Le logo est centr‚ dans son bloc de caractŠres          *
***********************************************************************}

procedure BuildLogo(colonne, ligne, profondeur, couleur: byte; var buf);

type BYTEAR = array[0..10000] of byte;             { Tableau d'octets  }
     BARPTR = ^BYTEAR;                        { pour le buffer du logo }

const MAX_CHAR = 32;           { maximum de caractŠres red‚finissables }

const UseChars : array[1..MAX_CHAR] of byte =   { CaractŠres red‚finis }
                  ( 128, 130, 132, 134, 141, 142, 143, 144, 146, 149,
                    152, 153, 154, 155, 156, 157, 158, 159, 160, 161,
                    162, 163, 164, 165, 166, 167, 168, 171, 172, 173,
                    174, 175 );

var Regs      : Registers;    { Registres pour g‚rer les interruptions }
    cvideo    : CARTE;                        { Type de la carte vid‚o }
    chardef   : array[0..15] of byte;   { Motif binaire d'un caractŠre }
    charhauteur,             { Nombre de lignes de trame par caractŠre }
    i, j, k, l,                               { Compteurs d'it‚rations }
    masque,                           { Masque pour une ligne de trame }
    largeur,                                    { Largeur de la chaŒne }
    index,                 { Indice pour parcourir le tableau UseChars }
    dx,                  { Largeur du bloc du logo (colonnes de texte) }
    dy,                { Profondeur du bloc de logo (lignes de texte ) }
    gauche,                                  { limite gauche en pixels }
    droite,                                  { limite droite en pixels }
    haut,                                       { limite sup en pixels }
    bas    : byte;                              { limite inf en pixels }
    bptr     : barptr;               { pour adresser le buffer du logo }

 { Fonction imbriqu‚e IsSet: D‚termine si un pixel du logo est dessin‚ }

function IsSet( ligne, colonne : byte ) : boolean;

begin
  if ( ligne < haut ) or ( ligne > bas ) or          { Pixel en dehors }
     ( colonne < gauche ) or ( colonne > droite ) then  { de la zone ? }
   IsSet := false                             { Oui, n'est pas dessin‚ }
  else                           { Non, regarde dans le buffer du logo }
   IsSet := bptr^[ (ligne-haut)*(largeur+1) +1+(colonne-gauche) ] <> 32;
end;

{-- Proc‚dure principale ----------------------------------------------}

begin
  cvideo := IsEgaVga;                       { D‚termine la carte vid‚o }
  case cvideo of
    NINI :
      begin
        writeln( 'Erreur: pas de carte EGA ou VGA install‚e !' );
        exit;
      end;

    EGA       :
      charhauteur := 14;       { EGA: 14 lignes de trame par caractŠre }

    VGA       :
      begin                                                      { VGA }
        SetCharWidth( 8 );        { Un caractŠre a 8 pixels en largeur }
        charhauteur := 16;          { 16 lignes de trame par caractŠre }
      end;
    end;

  bptr := @buf;                         { Pointe sur le buffer du logo }
  largeur := bptr^[0];       { Longueur de la chaŒne = largeur du logo }
  dx := ( largeur + 7 ) div 8;                  { Nombre de caractŠres }
  dy := ( profondeur + charhauteur - 1 ) div charhauteur;
  if ( dx*dy > MAX_CHAR ) then
    writeln( 'Erreur: Logo trop grand dans BuildLogo ! ' )
  else
    begin
      haut   := ( dy*charhauteur-profondeur ) div 2;{ Calcule les lim. }
      bas  := profondeur + haut - 1;
      gauche  := ( dx*8-largeur ) div 2;
      droite := largeur + gauche - 1;

      TextColor( couleur and 15 );       { Fixe la couleur d'affichage }
      TextBackGround( couleur shr 4 );
      index := 1;              { Premier caractŠre de le table UseChar }
      for i := 0 to dy-1 do             { Parcourt les lignes de texte }
        begin
          GotoXY( colonne, ligne + i );
          for j := 1 to dx do         { Parcourt les colonnes de texte }
            begin
              write( chr( UseChars[ index ] ) ); { Affiche les caract. }

              {-- Calcule le nouveau motif pour le caractŠre affich‚ --}

              for k := 0 to charhauteur-1 do  { Parcourt les de trames }
                begin
                  masque := 0;             { Pour l'instant masque nul }
                  for l := 0 to 7 do{ Chaque caract. 8 pixels de large }
                    begin
                      masque := masque shl 1;{D‚cale masque vers gauche}
                      if IsSet( i*charhauteur+k, (j-1)*8+l ) then
                        masque := masque or 1;      { Dessine le pixel }
                    end;
                  chardef[ k ] := masque;      { Motif binaire dans le }
                end;                           { buffer des caracteres }
              Regs.AX := $1100;        { Fixe le ,ouveau motif binaire }
              Regs.BH := charhauteur;       { … l'aide de l'option $00 }
              Regs.BL := 0;     { de la fonction $10 de l'interruption }
              Regs.CX := 1;                            { vid‚o du BIOS }
              Regs.DX := UseChars[ index ];
              Regs.ES := seg( chardef );
              Regs.BP := ofs( chardef );
              intr( $10, Regs );

              inc( index );           { CaractŠre suivant dans UseChar }
            end;
        end;
    end;
end;

{***********************************************************************
*  ResetLogo : Recharge le jeu de caractŠres d'origine                 *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************}

procedure ResetLogo;

var Regs      : Registers;       { registres pour g‚rer l'interruption }

begin
  case IsEgaVga of
    EGA  : begin
             Regs.AX := $1101;        { Charge … nouveau le jeu 8 x 14 }
             Regs.BL := 0;
             intr( $10, Regs );
           end;

    VGA  : begin
             SetCharWidth( 9 );{ Repr‚sente les caractŠres sur 9 pixel }
             Regs.AX := $1104;                  { recharge le jeu 8*16 }
             Regs.BL := 0;
             intr( $10, Regs );
           end;
    end;
end;

{***********************************************************************
*  Test : exemple de fonctionnement de la proc‚dure BuildLogo          *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                     *
***********************************************************************}

procedure Test;

const MyLogo : array[1..32] of string[38] =
                ( '                  **                  ',
                  '                 ****                 ',
                  '                 ****                 ',
                  '                  **                  ',
                  '                                      ',
                  '                                      ',
                  '                                      ',
                  '                 ****                 ',
                  '                 ****                 ',
                  '**************************************',
                  '**************************************',
                  '***              ****              ***',
                  '**               ****               **',
                  '*                ****                *',
                  '                 ****                 ',
                  '                 ****                 ',
                  '      ********   ****   ********      ',
                  '      ****  **** **** ****  ****      ',
                  '      ****     ********     ****      ',
                  '      ****      ******      ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ',
                  '      ****       ****       ****      ' );

var ch : char;
    i  : byte;

const NouvDef : set of char = [#128, #129, #132, #134, #141..#144, #146,
                               #149, #152..#168, #171..#173];

begin
  TextBackGround( BLACK );
  ClrScr;
  GotoXY( 1, 1 );
  for i := 0 to 255 do         { Affiche le jeu complet des caractŠres }
    begin
      if ( chr(i) in NouvDef ) then TextColor( WHITE )
                               else TextColor( YELLOW );

      GotoXY( i mod 13 * 6 + 2, i div 13 + 1 );
      write( i:3 , ':' );
      if ( i <> 13 ) and ( i <> 10 ) and ( i <> 7 ) then
       write( chr( i ) );
    end;

  GotoXY( 23, 22 );
  write( 'LOGOP  -  (c) 1990 by MICHAEL TISCHER' );
  BuildLogo( 61, 21, 32, CYAN shl 4 + WHITE, MyLogo );{ Dessine le logo}
  ch := ReadKey;                         { Attend une frappe de touche }
  ResetLogo;                                           {Efface le logo }
  ClrScr;
  GotoXY( 1, 1 );
end;

{**********************************************************************}
{--                        PROGRAMME PRINCIPAL                       --}
{**********************************************************************}

begin
  Test;
end.
