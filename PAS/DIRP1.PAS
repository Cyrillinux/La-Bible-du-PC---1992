{**********************************************************************}
{*                          D I R P 1 . P A S                         *}
{*--------------------------------------------------------------------*}
{*    Fonction        : Affiche tous les fichiers d'un r‚pertoire     *}
{*                     quelconque y compris les sous-r‚pertoires et   *}
{*                     noms de volumes sur l'‚cran.                   *}
{*                     La demande s'effectue … travers les deux       *}
{*                     fonctions DOS $4E et $4F.                      *}
{*                     Reportez-vous ‚galement au programme           *}
{*                     DIRP2.PAS.                                     *}
{*--------------------------------------------------------------------*}
{*    Auteur          : MICHAEL TISCHER                               *}
{*    D‚velopp‚ le    :  8.07.1988                                    *}
{*    DerniŠre modif. : 15.03.1992                                    *}
{**********************************************************************}

program DIRP1;

Uses Crt, Dos;                         { Ins‚rer les unit‚s CRT et DOS }

{-- D‚clarations de type ----------------------------------------------}

type DirBufTyp = record     { Structure de donn‚es des fonc.$4E et $4F }
                   Reserve    : array [1..21] of char;
                   Attr       : byte;
                   Time       : integer;
                   Date       : integer;
                   Size       : longint;
                   Name       : array [1..13] of char
                 end;

     MonVec    = array[1..12] of string[3]; {Tableau contenant les mois}

{-- Constantes --------------------------------------------------------}

const FA_ReadOnly  = $01;                       { Attributs de fichier }
      FAHidden     = $02;
      FA_SysFile   = $04;
      FA_VolumeID  = $08;
      FA_Directory = $10;
      FA_Archive   = $20;
      FA_AnyFile   = $3F;

      EINTR = 14;       { Autant d'entr‚es sont visibles simultan‚ment }
      Mois : MonVec = ( 'Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');



{**********************************************************************}
{* FindFirst: Lire la premiŠre entr‚e de r‚pertoire                   *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : TRUE ou FALSE, selon qu'une entr‚e a ‚t‚ trouv‚e          *}
{*           ou non                                                   *}
{**********************************************************************}

function FindFirst(NomFichier : string;        { Fichiers … rechercher }
                   Attribut  : integer) : boolean; {Attribut recherch‚ }

var Regs : Registers;
                 { Registres du processeur pour l'appel d'interruption }

begin
  NomFichier := NomFichier + #0;         { Terminer NomFichier par NUL }
  Regs.ah := $4E;           { Num‚ro de fonction pour Search for first }
  Regs.cx := Attribut;                          { Attributs recherch‚s }
  Regs.ds := Seg(NomFichier);     {Adresse de segment du nom de fichier}
  Regs.dx := succ(Ofs(NomFichier)); {Adresse d'offset du nom de fichier}
  MsDos( Regs );

                                      { Appeler l'interruption DOS $21 }
  FindFirst := ( (Regs.flags and 1) = 0 )          { Tester Flag Carry }
end;

{**********************************************************************}
{* FindNext: Lire l'entr‚e de r‚pertoire suivante                     *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : true ou false selon qu'une entr‚e a ‚t‚ trouv‚e           *}
{*             ou non                                                 *}
{* Infos    : Cette fonction ne peut ˆtre appel‚e que si l'appel de   *}
{*           FinFirst a abouti                                        *}
{**********************************************************************}

function FindNext : boolean;

var Regs : Registers;
                  { Registres du processeur pour l'appel d'interruption}

begin
  Regs.ah := $4F;            { Num‚ro de fonction pour Search for next }
  MsDos( Regs );                      { Appeler l'interruption DOS $21 }
  FindNext := ( (Regs.flags and 1) = 0 )           { Tester Flag Carry }
end;

{**********************************************************************}
{* SetDTA: Sp‚cifie l'adresse de DTA                                  *}
{* Entr‚e : SEGMENT = Adresse de segment du nouveau DTA               *}
{*           OFFSET  = Adresse d'offset du nouveau DTA                *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure SetDTA(Segment,           {Nouvelle adresse de segment du DTA}
                 Offset  : integer);  {Nouvelle adresse d'offset du DTA}

var Regs : Registers;
                 { Registres du processeur pour l'appel d'interruption }

begin
  Regs.ah := $1A;        { Sp‚cifier le num‚ro de fonction pour le DTA }
  Regs.ds := Segment;         { Adresse de segment dans le registre DS }
  Regs.dx := Offset;            { Adresse d'offset dans le registre DX }
  MsDos( Regs );                      { Appeler l'interruption DOS $21 }
end;

{**********************************************************************}
{* PRINTDATA: Afficher les informations … propos d'une entr‚e         *}
{* Entr‚e : DIRBUF = Structure de donn‚es avec informations de fichier*}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure PrintData( DirBuf : DirBufTyp );

var Compteur : byte;

begin
  writeln;          { Fait avancer la fenˆtre d'une ligne vers le haut }

  Compteur := 1;             { Commencer par la premiŠre lettre du nom }
  while (DirBuf.Name[Compteur]<>#0) do           { R‚p‚ter jusqu'… NUL }
   begin
    write(DirBuf.Name[Compteur]);     { Afficher les caractŠres du nom }
    Compteur := succ(Compteur)          { Traiter le caractŠre suivant }
   end;

  GotoXY(13, EINTR);
  write('³', DirBuf.Size:7);
  GotoXY(21, EINTR);
  write('³ ', DirBuf.Date and 31:2,' ');          { D‚terminer le jour }
  write (Mois[DirBuf.Date shr 5 and 15]);           { Afficher le mois }
  write(DirBuf.Date shr 9 + 1980:5);              { D‚terminer l'ann‚e }
  GotoXY(34, EINTR);
  write('³  ', DirBuf.Time shr 11:2, 'h');        { D‚terminer l'heure }
  write(DirBuf.Time shr 5 and 63:2);            { D‚terminer la minute }

  GotoXY(44, EINTR);
  write('³');            { Trait de s‚paration avec le champ pr‚c‚dent }
  Compteur := 1;                              { Afficher les attributs }
  while ( Compteur < 32 ) do
    begin
      if (DirBuf.Attr and Compteur) <> 0 then write('X')
                                             else write(' ');
      Compteur := Compteur shl 1;
    end;
  write('º');                         { C“t‚ droit du cadre de fenˆtre }
end;

{**********************************************************************}
{* ConfigEcran: Configure l'‚cran pour la sortie                      *}
{*                   du r‚pertoire                                    *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure ConfigEcran;

var Compteur : integer;                           { Compteur de boucle }

begin
 ClrScr;                                             { Effacer l'‚cran }
 Window(14,(20-EINTR) shr 1+1,64,(20-EINTR) shr 1 +5+EINTR);
 GotoXY(1,1);    { Curseur dans le coin sup‚rieur gauche de la fenˆtre }

 write('ÉÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍ»');
 write('º Nom        ³ Taille³   Date     ³  Heure  ³RHSVDº');
 write('ÇÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄ¶');

 for Compteur := 1 to EINTR do
  write('º            ³       ³            ³         ³     º');
 write('ÈÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍ¼');

 Window(15,(20-EINTR) shr 1+4,66,(20-EINTR) shr 1 +3+EINTR);
 GotoXY(1, EINTR);          { Curseur dans coin sup. gauche de fenˆtre }
end;

{**********************************************************************}
{* Dir: Contr“le la lecture et la sortie du r‚pertoire                *}
{* Entr‚e : CHEMIN     = Chemin de recherche avec masque de fichier   *}
{*           ATTRIBUT = Attribut de recherche                         *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure Dir( CHEMIN : string; Attr : byte );

var NbEntrees,                     { Nombre total des entr‚es trouv‚es }
    NbImage      : integer;            { Nombre d'entr‚es dans l'image }
    Touche        : char;     { Sert … attendre l'appui sur une touche }
    DirBuf       : DirBufTyp;                  { Re‡oit une entr‚e Dir }

begin
  SetDTA(Seg(DirBuf), Ofs(DirBuf));        { DirBuf est le nouveau DTA }
  clrscr;                                            { Effacer l'‚cran }
  ConfigEcran;       { Construire l'‚cran pour la sortie du r‚pertoire }

  NbImage := -1; { Aucune entr‚e n'est encore affich‚e dans la fenˆtre }
  NbEntrees := 0;                 { Aucune entr‚e n'est encore trouv‚e }
  if FindFirst( CHEMIN, Attr ) then    { Rechercher la premiŠre entr‚e }
    repeat
      NbEntrees := succ(NbEntrees);         { Une autre entr‚e trouv‚e }
      NbImage := succ(NbImage);     { Une autre entr‚e dans la fenˆtre }
      if NbImage = EINTR then            { La fenˆtre est-elle pleine? }
        begin                                                    { OUI }
          Window( 14, (20-EINTR) shr 1 + 5+ EINTR,
                  66 ,(20-EINTR) shr 1 + 6+ EINTR );
          GotoXY(1, 1);           { Curseur dans ligne inf. de fenˆtre }
          TextBackground( LightGray );                    { Fond blanc }
          TextColor( Black );                         { Ecriture noire }
          write('          Veuillez appuyer sur une touche          ');
          Touche := ReadKey;                          { Lire la touche }
          GotoXY(1, 1);     { Curseur dans coin sup. gauche de fenˆtre }
          TextBackground( Black );                         { Fond noir }
          TextColor( LightGray );                  { Ecriture en blanc }
          write('                                                   ');
          Window(15,(20-EINTR) shr 1+4,65,(20-EINTR) shr 1 +3+EINTR);
          GotoXY(1, EINTR);       { Replacer curseur sur anc. position }
          NbImage := 0;                      { Reprendre le calcul … 0 }
        end;
      PrintData( DirBuf );          { Afficher les donn‚es de l'entr‚e }
    until not(FindNext);                 { Y a-t-il une autre entr‚e ? }

  Window(14,(20-EINTR) shr 1 +5+EINTR,65,(20-EINTR) shr 1 +6+EINTR);
  GotoXY(1, 1);  { Curseur dans le coin sup‚rieur gauche de la fenˆtre }
  TextBackground( LightGray );                            { Fond blanc }
  TextColor( Black );                                 { Ecriture noire }
  write('                                                   ');

  GotoXY(2, 1);
  case NbEntrees of
    0 : write('Aucun fichier trouv‚');
    1 : write('Un fichier trouv‚');
    else write(NbEntrees,' Fichiers trouv‚s')
  end;

 Window(1, 1, 80, 25);        { Reconfigurer l'‚cran comme une fenˆtre }
end;

{**********************************************************************}
{**                           PROGRAMME PRINCIPAL                    **}
{**********************************************************************}

begin
  case ParamCount of        { R‚agir en fonction du nombre d'arguments }
    0  : Dir( '*.*', FA_AnyFile );    { Tous fichiers du r‚p. en cours }
    1  : Dir( ParamStr(1), FA_AnyFile );     { Afficher fich. sp‚cifi‚ }
    else writeln('Nombre de paramŠtres incorrect');
  end;
end.
