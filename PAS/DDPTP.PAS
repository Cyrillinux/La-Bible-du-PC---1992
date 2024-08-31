{**********************************************************************}
{*                          D D P T P                                 *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Permet d'optimiser les accŠs … la disquette    *}
{*                     en modifiant les valeurs de la Disk-Drive-     *}
{*                     Parameter-Table.                               *}
{*--------------------------------------------------------------------*}
{*    Auteur                : Michael Tischer                         *}
{*    D‚velopp‚ le          : 22.08.1991                              *}
{*    DerniŠre modification : 27.01.1992                              *}
{**********************************************************************}

program DDPTP;

Uses Crt, Dos;                        { Int‚grer les unit‚s CRT et DOS }

type DDPT_T   = array[ 0..10 ] of byte;       { Structure pour la DDPT }
     DDPT_PTR = ^DDPT_T;                        { Pointeur sur la DDPT }

var  DDPT : DDPT_PTR;                           { Pointeur sur la DDPT }

{**********************************************************************}
{* byte_hex : Convertit un octet en un nombre hexad‚cimal             *}
{* Entr‚e   : Nombre … convertir                                      *}
{* Sortie   : Nombre sous forme de chaŒne hexad‚cimal                 *}
{**********************************************************************}

function byte_hex( Nombre : byte ) : string;

{-- Convertit un chiffre 0 - 15 en hexa 0 - F -------------------------}

function h_Chiffre( Chiffre : byte ) : char;

begin
  if ( Chiffre >= 10 ) then                 { Chiffre >= 10 soit A - F }
    h_Chiffre := chr( 55 + Chiffre )
  else                             { Non chiffre comme chiffre d‚cimal }
    h_Chiffre := chr( 48 + Chiffre );
end;

begin
  byte_hex := '$' + h_Chiffre( Nombre div 16 )
                  + h_Chiffre( Nombre mod 16 );
end;

{**********************************************************************}
{* hex_byte : Convertit une chaŒne hexa en un octet                   *}
{* Entr‚e   : ChaŒne hexa … convertir                                 *}
{* Sortie   : Nombre                                                  *}
{**********************************************************************}

function hex_byte( hex : string ) : byte;

{-- Convertir un chiffre hexa 0 - F en  0 - 15  -----------------------}

function d_Chiffre( Chiffre : char ) : byte;

begin
  if ( Chiffre >= 'A' ) and ( Chiffre <= 'F' ) then
    d_Chiffre := ord( Chiffre ) - 55
  else                             { Non chiffre comme chiffre d‚cimal }
    d_Chiffre := ord( Chiffre ) - 48;
end;

begin
  if ( hex[ 1 ] = '$' ) then delete( hex, 1, 1 );
  if length( hex ) = 1 then hex := '0' + hex;
  hex_byte := d_Chiffre( hex[ 1 ] ) * 16 + d_Chiffre( hex[ 2 ] );
end;

{**********************************************************************}
{* RAM_DDPT : Tester si DDPT se trouve dans la RAM ou la ROM          *}
{* Entr‚e  : Aucune                                                   *}
{* Sortie  : true si DDPT dans la RAM                                 *}
{* Info     : La fonction inscrit une valeur dans la DDPT, la relit   *}
{*            puis compare si la valeur a ‚t‚ inscrite, la DDPT       *}
{*            se trouve donc dans la RAM                              *}
{**********************************************************************}

function RAM_DDPT : boolean;

var buffer : byte;        { M‚moire pour la valeur actuelle de la DDPT }

begin
  buffer := DDPT^[ 0 ];                   { Sauvegarder la valeur DDPT }
  DDPT^[ 0 ] := not buffer;                       { Inverser la valeur }
  RAM_DDPT := ( DDPT^[ 0 ] = not buffer );{ Evaluer le test d'‚criture }
  DDPT^[ 0 ] := buffer                   { Restaurer l'ancienne valeur }
end;

{**********************************************************************}
{* AfficherValeur : Afficher la valeur DDPT                           *}
{* Entr‚e         : Aucune                                            *}
{* Sortie         : Aucune                                            *}
{* Infos          : La proc‚dure affiche la valeur actuelle de la     *}
{*                  DDPT sur l'‚cran.                                 *}
{**********************************************************************}

procedure AfficherValeur;

begin
  writeln( 'Steprate                (SR): ',
               byte_hex( DDPT^[ 0 ] shr 4 ) );
  writeln( #13#10'Head-Unload-Time        (HU): ',
               byte_hex( DDPT^[ 0 ] and $F ) );
  writeln( 'Head-Load-Time          (HL): ',
               byte_hex( DDPT^[ 1 ] shr 1 ) );
  writeln( 'Head-Settle-Time        (HS): ',
               byte_hex( DDPT^[ 9 ] ) );
  writeln( #13#10'Temps de rotation du moteur aprŠs (MN): ',
               byte_hex( DDPT^[ 2 ] ) );
  writeln( 'Temps de rotation du moteur avant (MA): ',
               byte_hex( DDPT^[ 10 ] ) );
end;

{**********************************************************************}
{* ValeursNouv : D‚finir les nouvelles valeurs de la DDPT             *}
{* Entr‚e      : Aucune                                               *}
{* Sortie      : Aucune                                               *}
{**********************************************************************}

procedure ValeursNouv;

var i,j       : byte;                             { Compteur de boucle }
    Art       : string[ 2 ];                     { ParamŠtre … modifier}
    Valeur      : byte;                    { Nouvelle valeur … d‚finir }
    ValSecours : byte;               { Valeur de secours … sauvegarder }
    Commande    : string[ 6 ];   { ParamŠtre de la ligne d'instruction }

begin
  {-- Boucle: Examiner tous les paramŠtres  ---------------------------}

  for i := 1 to Paramcount do
    begin
      Commande := paramstr( i );                   { Lire le paramŠtre }
      for j := 1 to length( Commande ) do      { Commande en majuscule }
        Commande[ j ] := upcase( Commande[ j ] );
      Art := copy( Commande, 1, 2 );               { Valeur … modifier }
      delete( Commande, 1, 3 );           { D‚terminer nouvelle valeur }
      Valeur := hex_byte( Commande );
      if ( Art = 'SR' ) then                              { Step rate? }
        begin
          Valeur := Valeur shl 4;   { Valeur dans le quartet sup‚rieur }
          ValSecours := DDPT^[ 0 ] and $0F;        { Quartet inf‚rieur }
          DDPT^[ 0 ] := Valeur or ValSecours;  { Sauvegarder la valeur }
        end
      else if ( Art = 'HU' ) then                  { Head-Unload-Time? }
        begin
          Valeur := Valeur and $0F; { Valeur dans le quartet inf‚rieur }
          ValSecours := DDPT^[ 0 ] and $F0;        { Quartet sup‚rieur }
          DDPT^[ 0 ] := Valeur or ValSecours;  { Sauvegarder la valeur }
        end
      else if ( Art = 'HL' ) then                    { Head-Load-Time? }
        DDPT^[ 1 ] := Valeur shl 1   { Sauver valeur dans les bits 1-7 }
      else if ( Art = 'HS' ) then                  { Head-Settle-Time? }
        DDPT^[ 9 ] := Valeur                   { Sauvegarder la valeur }
      else if ( Art = 'MN' ) then { Temps de rotation du moteur aprŠs? }
        DDPT^[ 2 ] := Valeur                   { Sauvegarder la valeur }
      else if ( Art = 'MA' ) then { Temps de rotation du moteur avant? }
        DDPT^[ 10 ] := Valeur;                 { Sauvegarder la valeur }
    end;
end;

{**********************************************************************}
{*                         PROGRAMME PRINCIPAL                        *}
{**********************************************************************}

begin
  ClrScr;                                            { Effacer l'‚cran }
  writeln( 'DDPTP (c) 1991, 1992 by Michael Tischer');
  writeln( 'Optimiser les accŠs … la disquette' );

  GetIntVec( $1E, pointer( DDPT ) );    { Lire le pointeur sur la DDPT }

  if ( RAM_DDPT ) then             { DDPT dans la RAM donc modifiable? }
    begin
      if ( Paramcount > 0 ) then        { Faut-il d‚finir des valeurs? }
        begin
          ValeursNouv;             { Oui, d‚finir de nouvelles valeurs }
          writeln( #13#10#10'Nouvelles valeurs DDPT:');
          AfficherValeur;              { Afficher nouvelle valeur DDPT }
        end;
    end
  else            { DDPT se trouve dans la ROM, impossible de modifier }
    writeln( 'Il est impossible de modifier la  ' +
          'Disk-Drive-Paramter-Table car elle se trouve dans la ROM ' );

  writeln( #13#10#10'Contenu DDPT:');
  AfficherValeur;                    { Afficher anciennes valeurs DDPT }
end.
