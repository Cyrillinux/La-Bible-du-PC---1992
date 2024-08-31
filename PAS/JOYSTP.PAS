{**********************************************************************}
{                              J O Y S T P                             }
{----------------------------------------------------------------------}
{    Fonction        : D‚montre l'utilisation des Joysticks            }
{                      … l'aide du BIOS                                }
{----------------------------------------------------------------------}
{    Auteur          : MICHAEL TISCHER                                 }
{    D‚velopp‚ le    : 25.02.1991                                      }
{    DerniŠre modif  : 25.02.1991                                      }
{**********************************************************************}

program JOYSTP;

uses DOS, CRT;

{== D‚claration de type ===============================================}

type JSPOS = record                 { D‚crit la position d'un Joystick }
                x,
                y : integer;
               end;

{== Constantes ========================================================}

const CRLF = #13#10;

{== Variables globales ================================================}

var jsp        : array [1..2] of JSPOS; { Position actuelle du Joystick}
    maxx, maxy,                         { Position maximale du Joystick}
    minx, miny,                         { Position minimale du Joystick}
    x, y,                                 { Position actuelle … l'‚cran}
    xold, yold : integer;                { Position ancienne … l'‚cran }
    actstick   : byte;                           { Joystick s‚lectionn‚}
    j1but,                               { Bouton 1 du Joystick 1 et 2 }
    j2but      : array[1..2] of byte;    { Bouton 2 du Joystick 1 et 2 }
    xfacteur,                          { facteurs de conversion X et Y }
    yfacteur    : real;

{***********************************************************************
*  GetJoyButton:  Renvoie l'emplacement des boutons de joystick        *
**--------------------------------------------------------------------**
*  ParamŠtres entr‚e: J1B1 = Variable pour Bouton 1 / Joystick 1       *
*                     J1B2 = Variable pour Bouton 2 / Joystick 1       *
*                     J2B1 = Variable pour Bouton 1 / Joystick 2       *
*                     J2B2 = Variable pour Bouton 2 / Joystick 2       *
*  Info             : Les diverses variables re‡oivent la valeur 1     *
*                     (TRUE) lorsque le bouton correspondant du        *
*                     joystick est appuy‚, sinon 0 (FALSE).            *
***********************************************************************}

procedure GetJoyButton( var j1b1, j1b2, j2b1, j2b2 : byte );

var Regs : Registers;         { Registres processeur pour appel d'int. }

begin
  Regs.ah := $84;                                       { Fonction 84h }
  Regs.dx := 0;                                    { Sous-fonction 00h }
  intr( $15, Regs );                             { Appel Interrupt 15h }
  j1b1 := (( Regs.al and  16 ) shr 4) xor 1;      { Bit 4 de AL = J1B1 }
  j1b2 := (( Regs.al and  32 ) shr 5) xor 1;      { Bit 5 de AL = J1B2 }
  j2b1 := (( regs.al and  64 ) shr 6) xor 1;      { Bit 6 de AL = J2B1 }
  j2b2 := (( regs.al and 128 ) shr 7) xor 1;      { Bit 7 de AL = J2B2 }
end;

{***********************************************************************
*  GetJoyPos : Retourne la position des deux Joysticks                 *
**--------------------------------------------------------------------**
*  ParamŠtre en entr‚e: JS1 = Structure Joystick pour le 1er Joystick  *
*                       JS2 = Structure Joystick pour le 2eme Joystick *
***********************************************************************}

procedure GetJoyPos( var Js1, Js2 : JSPOS );

var Regs : Registers;            { Registres pour appel d'interruption }

begin
  Regs.ah := $84;                                       { Fonction 84h }
  Regs.dx := 1;                                    { Sous-fonction 01h }
  intr( $15, Regs );                             { Appel Interrupt 15h }
  Js1.x := Regs.ax;                            { Position X Joystick 1 }
  Js1.y := Regs.bx;                            { Position Y Joystick 1 }
  Js2.x := Regs.cx;                            { Position X Joystick 2 }
  Js2.y := Regs.dx;                            { Position Y Joystick 2 }
end;

{**********************************************************************}
{*                           PROGRAMME PRINCIPAL                      *}
{**********************************************************************}

begin
                    {-- Lire d'abord la position maximale du Joystick--}

 ClrScr;
 writeln( 'Veuillez placer le joystick dans le coin sup‚rieur droit ' +
          + CRLF + 'et appuyez sur l''un des deux boutons' );

 repeat                   { Attendre l'appui sur le bouton du Joystick }
  GetJoyButton( j1but[1], j2but[1], j1but[2], j2but[2] );
 until ( ( j1but[1] or j2but[1] or j1but[2] or j2but[2] ) <> 0 );

 if ( j1but[1] or j2but[1] ) <> 0 then         { S‚lectionner Joystick }
   actstick := 1
 else
   actstick := 2;

 GetJoyPos( jsp[1], jsp[2] );                      { Lire Position     }
 maxx := jsp[actstick].x;                          { et ranger         }
 miny := jsp[actstick].y;

 repeat                          { Attendre que le bouton soit relƒch‚ }
  GetJoyButton( j1but[1], j2but[1], j1but[2], j2but[2] );
 until ( ( j1but[actstick] or j2but[actstick] ) = 0 );

 {-- Lire maintenant la position minimale -----------------------------}

 writeln( CRLF + CRLF + 'Placez le Joystick dans le coin'+
          ' inf‚rieur gauche' + CRLF +
          'et appuyez sur un bouton' );

 repeat                    { Attendre … nouveau l''appui sur un bouton }
  GetJoyButton( j1but[1], j2but[1], j1but[2], j2but[2] );
 until ( ( j1but[actstick] or j2but[actstick] ) <> 0 );

 GetJoyPos( jsp[1], jsp[2] );                       { Lire la position }
 minx := jsp[actstick].x;                           { et ranger        }
 maxy := jsp[actstick].y;

 xfacteur := 80.0 / ( maxx - minx + 1 );    { Calculer les facteurs de }
 yfacteur := 23.0 / ( maxy - miny + 1 );{ conversion pour les axes X/Y }

              {-- D‚terminer le Joystick et afficher sa position ------}
              {-- jusqu'… ce que les deux boutons soient appuy‚s ------}

 ClrScr;
 GotoXY( 45, 1 );
 write( 'JOYSTP - (c) 1991 MICHAEL TISCHER' );
 GotoXY( 1, 25 );
 write( 'Appuyez sur les deux boutons pour quitter le programme');

 xold := 0;                           { Pr‚d‚finir l'ancienne Position }
 yold := 0;

 repeat
   GetJoyPos( jsp[1], jsp[2] );                     { Lire la position }

    {-- Calculer la nouvelle position X du Joystick  ------------------}

   x := round(xfacteur * ( jsp[actstick].x - minx + 1 ));
   if ( x < 0 ) then
     x := 0;
   if ( x > 79 ) then
     x := 79;

    {-- Calculer la nouvelle position Y du Joystick -------------------}

   y := round(yfacteur * ( jsp[actstick].y - miny + 1 ));
   if ( y < 0 ) then
     y := 0;
   if ( y > 22 ) then
     y := 22;

    {-- Afficher la nouvelle position si celle-ci a ‚t‚ modifi‚e ------}

   if ( x <> xold ) or ( y <> yold ) then
     begin
       GotoXY( xold+1, yold+2 );
       write( ' ' );
       GotoXY( x+1, y+2 );
       write( 'X' );
       xold := x;
       yold := y;
     end;
   GotoXY( 1, 1 );
   write( '(', jsp[actstick].x:3, '/', jsp[actstick].y:3, ')' );
   GetJoyButton( j1but[1], j2but[1], j1but[2], j2but[2] );
 until ( j1but[actstick] = 1 ) and ( j2but[actstick] = 1 );
 ClrScr;
 GotoXY( 1, 1 );
 writeln( 'Fin de programme' );
end.
