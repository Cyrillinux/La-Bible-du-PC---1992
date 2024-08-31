{**********************************************************************}
{*                             D I R P 2                              *}
{*--------------------------------------------------------------------*}
{*    Fonction        : Affiche les fichiers d'un r‚p. quelconque     *}
{*                      y compris sous-r‚pertoires et noms de volumes *}
{*                      sur l'‚cran.                                  *}
{*                      La demande s'effectue avec les deux fonctions *}
{*                      Pascal First et FindNext de l'unit‚ DOS.      *}
{*                      Reportez-vous ‚galement au programme          *}
{*                      DIRP1.PAS.                                    *}
{*--------------------------------------------------------------------*}
{*    Auteur          : MICHAEL TISCHER                               *}
{*    D‚velopp‚ le    :  8.07.1988                                    *}
{*    DerniŠre modif. : 15.03.1992                                    *}
{**********************************************************************}

program DIRP2;

Uses Crt, Dos;                         { Ins‚rer les unit‚s CRT et DOS }

{-- D‚clarations de type ----------------------------------------------}

type MonVec    = array[1..12] of string[3];         { Tableau des mois }

{-- Constantes --------------------------------------------------------}

const EINTR = 14;       { Autant d'entr‚es sont visibles simultan‚ment }
      Mois : MonVec = ( 'Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

{**********************************************************************}
{* PRINTDATA: Afficher les informations … propos d'une entr‚e         *}
{* Entr‚e : DIRBUF = Structure de donn‚es avec informations de fichier*}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure PrintData( DirBuf : SearchRec );

var Compteur : byte;
    Date,                   { Pour tronquer le champ TIME en SearchRec }
    Time     : word;

type longrec = record         { Pour d‚couper un mot LONG en deux Word }
                 LoWord,
                 HiWord  : word
               end;

begin
  writeln;          { Fait avancer la fenˆtre d'une ligne vers le haut }

  write( DirBuf.Name );         { Le nom a ‚t‚ d‚j… converti en Pascal }

  GotoXY(13, EINTR);
  write('³', DirBuf.Size:7);

  Date := longrec(DirBuf.Time).HiWord;    { Date et Heure de SearchRec }
  Time := longrec(DirBuf.Time).LoWord;

  GotoXY(21, EINTR);
  write('³ ', Date and 31:2,' ');                 { D‚terminer le jour }
  write (Mois[Date shr 5 and 15]);                  { Afficher le mois }
  write(Date shr 9 + 1980:5);                     { D‚terminer l'ann‚e }
  GotoXY(34, EINTR);
  write('³  ', Time shr 11:2, 'h');               { D‚terminer l'heure }
  write(Time shr 5 and 63:2);                   { D‚terminer la minute }

  GotoXY(44, EINTR);
  write('³');            { Trait de s‚paration avec le champ pr‚c‚dent }
  Compteur := 1;                              { Afficher les attributs }
  while ( Compteur < 32 ) do
    begin
      if( DirBuf.Attr and Compteur) <> 0 then
         write('X')
      else
         write(' ');
      Compteur := Compteur shl 1;
    end;
  write('º');                         { C“t‚ droit du cadre de fenˆtre }
end;

{**********************************************************************}
{* ConfigEcran: Configure l'‚cran pour la sortie du                   *}
{*              r‚pertoire                                            *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure ConfigEcran;

var Compteur : integer;                           { Compteur de boucle }

begin
 ClrScr;                                             { Effacer l'‚cran }
 Window(14,(20-EINTR) shr 1+1,64,(20-EINTR) shr 1 +5+EINTR);
 GotoXY(1,1);       { Curseur dans le coin sup‚rieur gauche de l'‚cran }

 write('ÉÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍ»');
 write('º Nom        ³ Taille³   Date     ³  Heure  ³RHSVDº');
 write('ÇÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄ¶');

 for Compteur := 1 to EINTR do
   write('º            ³       ³            ³         ³     º');
 write('ÈÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍ¼');

 Window(15,(20-EINTR) shr 1+4,66,(20-EINTR) shr 1 +3+EINTR);
 GotoXY(1, EINTR);          { Curseur dans coin sup. gauche de l'‚cran }
end;

{**********************************************************************}
{* Dir: Contr“le la lecture et la sortie du r‚pertoire                *}
{* Entr‚e : CHEMIN    = Chemin de recherche avec masque de fichier    *}
{*          ATTRIBUT  = Attribut de recherche                         *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure Dir( Chemin : string; Attr : byte );

var NbEntrees,                     { Nombre total des entr‚es trouv‚es }
    NbImage      : integer;            { Nombre d'entr‚es dans l'image }
    Touche        : char;     { Sert … attendre l'appui sur une touche }
    DirBuf       : SearchRec;                  { Re‡oit une entr‚e Dir }

begin
  clrscr;                                            { Effacer l'‚cran }
  ConfigEcran;       { Construire l'‚cran pour la sortie de r‚pertoire }

  NbImage := -1; { Aucune entr‚e n'est encore affich‚e dans la fenˆtre }
  NbEntrees := 0;               { Aucune entr‚e n'a ‚t‚ encore trouv‚e }
  FindFirst( Chemin, Attr, DirBuf );   { Rechercher la premiŠre entr‚e }
  if DOSError = 0 then
    repeat
      NbEntrees := succ(NbEntrees);         { Une autre entr‚e trouv‚e }
      NbImage := succ(NbImage);     { Une autre entr‚e dans la fenˆtre }
      if NbImage = EINTR then            { La fenˆtre est-elle pleine? }
        begin                                                    { OUI }
          Window(14, (20-EINTR) shr 1 + 5 + EINTR,
                66, (20-EINTR) shr 1 + 6+ EINTR );
          GotoXY(1, 1);            { Curseur sur ligne inf. de fenˆtre }
          TextBackground( LightGray );                    { Fond blanc }
          TextColor( Black );                       { Ecriture en noir }
          write('          Veuillez appuyer sur une touche          ');
          Touche := ReadKey;                          { Lire la touche }
          GotoXY(1, 1);     { Curseur dans coin sup. gauche de fenˆtre }
          TextBackground( Black );                         { Fond noir }
          TextColor( LightGray );                  { Ecriture en blanc }
          write('                                                   ');
          Window(15,(20-EINTR) shr 1+4,65,(20-EINTR) shr 1 +3+EINTR);
          GotoXY(1, EINTR);        { Replace curseur sur ancienne pos. }
          NbImage := 0;                      { Reprendre le calcul … 0 }
        end;
      PrintData( DirBuf );          { Afficher les donn‚es de l'entr‚e }
      FindNext( DirBuf );              { Rechercher le fichier suivant }
    until DOSError <> 0;    { jusqu'… ce qu'il n'y ait plus de fichier }

  Window(14,(20-EINTR) shr 1 +5+EINTR,65,(20-EINTR) shr 1 +6+EINTR);
  GotoXY(1, 1);  { Curseur dans le coin sup‚rieur gauche de la fenˆtre }
  TextBackground( LightGray );                            { Fond blanc }
  TextColor( Black );                               { Ecriture en noir }
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
    0  : Dir( '*.*', AnyFile ); { Tous fichiers ds r‚pertoire en cours }
    1  : Dir( ParamStr(1), AnyFile );   { Afficher le fichier sp‚cifi‚ }
    else writeln('Nombre de paramŠtres incorrect');
  end;
end.
