{**********************************************************************}
{*                        R E C L O C K P                             *}
{*--------------------------------------------------------------------*}
{*    Fonction     : D‚monstration des fonctions de verrouillage      *}
{*                   d'enregistrements DOS                            *}
{*--------------------------------------------------------------------*}
{*    Auteur       : Michael Tischer                                  *}
{*    D‚velopp‚ le : 19.09.1991                                       *}
{*    DerniŠre MAJ : 24.09.1991                                       *}
{**********************************************************************}

program RecLockP;

uses Crt, Dos,                        { Int‚grer les unit‚s CRT et DOS }
     NetFileP;                            { Int‚grer l'unit‚ de r‚seau }

const NomFichier = 'Rec.dat';         { Nom de fichier du fichier test }

type  Test     = array[ 1..160 ] of char;    { Type de donn‚es du test }
      TestFile = file of Test;

var Fichier : TestFile;                                 { Fichier test }

{**********************************************************************}
{* CreerEnreg : Cr‚er des enregistrements pour un test                *}
{* Entr‚e     : CaractŠres pour l'enregistrement                      *}
{* Sortie     : Donn‚es de test                                       *}
{**********************************************************************}

procedure CreerEnreg(     Caractere : char;
                       var Enreg    : test );

var i : word;                                     { Compteur de boucle }

begin
  for i := 1 to 160 do
    Enreg[ i ] := Caractere;
end;

{**********************************************************************}
{* OuvrirFichier : Ouvrir un fichier r‚seau existant. Sinon cr‚er un  *}
{*                 nouveau fichier test et compl‚ter le fichier       *}
{*                 avec des donn‚es de test                           *}
{* Entr‚e        : Fichier                                            *}
{* Sortie        : Fichier                                            *}
{**********************************************************************}

function OuvrirFichier( var Fichier : testfile ) : boolean;

var i        : word;                              { Compteur de boucle }
    TestChaine : Test;{ N‚cessaire pour la cr‚ation de donn‚es de test }

begin
{-- Ouvrir un fichier pour l'entr‚e et la sortie en mode Deny-None ----}

  NetReset( NomFichier, fm_rw or sm_no, sizeof( Test ), Fichier );
  if ( NetError = NE_FileNotFound ) then         { Fichier inexistant? }
    begin

{-- Cr‚er un fichier et compl‚ter par des donn‚es de test -------------}

      NetRewrite( NomFichier, fm_rw or sm_no, sizeof( Test ), Fichier );
      if ( NetError = 0 ) then                    { Cr‚er sans erreur? }
        begin
          if NetLock( Fichier, 0, 26 ) then    { Verrouiller 26 enreg. }
            begin
              NetSeek( Fichier, 0 );{ Pointeur sur le d‚but du fichier }
              for i := 1 to 26 do
                begin
                  CreerEnreg( chr( ord( 'Z' ) + 1 - i ), TestChaine );
                  NetWrite( Fichier, TestChaine );{Ecrire donn‚es test }
                end;
              OuvrirFichier := NetUnlock( Fichier, 0, 26 );
            end
          else
            OuvrirFichier := false;      { Erreur lors du verrouillage }
        end
      else
        OuvrirFichier := false;{ Erreur lors de la cr‚ation du fichier }
    end
  else
    OuvrirFichier := ( NetError = 0 );             { Ouvrir ou erreur? }
end;

{**********************************************************************}
{* NetzEdit   : D‚monstration des fonctions de r‚seau                 *}
{* Entr‚e     : Fichier                                               *}
{* Sortie     : Fichier                                               *}
{**********************************************************************}

procedure NetzEdit( var Fichier : TestFile );

var NumEnreg : longint;               { Num‚ro d'enregistrement actuel }
    EnregAct   : Test;                         { Enregistrement actuel }
    Action    : byte;                               { Action souhait‚e }
    Etat    : boolean;                    { Enregistrement verrouill‚? }
    Caractere   : char;

begin
{-- Afficher le menu --------------------------------------------------}

  writeln( #13#10'Fonctions possibles' );
  writeln( '  1: Positionner le pointeur de fichier.' );
  writeln( '  2: Verrouiller l''enregistrement' );
  writeln( '  3: Lire l''enregistrement' );
  writeln( '  4: Modifier l''enregistrement' );
  writeln( '  5: Ecrire dans l''enregistrement' );
  writeln( '  6: Lever l''interdiction' );
  writeln( '  7: Fin' );

  NumEnreg := 0;                               { Enregistrement actuel }
  Etat := false;                       { Enregistrement non verrouill‚ }
  CreerEnreg( #32, EnregAct );          { Cr‚er un enregistrement vide }

  repeat
 {-- Afficher les informations ----------------------------------------}

    gotoxy( 1, 16 );     { Afficher la position du pointeur de fichier }
    writeln( 'Enregistrement actuel: ',  NumEnreg : 4 );
    write( 'Etat          : ' );
    if Etat then
      writeln( 'Verrouill‚' )
    else
      writeln( 'Libre    ' );
    Writeln( 'Statut r‚seau  : ', NetError: 4, '  = ',
       copy( NetErrorMsg( NetError ) + '                   ', 1, 30 ) );
    gotoxy( 1, 21 );               { Afficher l'enregistrement de test }
    writeln( 'Enregistrement actuel:' );
    writeln( EnregAct );

    NetSeek( Fichier, NumEnreg ); { Positionner le pointeur de fichier }

    gotoxy( 1, 13 );
    write( 'Choix:                            ' );
    gotoxy( 10, 13 );
    readln( Action );
    case Action of
      1 : begin
            gotoxy( 1, 13 );
            write( 'Nouveau num‚ro d''enregistrement: ' );
            readln( NumEnreg );
            Etat := false;             { Enregistrement non verrouill‚ }
            CreerEnreg( #32, EnregAct )
          end;
      2 : Etat := Etat or NetLock( Fichier, NumEnreg, 1 );
      3 : NetRead( Fichier, EnregAct );        { Lire l'enregistrement }
      4 : begin
            gotoxy( 1, 13 );
            write( 'Nouveau caractŠre: ' );
            readln( Caractere );
            CreerEnreg( Caractere, EnregAct );
          end;
      5 : NetWrite( Fichier, EnregAct );{ Ecrire dans l'enregistrement }
      6 : Etat := Etat and not NetUnlock( Fichier, NumEnreg, 1 );
    end;
  until ( Action = 7 );
end;

{**********************************************************************}
{*               P R O G R A M M E  P  R I N C I P A L                *}
{**********************************************************************}

begin
  clrscr;
  writeln( 'D‚mo des fonctions de verrouillage de fichiers DOS',
           '  (C) 1991 by Michael Tischer' + paramstr( 1 ) );
  writeln( '====================================================',
           '===========================' );

  if ( ShareInst ) then                    { Programme Share install‚? }
    begin
      if OuvrirFichier( Fichier ) then       { Fichier ouvert ou cr‚‚? }
        begin
          NetzEdit( Fichier ); { D‚monstration des fonctions de r‚seau }
          NetClose( Fichier );                     { Fermer le fichier }
        end
      else
        writeln( #13#10'Erreur lors de l''ouverture du fichier r‚seau, ' +
                       'Num‚ro d''erreur: ', NetError );
      ClrScr;
    end
  else
    writeln( #13#10'Test non possible, Share doit ˆtre install‚' );
end.
