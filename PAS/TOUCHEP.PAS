{**********************************************************************}
{*                           T O U C H E P                            *}
{*--------------------------------------------------------------------*}
{*  Fonction: Impl‚mente une fonction qui permet de lire un caractŠre *}
{*            au clavier en affichant l'‚tat des touches de bascule   *}
{*            INSERT, CAPS et NUM                                     *}
{*                                                                    *}
{*--------------------------------------------------------------------*}
{*    Auteur                : MICHAEL TISCHER                         *}
{*    D‚velopp‚ le          :  8.07.1987                              *}
{*    DerniŠre modification :  1.01.1992                              *}
{**********************************************************************}

program TASTP;

Uses Crt, Dos;                         { Inclut les unit‚s Crt et Dos  }

{$V-}                  { Exclut le contr“le de la longueur des chaŒnes }

type FlagText = string[6]; { Pour transmettre les noms des indicateurs }


const FL      = 1;                 { Ligne d'affichage des indicateurs }
      FC      = 65;              { Colonne d'affichage des indicateurs }
      FlagCara = 0;                           { Couleur des caractŠres }
      FlagFond = 7;                  { Couleur de fond des indicateurs }


      {** Disposition des bits dans la variable d'‚tat du clavier *****}
      SCRL =  16;                                         { Scroll-Lock}
      NUML =  32;                                           { Num-Lock }
      CAPL =  64;                                          { Caps-Lock }
      INS  = 128;                                             { Insert }

      {** Quelques codes de touche retourn‚s par GETKEY ****************}
      BEL     = 7;                             { Code du signale sonore }
      BS      = 8;                        { Code de la touche Backspace }
      TAB     = 9;                    { Code de la touche de tabulation }
      LF      = 10;                        { Code de la touche Linefeed }
      CR      = 13;                          { Code de la touche Entr‚e }
      ESC     = 27;                   { Code de la touche d'‚chappement }
      F1      = 315;                              { Touches de fonction }
      F2      = 316;
      F3      = 317;
      F4      = 318;
      F5      = 319;
      F6      = 320;
      F7      = 321;
      F8      = 322;
      F9      = 323;
      F10     = 324;
      CUP     = 328;                            { Touches de direction }
      CLEFT   = 331;
      CRIGHT  = 333;
      CDOWN   = 328;

var Insert,                               { Etat de l'indicateur INSERT}
    Num,                                    { Etat de l'indicateur NUM }
    Caps     : boolean;                    { Etat de l'indicateur CAPS }
    CoulCara,                          { Couleur de caractŠre courante }
    CoulFond,                               { Couleur de fond courante }
    Touche    : integer;                       { Code de la touche lue }

{**********************************************************************}
{* NegFlag: Inverse un flag si n‚cessaire et affiche le texte associ‚ *}
{* Entr‚es: cf infra                                                  *}
{* Sortie : Nouvel ‚tat de l'indicateur (true=actif, false=inactif)   *}
{**********************************************************************}

function NegFlag(Flag   : boolean;      { dernier ‚tat de l'indicateur }
                 FlagReg, { ‚tat courant de l'indicateur (0 = inactif) }
                 Colonne, { Colonne d'affichage du nom de l'indicateur }
                 ligne  : integer;       { Ligne d'affichage du nom ...}
                 Texte   : FlagText) : boolean;  { Nom de l'indicateur }

var LigneCour,                                        { Ligne courante }
    ColCour : integer;                              { Colonne courante }

begin
 if (Flag and (FlagReg = 0)) or                      { Teste si l'‚tat }
    (not(Flag) and (FlagReg <> 0)) then     { de l'indicateur a chang‚ }
  begin                                                          { OUI }
   LigneCour := WhereY;                      { M‚morise ligne courante }
   ColCour := WhereX;                            { et colonne courante }
   gotoxy(Colonne, ligne);                   { Repositionne le curseur }
   if FlagReg = 0 then                   { L'indicateur est il inactif }
    begin                                                        { OUI }
     NegFlag := false;                        { R‚sultat de la fontion }
     TextColor( Black );               { Couleur des caractŠres = noir }
     TextBackground( Black );                            { Fond = noir }
    end
   else
    begin                                           { Indicateur actif }
     NegFlag:=true;                          { R‚sultat de la fonction }
     TextColor(FlagCara);          { Couleur des caractŠres = FLAGCARA }
     TextBackground(FlagFond)             { Couleur de fond = FLAGFOND }
    end;
   write(Texte);                      { Affiche le nom de l'indicateur }
   GotoXY(ColCour, LigneCour);               { Repositionne le curseur }
   TextColor(CoulCara);           { R‚tablit la couleur des caractŠres }
   TextBackground(CoulFond)              { R‚tablit la couleur de fond }
  end
  else
   NegFlag := Flag                     { Etat de l'indicateur inchang‚ }
end;

{**********************************************************************}
{* GetKey : Lit un caractŠre et affiche l'‚tat des indicateurs        *}
{* Entr‚e : n‚ant                                                     *}
{* Sortie : Code de la touche frapp‚e < 256 : touche ordinaire        *}
{*                                   >= 256 : touche ‚tendue          *}
{**********************************************************************}

function GetKey : integer;

var Regs        : Registers;           { Registres pour l'interruption }
    TouchePrete : boolean;                 { Indique si touche frapp‚e }

begin
 TouchePrete := false;                         { Pas de touche frapp‚e }
 repeat
  Regs.ah := $2;      { Num‚ro de la fonction "Lire l'‚tat du clavier "}
  intr($16, Regs );         { D‚clenche l'interruption clavier du BIOS }

  {** Ajuste les indicateurs en fonction du nouvel ‚tat du clavier   **}
  Insert := NegFlag(Insert, Regs.al and INS, FC+9, FL, 'INSERT');
  Caps := NegFlag(Caps, Regs.al and CAPL, FC+3, FL, ' CAPS ');
  Num := NegFlag(Num, Regs.al and NUML, FC, FL, 'NUM');
  Regs.ah := $1;           { Num‚ro de la fonction "Touche frapp‚e ? " }
  intr($16, Regs);          { D‚clenche l'interruption clavier du BIOS }
  if (Regs.flags and FZero = 0) then        { Indicateur de z‚ro … 1 ? }
   begin                                       { OUI (Touche frapp‚e ) }
    TouchePrete := true;                               { Lit la touche }
    Regs.ah := 0;            { Num‚ro de la fonction "Lire une touche" }
    intr($16, Regs );          { Apelle l'interruption clavier du BIOS }
    if (Regs.al = 0)                     { Est-ce une touche ‚tendue ? }
     then GetKey := Regs.ah or $100                              { Oui }
     else GetKey := Regs.al;                                     { Non }
   end;
 until TouchePrete;   { R‚pŠte l'op‚ration jusqu'… frappe d'une touche }
end;

{**********************************************************************}
{* IniKey : Initialise les indicateurs des touches                    *}
{* Entr‚e : n‚ant                                                     *}
{* Sortie : n‚ant                                                     *}
{* Info   : Les indicateurs sont invers‚s par rapport … leur ‚tat     *}
{*          actuel pour que ce dernier puisse ˆtre affich‚ au         *}
{*          prochain appel de GETKEY                                  *}
{**********************************************************************}

procedure IniKey;

var Regs        : Registers;           { Registres pour l'interruption }

begin
 Regs.ah := $2;        { Num‚ro de la fonction "Lire l'‚tat du clavier"}
 intr($16, Regs );          { D‚clenche l'interruption clavier du BIOS }
 if (Regs.al and INS <> 0) then Insert := false    { Fixe l'indicateur }
                           else Insert := true;                 {INSERT}
 if (Regs.al and CAPL <> 0) then Caps := false     { Fixe l'indicateur }
                            else Caps := true;                  { CAPS }
 if (Regs.al and NUML <> 0) then Num := false      { Fixe l'indicateur }
                            else Num := true                { NUM LOCK }
end;

{**********************************************************************}
{* Couleur : Fixe les couleurs des car. et du fond pour l'affichage   *}
{* Entr‚e  : cf infra                                                 *}
{* Sortie  : n‚ant                                                    *}
{* Var.    : Les couleurs sont m‚moris‚es par les variables COULFOND  *}
{*           et COULCARA                                              *}
{* Info    : Cette proc‚dure doit ˆtre appel‚e pour qu'… l'issue      *}
{*           d'un affichage de l'‚tat des indicateurs la couleur des  *}
{*           caractŠres courante puisse ˆtre restaur‚e. Turbo Pascal  *}
{*           ne dispose pas d'un fonction qui permette de lire cette  *}
{*           couleur                                                  *}
{**********************************************************************}

procedure Couleur(PremierPlan, ArrierePlan : integer);

begin
 CoulCara := PremierPlan;         { m‚morise la couleur des caractŠres }
 CoulFond := ArrierePlan;                { M‚morise la couleur du fond }
 TextColor(PremierPlan);              { Fixe la couleur des caractŠres }
 TextBackground(ArrierePlan)                 { Fixe la couleur du fond }
end;

{**********************************************************************}
{*                            PROGRAMME PRINCIPAL                     *}
{**********************************************************************}

begin
 IniKey;                                  { Initialise les indicateurs }
 Couleur(7,0);                                { Couleur = blanc / noir }
 ClrScr;                                              { Efface l'‚cran }
 writeln(#13#10'TOUCHEP (c) 1987, 92 by Michael Tischer');
 writeln(#13#10'Tapez quelques caractŠres en activant ou d‚sactivant'+
        #13#10'les touches INSERT, CAPS ou NUM');
 writeln('L''‚tat de ces touches va ˆtre affich‚ en permanence ');
 writeln('dans le coin sup‚rieur gauche de l''‚cran.');
 writeln('Pour sortir du programme tapez <Entr‚e> ou <F1>');
 write(#13#10'Votre saisie : ');
 repeat                                             { Boucle de saisie }
  Touche := GetKey;  { Lit une touche }
  if (Touche < 256) then write(chr(Touche))        { Affiche la touche }
 until (Touche = CR) or (Touche = F1);                { (si ordinaire) }
                           { R‚pŠte l'op‚ration jusqu'… F1 ou <Entr‚e> }
  writeln;
end.
