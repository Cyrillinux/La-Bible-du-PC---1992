{**********************************************************************}
{*                          D V I P                                   *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Montre comment acc‚der directement … la        *}
{*                     m‚moire d'‚cran en Turbo Pascal.               *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   :  2/10/1987                                     *}
{*    DerniŠre MAJ   : 14/01/1991                                     *}
{**********************************************************************}

program DVIP;

Uses Crt, Dos;                         { IntŠgre les unit‚s CRT et DOS }

const NORMAL        = $07;        { D‚finit les attributs de caractŠre }
      CLAIR         = $0f;                    { pour une carte d'‚cran }
      INVERSE       = $70;                                { monochrome }
      SOULIGNE      = $01;
      CLIGNOTANT    = $80;

      NOIR          = $00;                      { Attributs de couleur }
      BLEU          = $01;
      VERT          = $02;
      CYAN          = $03;
      ROUGE         = $04;
      MAGENTA       = $05;
      BRUN          = $06;
      GRISCLAIR     = $07;
      GRISFONCE     = $01;
      BLEUCLAIR     = $09;
      VERTCLAIR     = $0A;
      CYANCLAIR     = $0B;
      ROUGECLAIR    = $0C;
      MAGENTACLAIR  = $0D;
      JAUNE         = $0E;
      BLANC         = $0F;

type TextTyp = string[80];

var VSeg : word;            { Adresse de segment de la m‚moire d'‚cran }

{**********************************************************************}
{* InitDPrint: D‚termine le segment de la m‚moire d'‚cran pour DPrint *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure InitDPrint;

var CRTC_PORT : word absolute $0040:0063;{ ariable dans seg. var. BIOS }

begin
  if CRTC_PORT = $3B4 then          { Adaptateur monochrome connect‚ ? }
    VSeg := $B000           { OUI, la m‚moire d'‚cran est en B000:0000 }
  else                       { Non, ce doit ˆtre un adaptateur couleur }
    VSeg := $B800;               { La m‚moire d'‚cran est en B800:0000 }
end;

{**********************************************************************}
{* DPrint: Ecrit une chaŒne directement dans la m‚moire d'‚cran.      *}
{* Entr‚e : - COLONNE : colonne d'affichage                           *}
{*          - LIGNE   : ligne d'affichage                             *}
{*          - COULEUR : couleur (ou attribut) des caractŠres.         *}
{*          - STROUT  : chaŒne … afficher                             *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure DPrint( Colonne, Ligne, Couleur : byte; StrOut : TextTyp);

var PAGE_OFS : word absolute $0040:$004E;   { Variable  seg. var. BIOS }
    Offset   : word;   { Pointeur sur la position d'affichage courante }
    i, j     : byte;                          { Compteurs d'it‚rations }
    Attribut : word;                            { Attribut d'affichage }

begin
  Offset := Ligne * 160 + Colonne * 2 + PAGE_OFS;
  Attribut := Couleur shl 8;{ Octet fort pour accŠs … la m‚moire ‚cran }
  i := length( StrOut );          { D‚termine la longueur de la chaŒne }
  for j:=1 to i do                                { Parcourt la chaŒne }
    begin { Ecrit caractŠre et attribut directement dans m‚moire ‚cran }
      memw[VSeg:Offset] := Attribut or ord( StrOut[j] );
      Offset := Offset + 2;  { Passe au prochain couple ASCII-attribut }
    end;
end;

{**********************************************************************}
{* D‚mo   : D‚monstration du fonctionnement de DPrint.                *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Aucune                                                    *}
{**********************************************************************}

procedure demo;

var Colonne,                           { Position d'affichage courante }
    Ligne,
    Couleur   : integer;

begin
  TextBackGround( NOIR );                     { Colore le fond en noir }
  ClrScr;                                             { Efface l'‚cran }
  DPrint( 22, 0, BLANC, 'DVIP  - (c) 1988, 1992 by Michael Tischer');
  Randomize;              { Active le g‚n‚rateur de nombres al‚atoires }
  while not KeyPressed do  { R‚pŠte op‚ration jusqu'… touche actionn‚e }
    begin
      Colonne := Random( 76 );             { Colonne, ligne et couleur }
      Ligne := Random( 22 ) + 1;              { sont choisis au hasard }
      Couleur := Random( 14 ) + 1;
      DPrint( Colonne, Ligne,   Couleur, 'ÛÛÛÛ');    { Affiche un pav‚ }
      DPrint( Colonne, Ligne+1, Couleur, 'ÛÛÛÛ');
    end;
  ClrScr;                                   { Efface … nouveau l'‚cran }
end;

{**********************************************************************}
{**                       PROGRAMME PRINCIPAL                        **}
{**********************************************************************}

begin
  InitDPrint;                      { Initialise l'affichage par DPrint }
  Demo;                         { D‚montre le fonctionnement de DPrint }
end.
