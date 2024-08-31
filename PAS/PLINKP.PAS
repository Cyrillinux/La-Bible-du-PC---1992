{**********************************************************************}
{                          P L I N K P . P A S                         }
{----------------------------------------------------------------------}
{    Fonction       : transmet des fichiers par le port parallŠle      }
{----------------------------------------------------------------------}
{    Auteur       : Michael Tischer                                    }
{    D‚velopp‚ le : 27.09.1991                                         }
{    DerniŠre MAJ : 28.11.1991                                         }
{**********************************************************************}
{$M 65520, 0, 655360 }

uses dos, crt;                         { IntŠgre les unit‚s DOS et CRT }

{== Constantes ========================================================}

const UNESEC       =  18;                               { Une seconde  }
      DIXSEC       =  182;                             { Dix secondes  }
      TO_DEFAULT   =  DIXSEC;                    { Time-Out par d‚faut }

      MAXBLOC     =  4096;         { Taille d'un bloc 4 Ko ( Cluster ) }

{-- Constantes pour le protocole de transmission ----------------------}

      ACK          = $00;                        { Accus‚ de r‚ception }
      NAK          = $FF;                    { Non accus‚ de r‚ception }
      MAX_TRY      = 5;              { Nombre de tentatives autoris‚es }

{-- Tokens pour la communication entre ‚metteur et r‚cepteur --------}

      TOK_DATSTART = 0;                             { D‚but de fichier }
      TOK_DATNEXT  = 1;                   { Suite d'un bloc de donn‚es }
      TOK_DONNEESD   = 2;           { Transmission du fichier termin‚e }
      TOK_FIN     = 3;                              { Fin du programme }
      TOK_ESCAPE   = 4;{ Interruption par ESC sur l'ordinateur distant }

{-- Codes pour les appels LongJump ------------------------------------}

      LJ_OKEMETTEUR  = 1;        { Tous les fichiers correctement ‚mis }
      LJ_OKRECEPT    = 2;       { Tous les fichiers correctement re‡us }
      LJ_TIMEOUT   = 3;     { Time-out: le correspondant ne r‚pond pas }
      LJ_ESCAPE    = 4;  { Interruption par Esc sur l'ordinateur local }
      LJ_REMESCAPE = 5;{ Interruption par Esc sur l'ordinateur distant }
      LJ_DATA      = 6;                      { Erreur de communication }
      LJ_NOLINK    = 7;                               { Pas de liaison }
      LJ_NOPAR     = 8;                             { Pas d'interface  }
      LJ_PARA      = 9;                 { ParamŠtres d'appel invalides }

{== D‚finitions de types===============================================}

type BHEADER = record            { En-tˆte pour transmission des blocs }
                 case boolean of
                   true  : ( Token : byte;
                             Len   : word );
                   false : ( Champ  : array[ 0..2 ] of byte );
               end;

     JMPBUF  = record              { Enregistrement des informations , }
         BP,                         { n‚cessit‚es pour le branchement }
                 SP,
         CS,                  { ne pas changer l'ordre des variables ! }
                 IP  : word;
               end;

     DBloc = array[ 1..MAXBLOC ] of byte;          { Donnees d'un bloc }

{== Variables globales  ===============================================}

var InPort       : word;                    { Adresse du port d'entr‚e }
    OutPort      : word;
    Escape       : boolean;            { Pas de touche ESCAPE enfonc‚e }
    Timeout      : word;              { valeur de Timeout s‚lectionn‚e }
    TO_Count     : word;                         { Compteur de Timeout }
    Branchement  : JMPBUF;           { Adresse de retour pour terminer }
    BlocBuf      : DBLOC;              { Buffer pour m‚moriser un bloc }
    Fichier      : file;    { Variable fichier pour traiter un fichier }

{== D‚claration des fonctions en assembleur ===========================}

{$L plinkpa.obj }    { IntŠgre le module en assembleur }

function  getb : byte; external;
procedure putb( Wert : byte ); external;
procedure intr_install(escape_flag, timeout_count : pointer); external;
procedure intr_remove; external;
procedure EscapeDirect( Declenche : boolean ); external;

{**********************************************************************}
{ SetJmp : D‚termine l'emplacement du programme o— doit se brancher    }
{          LongJmp                                                     }
{----------------------------------------------------------------------}
{ Entr‚e  : JB : Structure de donn‚es du type JumpBuf, qui contient    }
{                les informations n‚cessaires au branchement           }
{ Sortie  : NOJMP au retour de cette fonction ; toute autre valeur     }
{           lorsque le retour suit un appel … LongJmp                  }
{**********************************************************************}

{$F+} { Setjmp et Longjmp doivent ˆtre de type FAR }

function SetJmp( var JB : JMPBUF ) : integer;

type WordP  = ^word;                             { Pointeur sur un mot }

begin
  JB.BP := WordP( ptr( SSeg, Sptr+2) )^;
  JB.IP := WordP( ptr( SSeg, Sptr+4) )^;
  JB.CS := WordP( ptr( SSeg, Sptr+6) )^;

      { SP doit r‚f‚rencer la position … partir de laquelle LongJmp va }
   { ult‚rieurement m‚moriser le nouveau contenu de BP et l'adresse de }
                                                  { retour sur la pile }

  JB.SP := Sptr + 12 - 6 - 6;

  SetJmp := -1;     { Indique qu'il ne s'agit pas d'un appel … LongJmp }
end;

{**********************************************************************}
{ LongJmp : GOTO interproc‚dural, qui poursuit l'ex‚cution du          }
{           programme … la ligne o— SetJmp a ‚t‚ appel‚                }
{----------------------------------------------------------------------}
{ Entr‚e  : JB      : Buffer de branchement rempli par SetJmp          }
{           RetCode : R‚sultat … renvoyer par SetJmp                   }
{**********************************************************************}

procedure LongJmp( JB : JMPBUF; RetCode : integer );

type WordP  = ^word;                             { Pointeur sur un mot }

begin
  WordP( ptr( SSeg, JB.SP   ) )^ := JB.BP;
  WordP( ptr( SSeg, JB.SP+2 ) )^ := JB.IP;
  WordP( ptr( SSeg, JB.Sp+4 ) )^ := JB.CS;

                  {-- Charge en AX le code de retour transmis ce qui --}
                                    {-- simule le r‚sultat de SetJmp --}

  inline( $8b / $46 / $06 );                           { mov ax,[bp+6] }

  inline( $8b / $ae / $fa / $ff );                     { mov bp,[bp-6] }

          { mov   sp,bp         ;Ces instructions sont automatiquement }
                    { pop   bp            ;g‚n‚r‚es par le compilateur }
                       { ret   6             ;restaurant ainsi la pile }
end;

{$F-}

{**********************************************************************}
{ GetPortAdr : Initialise les adresses des ports d'une interface       }
{              parallŠle c'est-…-dire les variables InPort et OutPort  }
{ Entr‚e        : NUMERO = Num‚ro de l'interface parallŠle (1-4)       }
{ Sortie        : TRUE, si interface valide                            }
{ Var. globales : InPort/W, OutPort/W                                  }
{ Info          : Les adresses de base des interfaces parallŠles       }
{                 (en nombre de 1 … 4)  se trouvent dans les mots      }
{                 m‚moire commen‡ant en 0040:0008                      }
{**********************************************************************}

function GetPortAdr( Numero : integer ) : boolean;

begin
 {-- Lit els adresses des ports dans le segment des variables du BIOS--}
  OutPort := MemW[ $0040: 6 + Numero * 2 ];
  if ( OutPort <> 0 ) then                    { Interface disponible ? }
    begin                                                        { Oui }
      InPort := OutPort + 1;          { Adresse pour registre d'entr‚e }
      GetPortAdr := TRUE;                         { Retour sans erreur }
    end
  else
  GetPortAdr := FALSE;                     { Erreur: interface absente }
end;

{**********************************************************************}
{ Port_Init     : Initialise les registres n‚cessaires … la            }
{                 transmission                                         }
{ Entr‚es       : EMETTEUR = TRUE, si ‚metteur, FALSE, si r‚cepteur    }
{ Sortie        : TRUE, si registres correctement initialis‚s          }
{ Var. globales : InPort/R, OutPort/R                                  }
{ Info          : La dissym‚trie: envoie 00010000 , attend 00000000    }
{                 est rendue n‚cessaire par l'inversion du signal      }
{                 Normalement les registres d'entr‚e et de sortie      }
{                 contiennent les valeurs souhait‚es mais              }
{                 l'initialisation est n‚cessaire lorsqu'on reprend une}
{                 transmission interrompue.                            }
{**********************************************************************}

function Port_Init( Emetteur : boolean ) : boolean;

begin
  EscapeDirect( TRUE );              { D‚clenche un Time out si Escape }
  if ( Emetteur ) then                 { L'ordinateur est-il ‚metteur? }
    begin
      TO_Count := Timeout * 5;    { Initialise le compteur de Time Out }
      PutB( $10 );                                { Envoie : 00010000b }
      while ( ( GetB <> $00 ) and ( TO_Count > 0 ) ) do     { Attend 0 }
        ;
    end
  else                                    { L'ordinateur est r‚cepteur }
    begin
      TO_Count := Timeout * 5;    { Initialise le compteur de Time Out }
      while ( ( GetB <> $00 ) and ( TO_Count > 0 ) ) do     { Attend 0 }
        ;
      PutB( $10 );                                 { Envoie: 00010000b }
    end;
  EscapeDirect( FALSE );                    { Si Escape pas de Timeout }
  Port_Init := ( TO_Count > 0 );             { Initialisation termin‚e }
end;

{**********************************************************************}
{ EmetOctet     : Envoie un octet en deux parties … l'ordinateur       }
{                 distant et teste le r‚sultat                         }
{ Entr‚es       : VALEUR = octet … ‚mettre                             }
{ Sortie        : Transmission correcte ? ( 0 = Erreur , -1 = ok )     }
{ Var. globales : Timeout/R, InPort/R, OutPort/R (dans Macros)         }
{**********************************************************************}

function EmetOctet( Wert : byte ) : boolean;

var Retour : byte;                                 { Octet r‚ceptionn‚ }

begin
         {-- Emet le quartet inf‚rieur --------------------------------}

  TO_Count := Timeout;            { Initialise le compteur de Time Out }
  PutB( Wert and $0F );                  { Envoi avec mise … 0 de BUSY }
  while ( ( ( GetB and 128 ) = 0 ) and ( TO_Count > 0 ) ) do
    ;
  if ( TO_Count = 0 ) then                      { Erreur de Time Out ? }
    longjmp( Branchement, LJ_TIMEOUT );   { Interrompt la transmission }

  Retour := ( GetB shr 3 ) and $0F;                  { Bits 3-6 en 0-3 }

  {-- Emet le quartet sup‚rieur ---------------------------------------}

  TO_Count := Timeout;            { Initialise le compteur de Time Out }
  PutB( ( Wert shr 4 ) or $10 );        { Envoie avec mise … 1 de BUSY }
  while ( ( ( GetB and 128 ) <> 0 ) and ( TO_Count > 0 ) ) do

  if ( TO_Count = 0 ) then                         { Erreur de Timeout }
    longjmp( Branchement, LJ_TIMEOUT );   { Interrompt la transmission }

  Retour := Retour or ( ( GetB shl 1 ) and $F0 );    { Bits 3-6 en 4-7 }
  EmetOctet :=  ( Wert = Retour );     { Octet correctement transmis ? }
end;

{**********************************************************************}
{ RecOctet      : R‚ceptionne un octet en deux parties de la part d'un }
{                 ordinateur distant et renvoie les parties pour       }
{                 v‚rification                                         }
{ Entr‚es       : aucune                                               }
{ Sortie        : octet re‡u                                           }
{ Var. globales : Timeout/R, InPort/R, OutPort/R ( Macros )            }
{**********************************************************************}

function RecOctet : byte;

var LoNib,
    HiNib : byte;                                     { Quartets re‡us }

begin
  {-- R‚ceptionne et renvoie le quartet inf‚rieur ---------------------}

  TO_Count := Timeout;            { Initialise le compteur de Time Out }
  while ( ( ( GetB and 128 ) = 0 ) and ( TO_Count > 0 ) ) do
    ;

  if ( TO_Count = 0 ) then                      { Erreur de Time Out ? }
    longjmp( Branchement, LJ_TIMEOUT );   { Interrompt la transmission }

  LoNib := ( GetB shr 3 ) and $0F;                   { Bits 3-6 en 0-3 }
  PutB( LoNib );                              { Retour … l'exp‚diteur  }

  {-- R‚ceptionne et renvoie le quartet sup‚rieur ---------------------}

  TO_Count := Timeout;             { Initialise le compteur de Timeout }
  while ( ( ( GetB and 128 ) <> 0 ) and ( TO_Count > 0 ) ) do
    ;

  if ( TO_Count = 0 ) then                      { Erreur de Time Out ? }
    longjmp( Branchement, LJ_TIMEOUT );   { Interrompt la transmission }

  HiNib := ( GetB shl 1 ) and $F0;                   { Bits 3-6 en 4-7 }
  PutB( ( HiNib shr 4 ) or $10 );     { Renvoie en let
      Busy … 1 }

  RecOctet := ( LoNib or HiNib );                         { Octet re‡u }
end;

{**********************************************************************}
{ EmetBloc : Emmet un bloc de donn‚es                                  }
{ Entr‚e   : TOKEN  = Commande pour le r‚cepteur                       }
{            NOMBRE = Nombre d'octets … transmettre                    }
{            DPTR   = Pointeur sur le buffer des donn‚es               }
{ Sortie   : n‚ant, en cas d'erreur branchement par LongJmp … la       }
{            routine de traitement d'erreur                            }
{**********************************************************************}

procedure EmetBloc( Token  : byte;
                    Nombre : word;
                    Dptr   : pointer );

var header     : BHEADER;     { En-tˆte pour m‚morise Token et  Nombre }
    RecEscape : byte;{ Entr‚e la touche ESC sur l'ordinateur distant ? }
    ok         : boolean;                        { Indicateur d'erreur }
    i          : word;                         { Compteur d'it‚rations }
    try        : word;               { Nombre de tentatives restantes  }
    Donnees      : ^DBloc;              { Pointeur sur bloc de donn‚es }

begin
  if ( Escape ) then         { A-t-on tap‚ Escape sur cet ordinateur ? }
    begin
      Token := TOK_ESCAPE;             { Oui, ‚mettre  le token Escape }
      Nombre := 0;
    end;

       {-- Emission de l'en-tˆte --------------------------------------}

  header.Token := Token;                         { Construit l'en-tˆte }
  header.Len := Nombre;

  try := MAX_TRY;
  repeat                               { AU maximum MAX_TRY tentatives }
    ok := TRUE;                   { A priori la transmission est bonne }
    for i := 0 to 2 do
      ok := ok and EmetOctet( Header.Champ[ i ] );     { Emet un octet }
    if ( ok ) then
      ok := ok and EmetOctet( ACK )                     { Confirmation }
    else
      ok := ok and EmetOctet( NAK );                    { Confirmation }
    if ( not ok ) then                                      { Erreur ? }
      dec( try );                               { Oui, autre tentative }
  until ( ( ok ) or ( try =  0 ) );

  if ( try = 0 ) then            { L'en-tˆte a-t-il pu ˆtre transmis ? }
    longjmp( Branchement, LJ_DATA ); { Non, interrompt la transmission }

  if ( Token = TOK_ESCAPE ) then     { A-t-on envoy‚ l'avis d'ESCAPE ? }
    longjmp( Branchement, LJ_ESCAPE );  { Oui, interrompt transmission }

    {-- Emission du bloc de donn‚es proprement dit---------------------}

  if ( Nombre > 0 ) then                         { Taille diff de 0  ? }
    begin
      Donnees := DPTR;
      try := MAX_TRY;
      repeat
    ok := TRUE;                   { A priori la transmission est bonne }
        for i := 1 to Nombre do
          ok := ok and EmetOctet( Donnees^[ i ] );
        if ( ok ) then
      ok := ok and EmetOctet( ACK )                     { Confirmation }
        else
      ok := ok and EmetOctet( NAK );
    if ( not ok ) then                                      { Erreur ? }
      dec( try );                            { Oui, nouvelle tentative }
      until ( ( ok ) or ( try =  0 ) );
      if ( try = 0 ) then { Le bloc de donn‚es transmis correctement ? }
    longjmp( Branchement, LJ_DATA ); { Non, interrompt la transmission }
    end;

  {-- Teste l'octet ESCAPE du r‚cepteur  ------------------------------}

  try := MAX_TRY;
  repeat
    RecEscape:=RecOctet;                   { D‚tecte un Escape distant }
    dec( try );
  until ( ( RecEscape = byte( true ) ) or
          ( RecEscape = byte( false ) ) );

  if ( try = 0 ) then                { Etat de la touche Escape re‡u ? }
    longjmp( Branchement, LJ_DATA ); { Non, interrompt la transmission }

  if ( RecEscape = byte( true ) ) then { Esc. sur ordinateur distant ? }
    longjmp( Branchement, LJ_REMESCAPE );{ Oui interrompt transmission }
end;

{**********************************************************************}
{ RecBloc : R‚ceptionne un bloc de donn‚es                             }
{ Entr‚es : TOKEN  = Pointeur sur la variable qui m‚morise le token    }
{           LEN    = Pointeur sur la variable qui m‚morise la longueur }
{           DONNEES  = Pointeur sur le buffer des donn‚es              }
{ Sortie  : n‚ant, en cas d'erreur branchement sur routine d'erreur    }
{           par LongJmp                                                }
{ Info    : Le buffer translis doit pr‚voir de la place pour           }
{           MAXBLOC octets, la taille du bloc ne pouvant               }
{           ˆtre anticip‚e                                             }
{**********************************************************************}

procedure RecBloc( var Token : byte;
                         var Len   : word;
                             Dptr  : pointer );

var header       : BHEADER;             { En-tˆte pour Token et Nombre }
    ok           : boolean;                      { Indicateur d'erreur }
    i            : word;                       { Compteur d'it‚rations }
    try          : word;              { Nombre de tentatives restantes }
    EscapeStatus : boolean;
    ByteBuffer   : byte;
    Donnees        : ^DBloc;            { Pointeur sur bloc de donn‚es }

begin
       {-- R‚ceptionne d'abord l'en-tˆte ------------------------------}

  try := MAX_TRY;
  repeat
    for i:= 0 to 2 do
      Header.Champ[ i ] := RecOctet;

    ByteBuffer := RecOctet;
    if ( ByteBuffer <> ACK ) then      { Tous les octets bien re‡us  ? }
      dec( try );                     { Oui, pas de nouvelle tentative }
  until ( ( try = 0 ) or ( ByteBuffer = ACK ) );

  if ( try = 0 ) then                    { En-tˆte correctement re‡u ? }
    longjmp( Branchement, LJ_DATA );  { Non Interrompt la transmission }

  Token := Header.Token;
  Len := Header.Len;
  if ( Token = TOK_ESCAPE ) then                    { Emetteur ESCAPE? }
    longjmp( Branchement, LJ_REMESCAPE );{ Oui interrompt transmission }

          {-- L'en-tˆte est bon, il faut passer au bloc des donn‚es. --}

  if ( Len > 0 ) then                       { Pas de bloc de donn‚es ? }
    begin                                                          { si}
      Donnees := Dptr;
      try := MAX_TRY;

      repeat                      { R‚ceptionne le bloc octet par octet}
        for i := 1 to len do
         Donnees^[ i ] := RecOctet;

         ByteBuffer := RecOctet;
     if ( ByteBuffer <> ACK ) then      { Tous les octets bien re‡us ? }
       dec( try );                    { Oui, pas de nouvelle tentative }
      until ( ( try = 0 ) or ( ByteBuffer = ACK ) );

      if ( try = 0 ) then              { Le bloc a-t-il ‚t‚ bien re‡u? }
    longjmp( Branchement, LJ_DATA ); { Non, interrompt la transmission }
    end;

 {-- Envoie … l'ordinateur distant l'‚tat actuel de la touche Escape --}

  EscapeStatus := Escape;                            { M‚morise l'‚tat }

  try := MAX_TRY;
  repeat
    dec( try );
  until ( EmetOctet( byte( EscapeStatus ) ) or ( try = 0 ) );

  if ( try = 0 ) then             { L'‚tat ESC a-t-il pu ˆtre envoy‚ ? }
    longjmp( Branchement, LJ_DATA ); { Non, interrompt la transmission }

  if ( EscapeStatus ) then {A-t-on actionn‚ Escape sur cet ordinateur ?}
    longjmp( Branchement, LJ_ESCAPE );  { Oui, interrompt transmission }
end;

{**********************************************************************}
{ EmetFichier : Emet un fichier                                        }
{ Entr‚es     : NAME = Nom de fichier                                  }
{ Sortie      : n‚ant                                                  }
{**********************************************************************}

procedure EmetFichier( Name : string );

var Status  : word;                                  { Etat d'‚mission }
    Lus : word;                                  { Nombre d'octets lus }
    Taille : longint;                        { Nombre d'octets envoy‚s }

begin
  write( copy( Name + '                   ', 1, 13 ) );
  assign( Fichier, Name );
  reset( Fichier, 1 );
  EmetBloc( TOK_DATSTART, length( Name ) + 1, @Name ); { Envoie le nom }

  {-- Transmet le contenu du fichier ----------------------------------}

  Taille := 0;
  repeat
    Blockread( Fichier, BlocBuf, MAXBLOC, Lus );         { Lit un bloc }
    if ( Lus > 0 ) then                                    { Termin‚ ? }
      begin               {                                      { Non }
    EmetBloc( TOK_DATNEXT, Lus, @BlocBuf );           { Envoie le bloc }
        inc( Taille, Lus );
        write( #13, copy( Name + '             ', 1, 13 ),
               '(', Taille, ')' );
      end;
  until (  Lus = 0 );
  writeln;

  EmetBloc( TOK_DONNEESD, 0, NIL );          { Cl“ture la transmission }

  close( Fichier );                               { Referme le fichier }
end;

{**********************************************************************}
{ RecFichier : R‚ceptionne un fichier                                  }
{ Entr‚es    : n‚ant                                                   }
{ Sortie     : Dernier token re‡u                                      }
{**********************************************************************}

function RecFichier : word;

var Status      : word;                            { Etat de r‚ception }
    AEnregistrer : word;                      { Taille du dernier bloc }
    Taille     : longint;
    Token       : byte;                                   { Token re‡u }
    Len         : word;                               { Longueur re‡ue }
    i           : word;                        { Compteur d'it‚rations }
    Name        : string[ 13 ];                       { Nom du fichier }

begin
  RecBloc( Token, Len, @BlocBuf );
  if ( Token = TOK_DATSTART ) then
    begin
      for i := 0 to BlocBuf[ 1 ] do
        Name[ i ] := chr( BlocBuf[ i + 1 ] );
      assign( Fichier, Name );
      rewrite( Fichier, 1 );
      write( copy( Name + '                   ', 1, 13 ) );

    {-- R‚ceptionne le contenu du fichier -----------------------------}

      Taille := 0;
      repeat
    RecBloc( Token, Len, @BlocBuf );             { R‚ceptionne un bloc }
    if ( Token = TOK_DATNEXT ) then      { Bloc de donn‚es cons‚cutif ?}
          begin                                                  { Oui }
        Blockwrite( Fichier, BlocBuf, Len );              { Enregistre }
            inc( Taille, Len );
            write( #13, copy( Name + '             ', 1, 13 ),
                   '(', Taille, ')' );
          end;
      until ( TOKEN <> TOK_DATNEXT );
      close( Fichier );                           { Referme le fichier }
      writeln;
    end;
  RecFichier := Token;                      { Retourne l'‚tat d'erreur }
end;

{**********************************************************************}
{                             PROGRAMME PRINCIPAL                      }
{**********************************************************************}

const Avis : array[ 0..8 ] of string =
          ( 'FIN: Tous les fichiers ont ‚t‚ correctement ‚mis.',
        'FIN: Tous les fichiers ont ‚t‚ correctement re‡us.',
        'ERREUR: Time-Out, le systŠme distant ne r‚pond pas.',
        'FIN: Interruption par Escape.',
        'FIN: Interruption par Escapr sur l''ordinateur distant.',
        'ERREUR: Interface ou cƒble d‚fectueux !',
        'ERREUR: Pas de contact avec l''ordinateur distant.',
        'ERREUR: L''interface indiqu‚e n''existe pas !',
        'ERREUR: ParamŠtre inconnu ou invalide !' );

var SRec     : SearchRec;{ Structure pour recherche dans un r‚pertoire }
    Emetteur   : boolean;{ Mode de transmission (Emetteur, r‚cepteur ) }
    sjStatus : integer;                             { Code de longjump }
    Numero,                                    { Num‚ro de l'interface }
    i,                                                      { Compteur }
    Trouve : byte;                    { Pour la recherche des fichiers }
    dummy    : integer;
    argv     : array[ 1..10 ] of string;                  { ParamŠtres }


begin
  write( #13#10'Transmission de donn‚es par l''interface parallŠle' );
  writeln( '   (c) 1991 by Michael Tischer' );
  write( '=================================================' );
  writeln( '==============================' );

  Escape := false;
  Timeout := TO_DEFAULT;

  if ( paramstr( 1 ) = '?' ) then           { Affiche juste la syntaxe }
    begin                                                        { Oui }
      writeln( 'Appel: plinkc [/Pn] [/Tnn] [Nom de fichier]' );
      halt( 0 );
    end;

  sjStatus := setjmp( Branchement ); { Adresse de retour pour terminer }
  if ( sjStatus > 0 ) then                          { Longjmp appel‚ ? }
    begin                                                        { Oui }
      Intr_remove;    { d‚sactive le gestionnaire
     d'interruption }
      writeln( #13#10#13#10, Avis[ sjStatus - 1 ] );
      halt( 0 );
    end;

  Intr_Install( @Escape, @TO_Count );{Initialise le driver d'interrupt.}

 {-- Fixe les paramŠtres par d‚faut et exploite la ligne de commande --}

 Emetteur := FALSE;            { Par d‚faut l'ordinateur est r‚cepteur }
 Numero := 1;                                    { et l'interface LPT1 }

 for i := 1 to paramcount do
   begin
     argv[ i ] := paramstr( i );             { m‚morise les paramŠtres }
     if ( argv[ i, 1 ] = '/' ) then
       begin
         case ( upcase( argv[ i, 2 ] ) ) of
           'T' : begin
                   delete( argv[ i ], 1, 2 );
                   val( argv[ i ], Timeout, dummy );
                   Timeout := ( Timeout * DIXSEC ) div 10;
                   if ( Timeout = 0 ) then
             longjmp( Branchement, LJ_PARA );              { incorrect }
                 end;
           'P' : begin
           Numero := ord( argv[ i, 3 ] ) - 48;             { Interface }
                   if ( ( Numero = 0 ) or ( Numero > 4 ) ) then
             longjmp( Branchement, LJ_PARA );              { incorrect }
                 end;
       else longjmp( Branchement, LJ_PARA );                 { inconnu }
         end;
     argv[ i ] := '';                              { Efface l'argument }
       end
     else                                { Doit ˆtre un nom de fichier }
       Emetteur := TRUE;                                    { Emetteur }
   end;

 {-- D‚marre la transmission ------------------------------------------}

 if ( not GetPortAdr( Numero ) ) then    { L'interface existe-t-elle ? }
   longjmp( Branchement, LJ_NOPAR );                     { Non, erreur }

 if ( not Port_Init( Emetteur ) ) then            { Etablit la liaison }
   longjmp( Branchement, LJ_NOLINK );             { Erreur, impossible }

 if ( Emetteur ) then                                      { Emetteur? }
   begin
     writeln( 'Emission vers LPT', Numero, #13#10 );

     {-- Transmet tous les fichiers -----------------------------------}

     for i := 1 to paramcount do       { Parcourt la ligne de commande }
       begin
     if ( argv[ i ] <> '' ) then                    { Nom de fichier ? }
           begin                                                 { Oui }
             findfirst( argv[ i ], AnyFile, SRec);
         while ( DosError = 0 ) do                 { Tant qu'il y en a }
               begin
                 if ( SRec.Attr <> Directory ) then
           EmetFichier( SRec.Name );             { Transmet le fichier }
                 findnext( SRec );
               end;
           end;
       end;
     EmetBloc( TOK_FIN, 0 , NIL );            { Tous les fichiers ‚mis }
     longjmp( Branchement, LJ_OKEMETTEUR );
   end
 else                                                 { Non, R‚cepteur }
   begin
     writeln( 'R‚ception sur LPT', Numero, #13#10 );
     while ( RecFichier <> TOK_FIN ) do     { R‚ceptionne les fichiers }
       ;                                       { jusqu'au token de FIN }
     longjmp( Branchement, LJ_OKRECEPT );
   end;
end.
