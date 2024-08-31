{**********************************************************************}
{*                         F L O C K P . P A S                        *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Montre comment fonctionne le verrouillage des  *}
{*                     fichiers sous r‚seau … l'aide des fonctions et *}
{*                     proc‚dures de l'unit‚ NETFILEP                 *}
{*--------------------------------------------------------------------*}
{*    Auteur         : Michael Tischer                                *}
{*    D‚velopp‚ le   : 10.02.1992                                     *}
{*    DerniŠre MAJ   : 13.02.1992                                     *}
{**********************************************************************}

program FLockP;

uses Crt, Dos,                         { IntŠgre les unit‚s CRT et DOS }
     NetFileP;                            { et aussi l'unit‚ de R‚seau }

const NomFichier = 'flockp.dat';              { Nom du fichier de test }

type  Test  = array[ 1..4 ] of char;{Type de donn‚es pour fichier test }

{**********************************************************************}
{* FMode   : G‚nŠre le mode du fichier … partir du type d'accŠs et du *}
{*           mode de partage                                          *}
{* Entr‚es : Type d'accŠs et mode de partage du fichier               *}
{* Sortie  : Mode du fichier                                          *}
{**********************************************************************}

function FMode( Acces, Prot : byte ) : byte;

{-- Types d'accŠs et modes de partage d‚finis comme dans Netfile ------}

const Acces_Type : array[ 1..3 ] of byte = ( FM_R, FM_W, FM_RW );
      Prot_Type  : array[ 1..5 ] of byte = ( SM_COMP, SM_RW, SM_R,
                          SM_W, SM_NO );

begin
  FMode := Acces_Type[ Acces ] or Prot_Type[ Prot ];
end;

{**********************************************************************}
{* FichierTest : Montre les conflits d'accŠs ou le jeu de protections *}
{*               avec ou sans verrouillage                            *}
{* Entr‚es     : Type d'accŠs et mode de partage des deux fichiers    *}
{*               concurrents                                          *}
{* Sortie      : n‚ant                                                *}
{**********************************************************************}

procedure FichierTest( AccesA, ProtA, AccesB, ProtB : byte );

const TestAEcr : Test = 'AAAA';              { Enregistrements de test }
      TestBEcr : Test = 'BBBB';

var TestALec,                                     { Donn‚es de lecture }
    TestBLec  : Test;
    FichierA,                     { Fichiers de test pour accŠs commun }
    FichierB    : file of Test;

begin
  window( 1, 11, 80, 25 );
  clrscr;
  writeln( 'Fichier A: Nom = ', NomFichier, ', Type d''accŠs = ',
       AccesA, ',  Partage    = ', ProtA );
  writeln( 'Fichier B: Nom = ', NomFichier, ', Type d''accŠs = ',
       AccesB, ',  Partage    = ', ProtB );

{-- Ouvre les fichiers ------------------------------------------------}

  write( #13#10'Ouverture du fichier A:  ' );
  NetReset( NomFichier, FMode( AccesA, ProtA ),
        sizeof( Test ), FichierA );
  if ( NetError = NE_FileNotFound ) then
    NetRewrite( NomFichier, FMode( AccesA, ProtA ),
        sizeof( test ), FichierA );
  Writeln( 'Etat   ', NetError : 2, '  = ', NetErrorMsg( NetError ) );

  write( 'Ouverture du fichier B:  ' );
  NetReset( NomFichier, FMode( AccesB, ProtB ),
        sizeof( Test ), FichierB );
  Writeln( 'Etat   ', NetError : 2, '  = ', NetErrorMsg( NetError ) );

{-- Ecrit dans les fichiers -------------------------------------------}

  write( #13#10'Ecriture dans fichier A:' );
  if ( Is_NetWriteOk( FichierA ) ) then           { Ecriture permise ? }
    begin
      Netwrite( FichierA, TestAEcr );
      writeln( ' Donn‚es "', TestAEcr, '" enregistr‚es ' );
    end
  else
    writeln( ' Fichier interdit en ‚criture     ' );

  write( 'Ecriture dans Fichier B:' );
  if ( Is_NetWriteOk( FichierB ) ) then            { Ecriture permise ?}
    begin
      Netwrite( FichierB, TestBEcr );
      writeln( ' Donn‚es "', TestBEcr, '" enregistr‚es ' );
    end
  else
    writeln( ' Fichier interdit en ‚criture ' );

       {-- Remet les pointeurs des deux fichiers au d‚but -------------}

  if Is_NetOpen( FichierA ) then                     { Fichier ouvert? }
    NetSeek( FichierA, 0 );
  if Is_NetOpen( FichierB ) then                    { Fichier ouvert ? }
    NetSeek( FichierB, 0 );

{-- Lit les fichiers   ------------------------------------------------}

  write( #13#10'Lecture dans fichier A:' );
  if ( Is_NetReadOk( FichierA ) ) then             { Lecture permise ? }
    begin
      Netread( FichierA, TestALec );
      writeln( ' Enregistrement "', TestALec, '" lu ' );
    end
  else
    writeln( ' Fichier interdit en lecture ' );

  write( 'Lecture dans fichier B:' );              { Lecture permise ? }
  if ( Is_NetReadOk( FichierB ) ) then
    begin
      Netread( FichierB, TestBLec );
      writeln( ' Enregistrement "', TestBLec, '" lu ' );
    end
  else
    writeln( ' Fichier interdit en lecture ' );

{-- Fermeture des fichiers --------------------------------------------}

  NetClose( FichierA );
  NetClose( FichierB );
end;

{**********************************************************************}
{*                      PROGRAMME PRINCIPAL                           *}
{**********************************************************************}

var AccesA,                               { Types d'accŠs des fichiers }
    AccesB,
    ProtA,                                     { Mode de partage       }
    ProtB   : byte;

begin
  clrscr;
  writeln( 'FLOCKP D‚mo de verrouillage de fichiers sous DOS    ',
       '(c) 1992 by Michael Tischer' );
  writeln( '====================================================',
       '===========================' );

  if ( ShareInst ) then                              { Share install‚? }
    begin
       {-- S‚lectionne le mode ----------------------------------------}

      writeln( #13#10'Types d''accŠs possibles:         ',
             'Modes de partage possibles:' );
      writeln( ' 1: Lecture seule                ',
           ' 1: Mode de compatibilit‚ ( pas de prot)' );
      writeln( ' 2: Ecriture seule               ',
           ' 2: Tout accŠs ‚tranger interdit ' );
      writeln( ' 3: Lecture et ‚criture          ',
           ' 3: Lecture seule          ' );
      writeln( '                                 ',
           ' 4: Ecriture seule            ' );
      writeln( '                                 ',
           ' 5: Tout est permis (Record lock)' );

      Write( #13#10'Type d''accŠs pour le fichier de test A: ' );
      read( AccesA );
      Write( 'Mode de partage pour le fichier de test A: ' );
      read( ProtA );
      Write( 'Type d''accŠs pour le fichier de test B: ' );
      read( AccesB );
      Write( 'Mode de partage pour le fichier de test B: ' );
      read( ProtB );

      FichierTest( AccesA, ProtA, AccesB, ProtB );
    end
  else
    writeln( #13#10'Test impossible, SHARE doit ˆtre install‚ ' );
end.
