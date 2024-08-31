{**********************************************************************}
{*                                L E D P                             *}
{*--------------------------------------------------------------------*}
{*    Fonction      : Fixe les bits de l'indicateur d'‚tat du clavier *}
{*                    du BIOS en allumant ou ‚teignant les diodes     *}
{*                    ‚lectroluminescentes                            *}
{*--------------------------------------------------------------------*}
{*    Auteur                : MICHAEL TISCHER                         *}
{*    D‚velopp‚ le          : 16.08.1988                              *}
{*    DerniŠre modification : 03.01.1992                              *}
{**********************************************************************}
                                                                        
program LEDP;
                                                                        
uses CRT,                                         { Inclut l'unit‚ CRT }
     DOS;                                         { Inclut l'unit‚ DOS }
                                                                        
const SCRL =  16;                                     { Bit Scroll-Lock}
      NUML =  32;                                        { Bit Num-Lock}
      CAPL =  64;                                       { Bit Caps-Lock}
      INS  = 128;                                          { Bit Insert}

{**********************************************************************}
{* SETFLAG : Met … 1 des bits de l'indicateur d'‚tat du clavier       *}
{* Entr‚e  : Bits … mettre … 1 ( cf constantes )                      *}
{* Sortie  : n‚ant                                                    *}
{**********************************************************************}
                                                                        
procedure SetFlag(Flag : byte);
                                                                        
var BiosTSByte : byte absolute $0040:$0017;{ Indicateur ‚tat du clavier}
    Regs       : Registers;            { Registres pour l'interruption }

begin
  BiosTSByte := BiosTSByte or Flag;        { Met … 1 les bits indiqu‚s }
  Regs.AH := 1;       { Num‚ro de la fonction : caractŠre disponible ? }
  intr($16, Regs);                           { D‚clenche l'interruption}
end;

{**********************************************************************}
{* CLRFLAG : Met … 0 des bits de l'indicateur d'‚tat du clavier       *}
{* Entr‚e  : Bits … mettre … 0 (cf constantes )                       *}
{* Sortie  : n‚ant                                                    *}
{**********************************************************************}
                                                                        
procedure ClrFlag(Flag : byte);
                                                                        
var BiosTSByte : byte absolute $0040:$0017;{ Indicateur ‚tat du clavier}
    Regs       : Registers;            { Registres pour l'interruption }

begin
  BiosTSByte := BiosTSByte and ( not Flag );        { Met … 0 les bits }
  Regs.AH := 1;       { Num‚ro de la fonction : caractŠre disponible ? }
  intr($16, Regs);                  { D‚clenche l'interruption du BIOS }
end;
                                                                        
{**********************************************************************}
{**                  PROGRAMME PRINCIPAL                             **}
{**********************************************************************}
                                                                        
var compteur : integer;
                                                                        
begin
  writeln('LEDP  -  (c) 1988, 92 by Michael Tischer');
  writeln(#13,#10, 'Observez les LEDs de votre clavier !');
                                                                        
  for compteur:=1 to 10 do                             { 10 it‚rations }
    begin
      SetFlag( CAPL);                                    { Allume CAPS }
      Delay( 100 );                                    { Attend 100 ms }
      ClrFlag( CAPL );                                   { Eteint CAPS }
      SetFlag( NUML);                                    { Allume NUM  }
      Delay( 100 );                                    { Attend 100 ms }
      ClrFlag( NUML );                                    { Eteint NUM }
      SetFlag( SCRL);                             { Allume SCROLL-LOCK }
      Delay( 100 );                                    { Attend 100 ms }
      ClrFlag( SCRL );                            { Eteint SCROLL-LOCK }
    end;
                                                                        
  for compteur:=1 to 10 do                             { 10 it‚rations }
    begin
      SetFlag(CAPL or SCRL or NUML);    { Allume les trois indicateurs }
      Delay( 500 );                                    { Attend 200 ms }
      ClrFlag(CAPL or SCRL or NUML);          { Eteint les indicateurs }
      Delay( 500 );                                    { Attend 200 ms }
    end;
end.
