{***********************************************************************
*                           I S E V P . P A S                          *
**--------------------------------------------------------------------**
*  Fonction: teste la pr‚sence d'une carte EGA ou VGA.                 *
**--------------------------------------------------------------------**
*  Auteur          : MICHAEL TISCHER                                   *
*  D‚velopp‚ le    : 05.08.1990                                        *
*  DerniŠre MAJ    : 14.01.1991                                        *
***********************************************************************}

Program IsEgaVgaP;

uses DOS;                                     { Pour les interruptions }

{-- D‚clarations de types ---------------------------------------------}

type CARTE = ( EGA_MONO, EGA_COLOR, VGA_MONO, VGA_COLOR, NINI );

{***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie : Type de carte selon le code CARTE                          *
***********************************************************************}

function IsEgaVga : CARTE;

var Regs : Registers;            { Registres pour g‚rer l'interruption }

begin
  Regs.AX := $1a00;            { La fonction 1Ah n'existe que pour VGA }
  Intr( $10, Regs );
  if ( Regs.AL = $1a ) then        { La fonction est-elle disponible ? }
    case Regs.BL of                            { Oui, exploite le code }
         4 : IsEgaVga := EGA_COLOR;
         5 : IsEgaVga := EGA_MONO;
         7 : IsEgaVga := VGA_MONO;
         8 : IsEgaVga := VGA_COLOR;
      else IsEgaVga := NINI;
    end
  else                                { Pas de VGA, mais peut-ˆtre EGA }
    begin
      Regs.ah := $12;                           { Invoque l'option 10h }
      Regs.bl := $10;                             { de la fonction 12h }
      intr($10, Regs);                            { Interruption vid‚o }
      if ( Regs.bl <> $10 ) then              { Est-ce une carte EGA ? }
        begin                         { Oui, recherche l'‚cran associ‚ }
          if Regs.BH = 0 then IsEgaVga := EGA_COLOR
                         else IsEgaVga := EGA_MONO;
        end
      else IsEgaVga := NINI;
    end;
end;

{**********************************************************************}
{--                    PROGRAMME PRINCIPAL                            *}
{**********************************************************************}

begin
  writeln( 'ISEVP  -  (c) 1990 by MICHAEL TISCHER'#13#10 );
  case IsEgaVga of
    NINI : writeln( 'La carte vid‚o active n''est ni une carte ' +
                         'EGA ni une carte VGA !');

    EGA_MONO  : writeln( 'La carte active est une carte EGA branch‚e'+
                         ' sur un ‚cran MDA.');

    EGA_COLOR : writeln( 'La carte active est une carte EGA branch‚e'+
                         ' sur un ‚cran EGA ou Multiscan .' );

    VGA_MONO  : writeln( 'La carte active est une carte VGA branch‚e'+
                         ' sur un ‚cran monochrome analogique.');

    VGA_COLOR : writeln( 'La carte active est une carte VGA branch‚e'+
                         ' sur un ‚cran VGA ou Multiscan .' );
  end;
end.
