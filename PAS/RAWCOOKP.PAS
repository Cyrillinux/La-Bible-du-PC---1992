{**********************************************************************}
{*                         R A W _ C O O K P                          *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Offre deux fonctions permettant de faire       *}
{*                     passer un driver de p‚riph‚rique de caractŠre  *}
{*                     en mode RAW ou en mode COOKED.                 *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   : 16/08/1987                                     *}
{*    DerniŠre modif.: 28/03/1992                                     *}
{**********************************************************************}

program RAWCOOKP;

Uses Crt, Dos;                            { Int‚grer unit‚s CRT et DOS }

const ENTSTAND = 0;                  { handle 0 : p‚riph. d'entr‚e std }
      SORSTAND = 1;                 { handle 1 : p‚riph. de sortie std }

var Touche : char;     { Sert uniquement au programme de d‚monstration }

{**********************************************************************}
{* GetMode: lit l'attribut d'un driver de p‚riph‚rique                *}
{* Entr‚e : le handle transmis doit ˆtre reli‚ au p‚riph‚rique …      *}
{*          appeler                                                   *}
{* Sortie : L'attribut de p‚riph‚rique                                *}
{**********************************************************************}

function GetMode(Handle : integer) : integer;

var Regs : Registers;                    { Reg. d'appel d'interruption }

begin
 Regs.ah := $44;             { Num‚ro de fonction pour IOCTL: Get Mode }
 Regs.bx := Handle;
 MsDos( Regs );                      { Appeler interruption du DOS $21 }
 GetMode := Regs.dx             { Transmettre attribut de p‚riph‚rique }
end;

{**********************************************************************}
{* SetRaw: fait passer un driver de p‚riph‚rique en mode RAW          *}
{* Entr‚e : le handle transmis doit ˆtre reli‚ au p‚riph‚rique …      *}
{*          appeler.                                                  *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure SetRaw(Handle : integer);

var Regs : Registers;                    { Reg. d'appel d'interruption }

begin
 Regs.ax := $4401;           { Num‚ro de fonction pour IOCTL: Set Mode }
 Regs.bx := Handle;
 Regs.dx := GetMode(Handle) and 255 or 32;      { Nvl attr. de p‚riph. }
 MsDos( Regs );                      { Appeler interruption du DOS $21 }
end;

{**********************************************************************}
{* SetCooked: fait passer un driver de caractŠre en mode COOKED       *}
{* Entr‚e : le handle transmis doit ˆtre reli‚ au p‚riph‚rique …      *}
{*          appeler.                                                  *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure SetCooked(Handle : integer);

var Regs : Registers;                    { Reg. d'appel d'interruption }

begin
 Regs.ax := $4401;           { Num‚ro de fonction pour IOCTL: Set Mode }
 Regs.bx := Handle;
 Regs.dx := GetMode(Handle) and 223;      { Nouvel attribut de p‚riph. }
 MsDos( Regs );                      { Appeler interruption du DOS $21 }
end;

{**********************************************************************}
{* SortieTest: sort une chaŒne de test 1000 fois sur le p‚riph‚rique  *}
{*             de sortie standard                                     *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure SortieTest;

var Regs     : Registers;                { Reg. d'appel d'interruption }
    Compteur : integer;                           { Variable de boucle }
    Test     : string[9];                 { La chaŒne de test … sortir }

begin
 Test    := 'Test.... ';
 Regs.bx := SORSTAND;  { Sortir sur le p‚riph‚rique de sortie standard }
 Regs.cx := 9;                                  { Nombre de caractŠres }
 Regs.ds := Seg(Test);                   { Adresse de segment du texte }
 Regs.dx := Ofs(Test)+1;                   { Adresse d'offset du texte }
 for Compteur := 1 to 1000 do             { Sortir la chaŒne 1000 fois }
  begin
    Regs.ah := $40;            { Num‚ro de fonction pour ‚crire handle }
    MsDos( Regs );                   { Appeler interruption du DOS $21 }
   end;
  writeln;
end;

{**********************************************************************}
{*                         PROGRAMME PRINCIPAL                        *}
{**********************************************************************}

begin
  ClrScr;                                                { Vider ‚cran }
  writeln('RAWCOOKP (c) 1987, 92 by Michael Tischer'#13#10);
  writeln('Le driver de console est maintenant en mode RAW.',
          ' Les touches de commande,');
  writeln('comme <CTRL-S> par exemple ne seront pas identifi‚es lors',
           ' de la sortie.'#13#10'Faites-en donc l''essai pendant les',
           ' sorties suivantes !');
  writeln('Veuillez frapper une touche pour commencer...');
  Touche := ReadKey;                             { Attendre une touche }

  SetRaw(ENTSTAND);       { Faire passer driver de console en mode RAW }
  SortieTest;                        { Sortir chaŒne de test 1000 fois }

  ClrScr;                                              { Vider l'‚cran }
    while KeyPressed do                      { Vider le buffer clavier }
    Touche := ReadKey;                                   { Lire touche }
  writeln('Le driver de console se trouve maintenant en mode COOKED.');
  writeln('Les touches de commande comme <CTRL-S> par exemple sont');
  writeln('identifi‚es lors de la sortie et trait‚es en cons‚quence.');
  writeln('Veuillez frapper une touche pour commencer...');

  Touche := ReadKey;                             { Attendre une touche }
  SetCooked(ENTSTAND);            { Faire passer driver en mode COOKED }
  SortieTest;                     { Sortir la chaŒne de test 1000 fois }
end.
