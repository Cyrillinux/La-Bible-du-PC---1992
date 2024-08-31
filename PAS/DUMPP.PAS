{**********************************************************************}
{*                             D U M P P                              *}
{*--------------------------------------------------------------------*}
{*    Fonction       : un filtre qui lit des caractŠres sur l'entr‚e  *}
{*                     standard pour les ressortir sur la sortie      *}
{*                     standard sous forme de dump hexa et ASCII      *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   :  8/08/1987                                     *}
{*    DerniŠre modif.: 28/02/1992                                     *}
{*--------------------------------------------------------------------*}
{*    Infos          : Ce programme ne peut ˆtre appel‚ qu'… partir   *}
{*                     du niveau DOS aprŠs avoir ‚t‚ compil‚ par      *}
{*                     TURBO en fichier EXE                           *}
{**********************************************************************}

program DUMPP;

Uses Dos;                                         { Int‚grer unit‚ DOS }

{$V-}                           { Pas de test de la longueur de chaŒne }

const NUL = 0;                              { Code ASCII caractŠre NUL }
      BEL = 7;                                   { Code ASCII sonnerie }
      BS  = 8;                                  { Code ASCII Backspace }
      TAB = 9;                                 { Code ASCII Tabulateur }
      LF  = 10;                                 { Code ASCII Line Feed }
      CR  = 13;                           { Code ASCII Carriage Return }
      EOF = 26;                            { Code ASCII Fin de fichier }
      ESC = 27;                                    { Code ASCII Escape }

type CCText = string[3]; { sert … transmettre le nom d'un car. sp‚cial }
     DumpBf = array[1..80] of char;          { Re‡oit le dump … sortir }

{**********************************************************************}
{* CC: Ecrit le nom d'un caractŠre de commande dans un buffer         *}
{* Entr‚e : voir plus bas                                             *}
{* Sortie  : Aucune                                                   *}
{* Infos   : AprŠs appel de cette proc‚dure, le pointeur transmis     *}
{*           d‚signe le dernier caractŠre du nom de caractŠre de      *}
{*           commande dans le buffer Dump                             *}
{**********************************************************************}

procedure CC(var Buffer  : DumpBf;   { C'est ici qu'est entr‚ le texte }
                 Text    : CCText;                 { Le texte … entrer }
             var Pointer : integer);     { Adr. d‚part txt dans buffer }

var Compteur : integer;                           { Compteur de boucle }

begin
 Buffer[Pointer] := '<';               { Pr‚cŠde caractŠre de commande }

 for Compteur := 1 to length(Text) do   { Transf‚rer texte dans buffer }
  Buffer[Pointer + Compteur] := Text[Compteur];

 Buffer[Pointer + Compteur + 1] := '>'; { Fin du caractŠre de commande }
 Pointer := Pointer + Compteur + 2;        { Ptr sur caractŠre suivant }
end;

{**********************************************************************}
{* DoDump: lit les caractŠres et les sort sous forme de Dump          *}
{* Entr‚e  : Aucune                                                   *}
{* Sortie  : Aucune                                                   *}
{**********************************************************************}

procedure DoDump;

var Regs : Registers;      { Variable de registre pour appeler interr. }
    NeufOctets : array[1..9] of char;           {Re‡oit caractŠres lus }
    DumpBuf  : DumpBf;                      { Re‡oit une ligne du DUMP }
    ChHexa,
    Compteur,                                     { Compteur de boucle }
    NextA    : integer;         { Pointeur dans buffer pour code ASCII }
    Fin      : boolean;                       { Pas lu d'autre octet ? }

begin
  Fin := false;                                       { Pas encore Fin }

  repeat
    Regs.ah := $3F;           { Num‚ro de fonction pour Lecture Handle }
    Regs.bx := 0;                    { P‚riph. d'entr‚e std : Handle 0 }
    Regs.cx := 9;                                  { Lire 9 caractŠres }
    Regs.ds := seg(NeufOctets);         { Adresse de segment du buffer }
    Regs.dx := ofs(NeufOctets);           { Adresse d'offset du buffer }
    MsDos( Regs );                      { Appeler interruption DOS $21 }

    if( Regs.ax = 0 ) then
      Fin := true                               { Aucun caractŠre lu ? }
    else
      begin                                                      { NON }
        for Compteur := 1 to 30 do          { Remplir buffer d'espaces }
          DumpBuf [Compteur] := ' ';
        DumpBuf[31] := #219;        { Fixer car. s‚paration hexa/ASCII }
        NextA := 32;  { CaractŠres ASCII aprŠs caractŠre de s‚paration }

        for Compteur := 1 to Regs.ax do   { Traiter les caractŠres lus }
        begin
          ChHexa := ord(NeufOctets[Compteur]) shr 4 + 48;   { octet en }
          if( ChHexa > 57) then
            ChHexa := ChHexa + 7;                   { 1er chiffre hexa }
          DumpBuf[Compteur * 3 - 2] := chr(ChHexa);  { Sauve ds buffer }

          ChHexa := ord(NeufOctets[Compteur]) and 15 + 48;  { octet en }
          if( ChHexa > 57) then
            ChHexa := ChHexa + 7;                   { 2nd chiffre hexa }
          DumpBuf[Compteur * 3 - 1] := chr(ChHexa);  { Sauve ds buffer }

          case ord(NeufOctets[Compteur]) of        { Tester code ASCII }
            NUL : CC(DumpBuf, 'NUL', NextA);           { CaractŠre NUL }
            BEL : CC(DumpBuf, 'BEL', NextA);                { Sonnerie }
            BS  : CC(DumpBuf, 'BS' , NextA);               { Backspace }
            TAB : CC(DumpBuf, 'TAB', NextA);              { Tabulateur }
            LF  : CC(DumpBuf, 'LF' , NextA);               { Line Feed }
            CR  : CC(DumpBuf, 'CR' , NextA);         { Carriage Return }
            EOF : CC(DumpBuf, 'EOF', NextA);          { Fin de fichier }
            ESC : CC(DumpBuf, 'ESC', NextA);                  { Escape }
            else
              begin                                 { CaractŠre normal }
                DumpBuf[NextA] := NeufOctets[Compteur];  { Sauve ASCII }
                NextA := succ(NextA)       { Fixe ptr sur car. suivant }
              end
          end;
        end;

        DumpBuf[NextA] := #219;               { Fixer caractŠre de fin }
        DumpBuf[NextA+1] := chr(CR);                            { CR/LF}
        DumpBuf[NextA+2] := chr(LF);              { … la fin du buffer }
        Regs.ah := $40;      { Num‚ro de fonction pour Ecriture Handle }
        Regs.bx := 1;                  { p‚riph. sortie std : Handle 1 }
        Regs.cx := NextA+2;                     { Nombre de caractŠres }
        Regs.ds := seg(DumpBuf);        { Adresse de segment du buffer }
        Regs.dx := ofs(DumpBuf);          { Adresse d'offset du buffer }
        MsDos( Regs );                  { Appeler interruption DOS $21 }
      end;
  until Fin;     { R‚p‚ter jusqu'… ce que plus de caractŠre disponible }
end;

{**********************************************************************}
{*                        PROGRAMME PRINCIPAL                         *}
{**********************************************************************}

begin
  DoDump;                                                { Sortir Dump }
end.
