{**********************************************************************}
{*                           M C B P . P A S                          *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Permet de suivre le chaŒnage des blocs de      *}
{*                     m‚moire allou‚s par DOS                        *}
{*--------------------------------------------------------------------*}
{*    Auteur         : Michael TISCHER                                *}
{*    D‚velopp‚ le   : 22.08.1988                                     *}
{*    DerniŠre MAJ   : 20.03.1992                                     *}
{**********************************************************************}

program MCBP;

uses DOS, CRT;                         { IntŠgre les unit‚s DOS et CRT }

type BytePtr = ^byte;                             { Pointeur sur octet }
     Zone    = array[0..1000] of byte;       { Zone qlcq de la m‚moire }
     ZonePtr = ^Zone;                              { Pointeur sur zone }
     MCB     = record                            { Memory-Control-Bloc }
         IdCode   : char;     { "M": existe un bloc qui suit, "Z": Fin }
         PSP      : word;                     { Segment du PSP associ‚ }
         Distance : word;                 { Nombre de  paragraphes - 1 }
               end;
     MCBPtr  = ^MCB;                                { Pointeur sur MCB }
     MCBPtr2 = ^MCBPtr;              { Pointeur sur un pointeur de MCB }
     HexStr  = string[4];         { M‚morise chaŒne hexa. … 4 chiffres }

var  CvHStr  : HexStr;             { M‚morise la chaŒne hexa convertie }

{**********************************************************************}
{* HexString: Transforme un nombre en chaŒne hexad‚cimale             *}
{*            … 4 positions                                           *}
{* Entr‚e : - HexVal = Valeur … convertir                             *}
{* Sortie : La chaŒne hexa .                                          *}
{**********************************************************************}

function HexString( HexVal : word ) : HexStr;

var compteur,                                  { Compteur d'it‚rations }
    Nibble  : byte;                       { Quartet inf‚rieur d'un mot }

begin
  CvHStr := 'xxxx';                                   { Cr‚e la chaŒne }
  for compteur:=4 downto 1 do               { Parcourt ses 4 positions }
    begin
      Nibble := HexVal and $000f;    { Ne prend en cmpt que 4 bits sup }
      if( Nibble > 9 ) then                       { Chiffre = lettre ? }
        CvHStr[ compteur ] := chr(Nibble - 10 + ord('A'))        { Oui }
      else                                      { Chiffre entre 0 et 9 }
        CvHStr[ compteur ] := chr(Nibble + ord('0'));
      HexVal := HexVal shr 4;
    end;
  HexString := CvHStr;                    { Transmet la chaŒne trouv‚e }
end;

{**********************************************************************}
{* FirstMCB: Retourne un pointeur sur le premier MCB.                 *}
{* Entr‚e  : n‚ant                                                    *}
{* Sortie : Pointeur sur le premier MCB                               *}
{**********************************************************************}

function FirstMCB : MCBPtr;

var Regs : Registers;         { Registres pour g‚rer les interruptions }

begin
  Regs.ah := $52;           { Fonction: Lit l'adresse du DOS-Info-Bloc }
  MsDos( Regs );                { D‚clenche l'innterruption $21 de DOS }

{*-- ES:(BX-4) pointe sur le premier  MCB, forme le pointeur ---------*}

  FirstMCB := MCBPtr2( ptr( Regs.ES-1, Regs.BX+12 ) )^;
end;

{**********************************************************************}
{* Dump: Affiche le dump hexa et ASCII d'une zone de m‚moire          *}
{* Entr‚e : - DPtr  = Pointeur sur la zone … dumper.                  *}
{*          - Nbr   = Nombre de lignes de 16 octets … dumper          *}
{* Sortie : n‚ant                                                     *}
{**********************************************************************}

procedure Dump( DPtr : ZonePtr; Nbr : byte);

type HBStr = string[2];         { M‚morise un nombre hexa … 2 chiffres }

var  Offset,                          { Offset dans la zone de m‚moire }
     Z       : integer;                                     { Compteur }
     HexStr  : HBStr;           { M‚morise un nombre hexa pour le dump }

procedure HexByte( HByte : byte );

begin
  HexStr[1] := chr( (HByte shr 4) + ord('0') );      { Premier chiffre }
  if HexStr[1] > '9' then                        { Est-ce une lettre ? }
    HexStr[1] := chr( ord(HexStr[1]) +  7 );                     { Oui }
  HexStr[2] := chr( (HByte and 15) + ord('0') );    { DeuxiŠme chiffre }
  if HexStr[2] > '9' then                        { Est-ce une lettre ? }
    HexStr[2] := chr( ord(HexStr[2]) +  7 );                     { Oui }
end;

begin
  HexStr := 'zz';                                { Cr‚e la chaŒne hexa }
  writeln;
  write('DUMP ³ 0123456789ABCDEF        00 01 02 03 04 05 06 07 08');
  writeln(' 09 0A 0B 0C 0D 0E 0F');
  write('ÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
  writeln('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
  Offset := 0;              { Commence par le premier octet de la zone }
  while Nbr>0 do                         { Parcourt la boucle Nbr fois }
    begin
      write(HexString(Offset), ' ³ ');
      for Z:=0 to 15 do                   { Traite 16 octets … la fois }
        if(Dptr^[Offset+Z] >= 32) then             { ASCII ordinaire ? }
          write( chr(Dptr^[Offset+Z]) )               { Oui, l'affiche }
        else                                                     { Non }
          write(' ');      { A la place du caractŠre affiche un espace }
      write('        '); { Place le curseur sur la partie hexad‚cimale }
      for Z:=0 to 15 do                             { Traite 16 octets }
        begin
           HexByte( Dptr^[Offset+Z] );            { Conversion en hexa }
           write(HexStr, ' ');                { Affiche la chaŒne hexa }
        end;
      writeln;
      Offset := Offset + 16;               { Offset sur ligne suivante }
      Dec( Nbr );           { D‚cr‚mente le nombre de lignes restantes }
    end;
  writeln;
end;

{**********************************************************************}
{* TraceMCB: Suit la chaŒne des blocs MCB.                            *}
{* Entr‚e  : n‚ant                                                    *}
{* Sortie  : n‚ant                                                    *}
{**********************************************************************}

procedure TraceMCB;

const ComSpec : array[0..7] of char = 'COMSPEC=';

var  ActMCB   : MCBPtr;
     Fin      : boolean;
     Touche   : char;
     NrMCB,                                    { Num‚ro du MCB examin‚ }
     Z        : integer;                                    { Compteur }
     MemPtr   : ZonePtr;

begin
  Fin    := false;
  NrMCB  := 1;                      { Le premier MCB porte le numero 1 }
  ActMCB := FirstMCB;                { Lit le pointeur sur premier MCB }
  repeat                                              { Suit la chaŒne }
    if ActMCB^.IdCode = 'Z' then               { Dernier MCB atteint ? }
      Fin := true;                                               { Oui }
    writeln('Num‚ro du MCB = ', NrMCB);
    writeln('Adresse du MCB= ', HexString(seg(ActMCB^)), ':',
                                HexString(ofs(ActMCB^)) );
    writeln('Adr. M‚moire  = ', HexString(succ(seg(ActMCB^))), ':',
                                HexString(ofs(ActMCB^)) );
    writeln('ID            = ', ActMCB^.IdCode);
    writeln('Adresse du PSP= ', HexString(ActMCB^.PSP), ':0000');
    writeln('Taille        = ', ActMCB^.Distance, ' paragraphes ',
        '( ', longint(ActMCB^.Distance) shl 4, ' octets)');
    write  ('Contenu       = ');

             {*-- Est-ce un environnement  ? -------------------------*}

    Z      := 0;              { Commence l'examen par le premier octet }
    MemPtr := ZonePtr(ptr(Seg(ActMCB^)+1, 0));     { Ptr sur m‚m. vive }
    while( (Z<=7) and (ord(ComSpec[Z]) = MemPtr^[Z]) ) do
      Inc(Z);                                { Z sur caractŠre suivant }
    if Z>7 then                         { A-t-on d‚couvert la chaŒne ? }
      begin                        { Oui, il s'agit d'un environnement }
        writeln('Environnement');
        MemPtr := ZonePtr(ptr(Seg(ActMCB^)+1, 0));
        if Lo(DosVersion) >= 3 then         { DOS 3.0 ou post‚rieure ? }
        begin                         { Oui, donne le nom du programme }
          write('Nom du progr  = ');
          Z := 0;                       { Commence par le premier octet}
          while not( (MemPtr^[Z]=0) and (MemPtr^[Z+1]=0) ) do
          Inc( Z );                              { Cherche chaŒne vide }
          if( MemPtr^[Z+2]=1 ) and ( MemPtr^[Z+3]=0 ) then
            begin                          { Voici un nom de programme }
              Z := Z + 4;                      { Z sur le d‚but du nom }
              repeat                    { Parcourt le nom du programme }
                write( chr(MemPtr^[Z]) );       { Affiche un caractŠre }
                Inc( Z );                { Traite le caractŠre suivant }
              until ( MemPtr^[Z]=0 );    { Jusqu'… la fin de la chaŒne }
              writeln;
            end
          else                 { Nom du programme impossible … trouver }
            writeln('inconnu');
        end;

        {*-- AFfiche les chaŒnes de l'environnement ------------------*}

        writeln(#13,#10, 'ChaŒnes de l''environnement');
        Z := 0;     { Commence par le premier octet de la zone allou‚e }
        while MemPtr^[Z]<>0 do            { r‚pŠte jusqu'… chaŒne vide }
        begin
          write('      ');
          repeat                                   { Affiche un chaŒne }
            write( chr(MemPtr^[Z]) );            { Affiche un caractŠre}
            Inc( Z );                     { Traite le caractŠre suivant}
          until MemPtr^[Z]=0;                       { Fin de la chaŒne }
          Inc( Z );             { Passe au d‚but de la chaŒne suivante }
          writeln;                                  { Termine la ligne }
        end
      end
    else                                         { Pas d'environnenent }
      begin
        {*-- S'agit-il d'un PSP ? ------------------------------------*}
        {*-- (introduit par la commande INT 20 (Code=$CD $20) ) ------*}

        MemPtr := ZonePtr(ptr(seg(ActMCB^)+1, 0));         { Init. ptr }
        if( (MemPtr^[0]=$CD) and (MemPtr^[1]=$20) ) then
                                                   { c'est bien un PSP }
          writeln('PSP (suivi d''un programme)')
        else             { La commande INT 20 n'a pas pu ˆtre d‚tect‚e }
          begin
            writeln('non identifiable (Programme ou donn‚es)');
            Dump( MemPtr, 5);        { Effectue un dump de 5*16 octets }
          end;
      end;

    write('ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ');
    writeln('ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ Appuyez sur une toucheÍÍ');
    if( not Fin ) then
      begin                                 { Pointeur sur MCB suivant }
        ActMCB := MCBPtr(ptr(seg(ActMCB^) + ActMCB^.Distance + 1, 0));
        Inc(NrMCB);                      { Incr‚mente le num‚ro du MCB }
        Touche := ReadKey;
      end;
  until( Fin )                 { r‚pŠte op‚ration jusqu'au dernier MCB }
end;

{**********************************************************************}
{**                           PROGRAMME PRINCIPAL                    **}
{**********************************************************************}

begin
  ClrScr;                                             { Efface l'‚cran }
  writeln( 'MCBP  -  (c) 1988, 92 by Michael TISCHER' );
  writeln;
  writeln;
  TraceMCB;                               { Parcourt la chaŒne des MCB }
end.
