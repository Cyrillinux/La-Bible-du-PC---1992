{**********************************************************************}
{*                             N O K E Y P                            *}
{*--------------------------------------------------------------------*}
{*    Montre comment effacer le buffer du clavier                     *}
{*    pour prot�ger l'utilisateur contre des saisies r�siduelles      *}
{*    lorsqu'il doit r�pondre � des questions                         *}
{     importantes (par ex "Voulez-vous supprimer tel fichier ?")      *}
{*--------------------------------------------------------------------*}
{*    Auteur                : MICHAEL TISCHER                         *}
{*    D�velopp� le          :  01.01.1992                             *}
{*    Derni�re modification :  01.01.1992                             *}
{**********************************************************************}

program NoKeyP;

uses Crt;

{**********************************************************************}
{* ClearKbBuffer : efface le contenu du buffer du clavier             *}
{* Entr�e : n�ant                                                     *}
{* Sortie : n�ant                                                     *}
{**********************************************************************}

procedure ClearKbBuffer;

begin
  inline( $fa );           { CLI, inhibe les interruptions mat�rielles }
  memw[$40:$1A] := memw[$40:$1C];   { Plus de caract�re dans le buffer }
  inline( $fb );         { STI, r�tablit les interruptions mat�rielles }
end;

{**********************************************************************}
{*                       Programme principal                          *}
{**********************************************************************}

var i,                                         { Compteur d'it�rations }
    ccount : integer;            { Nombre de caract�res dans le buffer }
    ch     : char;                              { m�morise les touches }

begin
  clrscr;
  writeln( 'NOKEYP  -  (c) 1992 by Michael Tischer' );
  writeln;
  writeln( 'A 0 les caract�res du buffer vont �tre effac�s .' );
  writeln;

  for i := 10 downto 0 do    { Laisse le temps de taper des caract�res }
    begin
      write( i:5 );
      delay( 750 );
    end;

  ClearKbBuffer;                           { Vide le buffer du clavier }

  {-- Affiche le nombre de caract�res qui restent dans le buffer ------}

  ccount := 0;                               { Pas encore de caract�re }
  writeln;
  writeln;
  writeln( 'Caract�res dans le buffer :' );

  while KeyPressed do       { Reste-t-il un caract�re dans le buffer ? }
    begin                         { Oui, lit le caract�re et l'affiche }
      ch := ReadKey;
      write( '   ', ord(ch):5 );             { Affiche d'abord le code }
      if ord(ch) > 32 then                       { caract�re sp�cial ? }
        write ( '(', ch, ')' );          { Non, affiche le caract�re   }
      writeln;
      inc( ccount );
    end;
  if ccount = 0 then                              { Pas de caract�re ? }
    writeln( '(Aucun)' );                                        { Non }
  writeln;
end.
