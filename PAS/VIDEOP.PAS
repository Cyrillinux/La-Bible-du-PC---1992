{**********************************************************************}
{*                            V I D E O P                             *}
{*--------------------------------------------------------------------*}
{*    Fonction      : fournit  quelques fonctions qui exploitent      *}
{*                    l'interruption vid‚o du BIOS et qui ne sont pas *}
{*                    encore int‚gr‚es dans Turbo Pascal              *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   : 10.07.1987                                     *}
{*    DerniŠre MAJ   : 14.01.1991                                     *}
{**********************************************************************}

program VIDEOP;

Uses Crt, Dos;                          { Inclut les unit‚s CTR et DOS }

const NORMAL        = $07;                     { D‚finit les attributs }
      CLAIR          = $0f;                          { pour les cartes }
      INVERSE        = $70;                        { ‚cran monochromes }
      SOULIGNE = $01;
      CLIGNOTANT       = $80;

type TextTyp = string[80];

var  i,                                   { Variables pour les boucles }
     j,
     k,
     l       : integer;
     IString : string[2];                  { Nombre de flŠches trac‚es }

{**********************************************************************}
{* GetVideoMode : D‚termine le mode vid‚o courant et divers autres    *}
{*                paramŠtres                                          *}
{* Entr‚e       : n‚ant                                               *}
{* Sorties      : Les variables cit‚es plus bas sont mises … jour     *}
{**********************************************************************}

procedure GetVideoMode(var ModeVideo,   { Num‚ro du mode vid‚o courant }
               Nombre,                  { Nombre de colonnes par ligne }
 Page       : integer);                        { page d'‚cran courante }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah := $0F;                               { Num‚ro de la fonction }
 Intr($10, Regs);             { D‚clenche l'interruption vid‚o du BIOS }
 ModeVideo := Regs.al;                          { Num‚ro du mode vid‚o }
 Nombre := Regs.ah;                   { Nombre de caractŠres par ligne }
 Page := Regs.bh;                 { Num‚ro de la page d'‚cran courante }
end;

{**********************************************************************}
{* SetCursorType : D‚finit l'aspect du curseur clignotant             *}
{* Entr‚e        : Voir plus bas                                      *}
{* Sortie        : n‚ant                                              *}
{* Info          : Les paramŠtres peuvent ˆtre compris entre 0 et 13  *}
{*                 pour une carte monochrome, 0 et 7 pour une carte   *}
{*                 couleur                                            *}
{**********************************************************************}

procedure SetCursorType(Debut,             { Ligne de d‚but du curseur }
            Fin    : integer);               { Ligne de fin du curseur }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah := 1;                                 { Num‚ro de la fonction }
 Regs.ch := Debut;            { Fixe l'extr‚mit‚ sup‚rieure du curseur }
 Regs.cl := Fin;              { Fixe l'extr‚mit‚ inf‚rieure du curseur }
 Intr($10, Regs);             { D‚clenche l'interruption vid‚o du BIOS }
end;

{**********************************************************************}
{* SetCursorPos : Fixe la position du curseur dans la page            *}
{*                d'‚cran indiqu‚e                                    *}
{* Entr‚e       : Voir plus bas                                       *}
{* Sortie       : n‚ant                                               *}
{* Info         : La position du curseur clignotant ne change …       *}
{*                l'issue de cet appel que si la page d'‚cran indiqu‚e*}
{*                est la page d'‚cran courante                        *}
{**********************************************************************}

procedure SetCursorPos(Page,                  { Page d'‚cran concern‚e }
               Colonne,                  { nouvelle colonne du curseur }
               Ligne   : integer);         { nouvelle ligne du curseur }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah := 2;                                 { Num‚ro de la fonction }
 Regs.bh := Page;                                       { Page d'‚cran }
 Regs.dh := Ligne;                              { Fixe les coordonn‚es }
 Regs.dl := Colonne;                                      { de l'‚cran }
 Intr($10, Regs);             { D‚clenche l'interruption vid‚o du BIOS }
end;

{**********************************************************************}
{* GetCursorPos : D‚termine la position du curseur dans la page       *}
{*                d'‚cran ainsi que les limites de son aspect         *}
{* Entr‚e       : Voir plus bas                                       *}
{* Sortie       : Les variables cit‚es plus bas sont mises … jour     *}
{* Info         : Les limites du curseur sont ind‚pendantes de la     *}
{*                page ‚cran indiqu‚e                                 *}
{**********************************************************************}

procedure GetCursorPos(Page : integer;                  { Page d'‚cran }
               var Colonne,                       { Colonne du curseur }
               Ligne,                               { Ligne du curseur }
               Debut,                { Extr‚mit‚ sup‚rieure du curseur }
               Fin    : integer);               { Extr‚mit‚ inf‚rieure }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah := 3;                                 { Num‚ro de la fonction }
 Regs.bh := Page;                                       { Page d'‚cran }
 Intr($10, Regs);              {D‚clenche l'interruption vid‚o du BIOS }
 Colonne := Regs.dl;                           { Pr‚lŠve les r‚sultats }
 Ligne := Regs.dh;                                { dans les registres }
 Debut := Regs.ch;                                    { et les affecte }
 Fin := Regs.cl;                                       { aux variables }
end;

{**********************************************************************}
{* SetDisplayPage : Fixe la page d'‚cran … afficher                   *}
{* Entr‚e         : Voir plus bas                                     *}
{* Sortie         : n‚ant                                             *}
{**********************************************************************}

procedure SetDisplayPage(Page : integer);      { nouvelle page d'‚cran }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah := 5;                      { Num‚ro de la fonction "Set Page" }
 Regs.al := Page;                                       { Page d'‚cran }
 Intr($10, Regs);             { D‚clenche l'interruption vid‚o du BIOS }
end;

{**********************************************************************}
{* ScrollUp : Fait d‚filer une zone d'‚cran d'une ou plusieurs        *}
{*            lignes vers le haut ou provoque son effacement          *}
{* Entr‚e   : Voir plus bas                                           *}
{* Sortie   : n‚ant                                                   *}
{* Info     : Si on prend 0 comme paramŠtre, la zone d'‚cran est      *}
{*            remplie avec des lignes vierges                         *}
{**********************************************************************}

procedure ScrollUp(Nombre,          { Nombre de lignes … faire d‚filer }
           Couleur,                 { Attribut pour les lignes vierges }
           ColonneHG,                        { Colonne coin sup gauche }
           LigneHG,                            { Ligne coin sup gauche }
           ColonneBD,                   { Colonne coin inf‚rieur droit }
           LigneBD   : integer);          { Ligne coin inf‚rieur droit }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah := 6;                                 { Num‚ro de la fonction }
 Regs.al := Nombre;                 { Nombre de lignes … faire d‚filer }
 Regs.bh := Couleur;                      { Couleur des lignes vierges }
 Regs.ch := LigneHG;         { Fixe les coordonn‚es du coin sup gauche }
 Regs.cl := ColonneHG;
 Regs.dh := LigneBD;   { Fixe les coordonn‚es du coins inf‚rieur droit }
 Regs.dl := ColonneBD;
 Intr($10, Regs);             { D‚clenche l'interruption vid‚o du BIOS }
end;

{**********************************************************************}
{* ScrollDown : Fait d‚filer une zone d'‚cran d'une ou de plusieurs   *}
{*              lignes vers le bas ou provoque son effacement         *}
{* Entr‚e     : Voir plus bas                                         *}
{* Sortie     : n‚ant                                                 *}
{* Info       : Si on prend 0 comme paramŠtre, la zone d'‚cran est    *}
{*              remplie avec des lignes vierges                       *}
{**********************************************************************}

procedure ScrollDown(Nombre,        { Nombre de lignes … faire d‚filer }
             Couleur,               { Attribut pour les lignes vierges }
             ColonneHG,                { Colonne coin sup‚rieur gauche }
             LigneHG,                    { Ligne coin sup‚rieur gauche }
             ColonneBD,                 { Colonne coin inf‚rieur droit }
             LigneBD : integer);          { Ligne coin inf‚rieur droit }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah := 7;                                 { Num‚ro de la fonction }
 Regs.al := Nombre;                 { Nombre de lignes … faire d‚filer }
 Regs.bh := Couleur;                      { Couleur des lignes vierges }
 Regs.ch := LigneHG;                            { Fixe les coordonn‚es }
 Regs.cl := ColonneHG;                      { du coin sup‚rieur gauche }
 Regs.dh := LigneBD;                            { Fixe les coordonn‚es }
 Regs.dl := ColonneBD;                       { du coin inf‚rieur droit }
 Intr($10, Regs);             { D‚clenche l'interruption vid‚o du BIOS }
end;

{**********************************************************************}
{* GetChar : Lit un caractŠre et son attribut … une position donn‚e   *}
{*           de la page d'‚cran                                       *}
{* Entr‚e  : Voir plus bas                                            *}
{* Sortie  : Voir plus bas                                            *}
{**********************************************************************}

procedure GetChar(Page,                       { Page d'‚cran concern‚e }
          Colonne,                                   { Colonne d'‚cran }
          Ligne       : integer;                       { Ligne d'‚cran }
          var Caractere : char;                         { CaractŠre et }
          var Couleur   : integer);                     { son attribut }

var Regs     : Registers;              { Registres pour l'interruption }
    ColonneCour,                                    { Colonne courante }
    LigneCour,                                        { Ligne courante }
    PageCour,                                  { Page d'‚cran courante }
    Dummy    : integer;       { pour variables accessoires ou inutiles }

begin
 GetVideoMode(Dummy, Dummy, PageCour);{D‚termine la page ‚cran courante}
 GetCursorPos(PageCour, ColonneCour, LigneCour, Dummy, Dummy);
   { lit la position courante du curseur dans la page d'‚cran courante }
 SetCursorPos(Page, Colonne, Ligne);           { Positionne le curseur }

 Regs.ah := 8;    { Num‚ro de fonction pour lire caractŠre et attribut }
 Regs.bh := Page;                                       { Page d'‚cran }
 Intr($10, Regs);             { D‚clenche l'interruption vid‚o du BIOS }
 Caractere := chr(Regs.al);                  { Code ASCII du caractŠre }
 Couleur := Regs.ah;                           { Attribut du caractŠre }
 SetCursorPos(PageCour, ColonneCour, LigneCour);
end;                       { RamŠne le curseur … son ancienne position }

{**********************************************************************}
{* WRITECHAR : Affiche un caractŠre dans une couleur donn‚e … la      *}
{*             pos. courante du curseur dans la page ‚cran indiqu‚e   *}
{* Entr‚e    : Voir plus bas                                          *}
{* Sortie    : n‚ant                                                  *}
{* Info      : Dans le traitement de l'affichage les caractŠres de    *}
{*             contr“le comme <Entr‚e> sont consid‚r‚s comme des      *}
{*             caractŠres ordinaires                                  *}
{**********************************************************************}

procedure WriteChar(Page   : integer;         { Page d'‚cran concern‚e }
                    Caractere : char;        { Code ASCII du caractŠre }
                    Couleur   : integer);               { son attribut }

var Regs : Registers;                  { Registres pour l'interruption }

begin
 Regs.ah:=9;        { Num‚ro de la fonction pour afficher un caractŠre }
 Regs.al := ord(Caractere);             { Code du caractŠre … afficher }
 Regs.bh := Page;                               { Fixe la page d'‚cran }
 Regs.bl := Couleur;                    { Fixe la couleur du caractŠre }
 Regs.cx := 1;                         { Un seul exemplaire … afficher }
 Intr($10, Regs);                     { D‚clenche l'interruption vid‚o }
end;

{**********************************************************************}
{* WriteText: Affiche une chaŒne de caractŠres … la position indiqu‚e *}
{*            de la page d'‚cran                                      *}
{* Entr‚e   : Voir plus bas                                           *}
{* Sortie   : n‚ant                                                   *}
{* Info     : Les caractŠres de contr“le (par ex <Entr‚e>) sont       *}
{*            trait‚s comme tels                                      *}
{**********************************************************************}

procedure WriteText(Page,                     { Page d'‚cran concern‚e }
                    Colonne,           { Colonne o— d‚bute l'affichage }
                    Ligne,              { Ligne, o— d‚bute l'affichage }
                    Couleur : integer;  { Couleur pour tous caractŠres }
                    Text   : TextTyp);              { Texte … afficher }

var Regs : Registers;                  { Registres pour l'interruption }
    Compteur  : integer;                       { Compteur d'it‚rations }

begin
 SetCursorPos(Page, Colonne, Ligne);           { Positionne le curseur }
 for Compteur:=1 to length(Text) do            { Traite successivement }
  begin                                    { les diff‚rents caractŠres }
   WriteChar(Page, ' ', Couleur);       { Couleur en position courante }
   Regs.ah := 14;            { Num‚ro de la fonction "sortie t‚l‚type" }
   Regs.al := ord(Text[compteur]);      { Code du caractŠre … afficher }
   Regs.bh := Page;                                     { Page d'‚cran }
   Intr($10, Regs);           { D‚clenche l'interruption vid‚o du BIOS }
  end;
end;

{**********************************************************************}
{**                      Programme principal                          *}
{**********************************************************************}

begin
 ClrScr;                                              { Efface l'‚cran }
 for i := 1 to 24 do                      { Parcourt les lignes 1 … 24 }
  for j := 0 to 79 do                         { et toutes les colonnes }
   begin
    SetCursorPos(0, j, i);                     { Positionne le curseur }
    WriteChar(0, chr(i*80+j and 255), NORMAL);  { affiche un caractŠre }
   end;
 ScrollDown(0, NORMAL, 5, 8, 19, 22);            { Efface la fenˆtre 1 }
 WriteText(0, 5, 8, INVERSE, '   Fenˆtre 1   ');
 ScrollDown(0, NORMAL, 60, 2, 74, 16);           { Efface la fenˆtre 2 }
 WriteText(0, 60, 2, INVERSE, '   Fenˆtre 2   ');
 WriteText(0, 30, 12, INVERSE or CLIGNOTANT, ' >>> BIBLE PC <<< ');
 WriteText(0, 0, 0, INVERSE, '                            Il reste '+
                         '   flŠches … tracer                        ');
 for i := 49 downto 0 do                         { 50 flŠches au total }
  begin
   Str(i:2, IString);                         { Transforme i en chaŒne }
   WriteText(0, 37, 0, INVERSE, IString);
   j := 1;                     { Chaque flŠche se compose de 16 lignes }
   while j <= 15 do
    begin
      k := 0;
      while k < j do                 { Fabrique une ligne de la flŠche }
       begin
        SetCursorPos(0, 12-(j shr 1)+k, 9);         { FlŠche fenˆtre 1 }
        WriteChar(0, '*', CLAIR);
        SetCursorPos(0, 67-(j shr 1)+k, 16);        { FlŠche fenˆtre 2 }
        WriteChar(0, '*', CLAIR);
        k := succ(k);
       end;
      ScrollDown(1, NORMAL, 5, 9, 19, 22); { Fait d‚filer la fenˆtre 1 }
      ScrollUp(1, NORMAL, 60, 3, 74, 16);  { Fait d‚filer la fenˆtre 2 }
      for l := 0 to 8000 do                         { Boucle d'attente }
       ;
      j := j+2;
    end;
  end;
 ClrScr;                                              { Efface l'‚cran }
end.
