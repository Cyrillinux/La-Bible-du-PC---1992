{**********************************************************************}
{*                             N O K E Y P                            *}
{*--------------------------------------------------------------------*}
{*    Montre comment effacer le buffer du clavier                     *}
{*    pour protÇger l'utilisateur contre des saisies rÇsiduelles      *}
{*    lorsqu'il doit rÇpondre Ö des questions                         *}
{     importantes (par ex "Voulez-vous supprimer tel fichier ?")      *}
{*--------------------------------------------------------------------*}
{*    Auteur                : MICHAEL TISCHER                         *}
{*    DÇveloppÇ le          :  01.01.1992                             *}
{*    Derniäre modification :  01.01.1992                             *}
{**********************************************************************}

program NoKeyP;

uses Crt;

{**********************************************************************}
{* ClearKbBuffer : efface le contenu du buffer du clavier             *}
{* EntrÇe : nÇant                                                     *}
{* Sortie : nÇant                                                     *}
{**********************************************************************}

procedure ClearKbBuffer;

begin
  inline( $fa );           { CLI, inhibe les interruptions matÇrielles }
  memw[$40:$1A] := memw[$40:$1C];   { Plus de caractäre dans le buffer }
  inline( $fb );         { STI, rÇtablit les interruptions matÇrielles }
end;

{**********************************************************************}
{*                       Programme principal                          *}
{**********************************************************************}

var i,                                         { Compteur d'itÇrations }
    ccount : integer;            { Nombre de caractäres dans le buffer }
    ch     : char;                              { mÇmorise les touches }

begin
  clrscr;
  writeln( 'NOKEYP  -  (c) 1992 by Michael Tischer' );
  writeln;
  writeln( 'A 0 les caractäres du buffer vont àtre effacÇs .' );
  writeln;

  for i := 10 downto 0 do    { Laisse le temps de taper des caractäres }
    begin
      write( i:5 );
      delay( 750 );
    end;

  ClearKbBuffer;                           { Vide le buffer du clavier }

  {-- Affiche le nombre de caractäres qui restent dans le buffer ------}

  ccount := 0;                               { Pas encore de caractäre }
  writeln;
  writeln;
  writeln( 'Caractäres dans le buffer :' );

  while KeyPressed do       { Reste-t-il un caractäre dans le buffer ? }
    begin                         { Oui, lit le caractäre et l'affiche }
      ch := ReadKey;
      write( '   ', ord(ch):5 );             { Affiche d'abord le code }
      if ord(ch) > 32 then                       { caractäre spÇcial ? }
        write ( '(', ch, ')' );          { Non, affiche le caractäre   }
      writeln;
      inc( ccount );
    end;
  if ccount = 0 then                              { Pas de caractäre ? }
    writeln( '(Aucun)' );                                        { Non }
  writeln;
end.
