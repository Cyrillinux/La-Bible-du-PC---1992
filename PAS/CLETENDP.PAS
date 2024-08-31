{**********************************************************************}
{*                           C L E T E N D P                          *}
{*--------------------------------------------------------------------*}
{*    Montre comment lire les touches additionnelles d'un clavier     *}
{*    ‚tendu                                                          *}
{*--------------------------------------------------------------------*}
{*    Auteur                : MICHAEL TISCHER                         *}
{*    D‚velopp‚             :  01.01.1992                             *}
{*    DerniŠre modification :  01.01.1992                             *}
{**********************************************************************}

program cletend;

uses Dos, Crt;

const Entree = #13#10;                                { Nouvelle ligne }

{**********************************************************************}
{* HexByte : Convertit un octet en nombre hexad‚cimal … 2 chiffres    *}
{* Entr‚e : VALEUR = octet … convertir                                *}
{* Sortie : chaŒne hexad‚cimale … 2 chiffres                          *}
{**********************************************************************}

function HexByte( valeur : byte ) : string;

const HexDigits : array [0..15] of char = '0123456789ABCDEF';

var dummy : string[2];                           { variable de travail }

begin
  dummy[0] := chr(2);                         { a priori deux chiffres }
  dummy[1] := HexDigits[ valeur shr 4 ]; { Convertit les deux quartets }
  dummy[2] := HexDigits[ valeur and $0F ];                    { en Hex }
  HexByte := dummy;
  HexByte := dummy;
end;

{**********************************************************************}
{* TestCE : Teste si les fonctions ‚tendues du BIOS pour lire un      *}
{*          ‚tendu sont disponibls                                    *}
{* Entr‚e : n‚ant                                                     *}
{* Sortie : TRUE, si les fonctions sont disponibles, sinon FALSE      *}
{**********************************************************************}

function TestCE : boolean;

var Regs : Registers;        { pour le d‚clenchement de l'interruption }

begin
  Regs.AX := $1200; { Fonction d'‚tat ‚tendue pour les claviers ‚tendu }
  intr( $16, Regs );
  TestCE := ( Regs.AX <> $1200 );        { AX=$1200 : Fonction absente }
end;

{**********************************************************************}
{* GetCEKey : Lit une touche avec la fonction ‚tendue $10             *}
{* Entr‚e : n‚ant                                                     *}
{* Sortie : code de la touche frapp‚e                                 *}
{**********************************************************************}

function GetCEKey : word;

var Regs : Registers;                            { pour l'interruption }

begin
  Regs.AH := $10;           { Fonction de lecture ‚tendue pour clavier }
  intr( $16, Regs );
  GetCEKey := Regs.AX;                  { Renvoie le code de la touche }
end;

{**********************************************************************}
{*                     PROGRAMME PRINCIPAL                            *}
{**********************************************************************}

var Touche : word;

begin
  clrscr;
  writeln( 'CLETENDP  -  (c) 1992 by Michael Tischer' + Entree );
  if ( TestCE ) then
    begin
      writeln( 'Les extensions du BIOS pour claviers ‚tendu'+
      ' ont ‚t‚ d‚cel‚es! '+Entree+
      'Actionnez les touches ou les combinaisons de touches'+Entree+
      'dont vous voulez connaŒtre les codes'+Entree+Entree
      'Pour sortir du programme tapez <Esc>'+Entree );

      repeat                                        { Boucle de saisie }
        Touche := GetCEKey;                           { Lit une touche }
        write( 'Scan : ', HexByte(hi(Touche)), '  ',
               'ASCII: ', HexByte(lo(Touche)) );
        if ( (lo(Touche) = $E0) and (hi(Touche) <> 0 ) ) then
          write( '  <---- Touche ‚tendu' );
        writeln;
      until ( Touche = $011b );    { R‚p‚ter l'op‚ration jusqu'… ESCAPE }
      writeln( Entree );
    end
  else
    writeln( 'Il n''y a pas d''extension du BIOS pour clavier ‚tendu !');
end.
