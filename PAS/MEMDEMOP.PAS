{**********************************************************************}
{*                        M E M D E M O P . P A S                     *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Montre comment DOS gŠre la m‚moire             *}
{*--------------------------------------------------------------------*}
{*    Auteur         : Michael TISCHER                                *}
{*    D‚velopp‚ le   : 08.10.1991                                     *}
{*    DerniŠre MAJ   : 20.03.1992                                     *}
{**********************************************************************}

{$M 8096, 0, 10240 }

program MEMDEMOP;

uses crt,                                        { IntŠgre l'unit‚ CRT }
     dos;                                        { IntŠgre l'unit‚ DOS }

{== Constantes ========================================================}

const
{-------- Num‚ros des fonctions de l'interruption 21h------------------}

      GET_MEM      = $48;                 { R‚serve de la m‚moire vive }
      FREE_MEM     = $49;                  { LibŠre de la m‚moire vive }
      CHANGE_MEM   = $4A;    { Modifie la taille d'une zone de m‚moire }
      GET_STRATEGY = $5800;            { Lit la strat‚gie d'allocation }
      SET_STRATEGY = $5801;           { Fixe la strat‚gie d'allocation }
      GET_UMB      = $5802;     { Lit l'‚tat d'inclusion des blocs UMB }
      SET_UMB      = $5803;           { Fixe l'inclusion des blocs UMB }

{-- Strat‚gies de recherche pour FixeStrategie ------------------------}

      CHERCHE_ENBAS    = $00;          { premier bloc de m‚moire libre }
      CHERCHE_MEILLEUR = $01;         { meilleur bloc de m‚moire libre }
      CHERCHE_ENHAUT   = $02;          { dernier bloc de m‚moire libre }
      DABORD_UMB       = $80;              { Chercher dans la zone UMB }
                                         { utiliser avec CHERCHE_....) }

{-------- Constantes pour FixeUMB -------------------------------------}

      UMB_NON = $00;               { Ne tient pas compte des blocs UMB }
      UMB_OUI = $01;                            { Alloue des blocs UMB }

{------- Constantes pour Demo -----------------------------------------}

      TEST_TA        = 10240-1;          { 10239 paragraphes pour test }
      TEST_TA_UMB    = 2560-1;      { 2559 paragraphes d'UMB pour test }
      TEST_TA_KB     = 160;           { Environnement de test = 160 Ko }
      TEST_TA_UMB_KB = 40;         { Environnement de test UMB = 40 Ko }
      NBREBLOC       = 26;     { Nbre d'adresses pour aff. du r‚sultat }

{-- Codes de touches pour saisie utilisateur --------------------------}

      ESC  = #27;                               { Interruption par ESC }
      F1   = #59;                              { Touche de fonction F1 }
      F2   = #60;                              { Touche de fonction F2 }
      F3   = #61;                              { Touche de fonction F3 }
      F8   = #66;                              { Touche de fonction F8 }
      F9   = #67;                              { Touche de fonction F9 }
      F10  = #68;                             { Touche de fonction F10 }

{== D‚clarations de types =============================================}

type  BlocTyp = record           { Gestion d'un bloc de m‚moire allou‚ }
           Adresse,                                          { Segment }
           Taille : word;                       { Taille du bloc en Ko }
                 end;

{== Typisierte Constantes =============================================}

const OuiNon     : array[ false..true ] of string =
           ( 'Non ', 'Oui ' );
      SText      : array[ CHERCHE_ENBAS..CHERCHE_ENHAUT ] of string =
           ( 'Utiliser le premier bloc de m‚moire libre ',
             'Utiliser le meilleur bloc de m‚moire libre',
             'Utiliser le dernier bloc de m‚moire libre ' );
      ChampCouleur: array[ 0..1 ] of byte   =
           ( $07, $70 );
      TexteTouche : array[ 0..3 ] of string =
           ( ' [F1]  Allouer de la m‚moire',
             ' [F2]  Lib‚rer de la m‚moire',
             ' [F3]  Modifier la taille ',
             ' [ESC] Fin du programme ' );

{== Variables globales=================================================}

var Regs         : Registers;              { Registres d'interruptions }
    ChampAdresse : array[ 0..1000 ] of word;       { Champ de m‚moires }
    NbAdresse    : word;                           { Nombre d'adresses }
    SegConv      : word;        { Adr. bloc de test dans m‚moire conv. }
    UMBSeg       : word;           { Adr. bloc de test en m‚moire sup. }
    BlocChamp    : array[ 0..NBREBLOC - 1 ] of BlocTyp;      { M‚moire }

{***********************************************************************
* DOS_GetMem : R‚serve de la m‚moire                                   *
* Entr‚e     : Taille m‚moire souhait‚e en paragraphes                 *
* Sortie     : Segment du bloc de m‚moire allou‚ ,                     *
*              Nombre de paragraphes allou‚s ou nombre maximal  des    *
*              paragraphes disponibles                                 *
***********************************************************************}

procedure DOS_GetMem(     Ta  : word;
                      var Adr : word;
                      var Res : word );

begin
  with Regs do
    begin
      ah := GET_MEM;                              { Num‚ro de fonction }
      bx := Ta;                     { Nombre de paragraphes … r‚server }
      msdos( Regs );                       { D‚clenche  l'interruption }
      if( flags and fcarry = 0 ) then                 { Appel r‚ussi ? }
        begin
          Adr := regs.ax;       { Oui, restitue l'adresse et la taille }
          Res := Ta;
        end
      else                                               { Non ,erreur }
        begin
          Adr := 0;                          { pas de m‚moire r‚serv‚e }
          Res := bx;                      { Taille disponible maximale }
        end;
    end;
end;

{***********************************************************************
* DOS_FreeMem : LibŠre de la m‚moire pr‚alablement r‚serv‚e            *
* Entr‚e      : Segment de la m‚moire                                  *
* Sortiee     : n‚ant                                                  *
***********************************************************************}

procedure DOS_FreeMem( Adr : word );

begin
  with Regs do
    begin
      ah := FREE_MEM;                          { Num‚ro de la fonction }
      es := Adr;                     { Adresse de la m‚moire … lib‚rer }
      msdos( Regs );                        { D‚clenche l'interruption }
    end;
end;

{***********************************************************************
* DOS_ChangeMem : Change la taille d'un bloc r‚serv‚                   *
* Entr‚e       : Ancien segment, nvelle taille souhait‚e (paragraphes) *
* Sortie       : Segment du bloc allou‚                                *
*                 Nombre de paragraphes allou‚s ou nombre maximal      *
*                 de paragraphes disponibles                           *
***********************************************************************}

procedure DOS_ChangeMem(     Ta  : word;
                         var Adr : word;
                         var Res : word );
begin
  with Regs do
    begin
      ah := CHANGE_MEM;                        { Num‚ro de la fonction }
      bx := Ta;                     { Nombre de paragraphes … r‚server }
      es := Adr;               { Segment du bloc de m‚moire … modifier }
      msdos( Regs );                        { D‚clenche l'interruption }
      if( flags and fcarry = 0 ) then                 { Appel r‚ussi ? }
        Res := Ta                            { Nouvelle taille m‚moire }
      else                                               { Non, erreur }
        Res := bx;                        { Taille maximale disponible }
    end;
end;

{***********************************************************************
* LitStrategie : Lit la strat‚gie de gestion de la m‚moire             *
* Entr‚e       : n‚ant                                                 *
* Sortie       : Type de strat‚gie                                     *
***********************************************************************}

function LitStrategie : integer;

begin
  with Regs do
    begin
      ax := GET_STRATEGY;              { Fixe le num‚ro de la fonction }
      msdos( Regs );                        { D‚clenche l'interruption }
      LitStrategie := ax;                       { Retourne la strat‚gie}
    end;
end;

{***********************************************************************
* LitUMB       : Lit l'‚tat d'inclusion des blocs UMB                  *
* Entr‚e       : n‚ant                                                 *
* Sortie       : Indique si les blocs UMB sont pris en compte          *
* Info          : Disponible … partir de MS-DOS version 5.0            *
***********************************************************************}

function LitUMB : integer;

begin
  with Regs do
    begin
      ax := GET_UMB;                   { Fixe le num‚ro de la fonction }
      msdos( Regs );                        { D‚clenche l'interruption }
      LitUMB := al;                                  { Retourne l'‚tat }
    end;
end;

{***********************************************************************
* FixeStrategie: Fixe la strat‚gie d'allocation de la m‚moire          *
* Entr‚e       : Nouveau type de strat‚gie souhait‚e                   *
* Sortie       : n‚ant                                                 *
***********************************************************************}

procedure FixeStrategie( Strategie : integer );

begin
  with Regs do
    begin
      ax := SET_STRATEGY;              { Fixe le num‚ro de la fonction }
      bx := Strategie;
      msdos( Regs );                        { D‚clenche l'interruption }
    end;
end;

{***********************************************************************
* FixeUMB      : Fixe l'‚tat d'inclusion des blocs de m‚moire UMB      *
* Entr‚e       : Nouvel ‚tat d'inclusion souhait‚                      *
* Sortie       : n‚ant                                                 *
* Info         : Disponible … partir de la version 5.0 de MS-DOS       *
***********************************************************************}

procedure FixeUMB( UMB : integer );

begin
  with Regs do
    begin
      ax := SET_UMB;                   { Fixe le num‚ro de la fonction }
      bx := UMB;
      msdos( Regs );                        { D‚clenche l'interruption }
    end;
end;

{***********************************************************************
* AlloueMemoire   : Cr‚e l'environnement du test                       *
* Entr‚e          : n‚ant                                              *
* Sortie          : n‚ant                                              *
***********************************************************************}

procedure AlloueMemoire;

var SegAdr    : word;                  { Segment de la m‚moire allou‚e }
    Essai     : word;                    { Taille de m‚moire souhait‚e }
    Taille    : word;           { Taille de la zone de m‚moire allou‚e }

begin
      {-- Alloue le  bloc de test--------------------------------------}

  FixeUMB( UMB_NON );                     { En m‚moire conventionnelle }
  DOS_GetMem( TEST_TA, SegConv, Taille );             { Cherche le bloc}

  if ( SegConv = 0 ) then                                    { Erreur? }
    exit;                 { Pas de bloc de test, terminer la proc‚dure }


  FixeUMB( UMB_OUI );             { Bloc de test en m‚moire sup‚rieure }
  FixeStrategie( CHERCHE_ENHAUT or DABORD_UMB );
  DOS_GetMem( TEST_TA_UMB, UMBSeg, Taille );
  if( UMBSeg <> 0 ) and ( UMBSeg < $A000 ) then   { Pas de blocs UMB ? }
    begin
      DOS_FreeMem( UMBSeg );                       { LibŠre la m‚moire }
      UMBSeg := 0;                              { Absence de blocs UMB }
    end;

  {-- Alloue la m‚moire conv. restante et la m‚moire sup‚rieure -------}
  {--    par blocs de 1 Ko                                          ---}

  Essai := 63;               { Essaie d'abord d'allouer 15 paragraphes }
  NbAdresse := 0;      { Initialise le nombre de blocs de 1 Ko allou‚s }
  repeat
    DOS_GetMem( Essai, SegAdr, Taille );       { R‚clame de la m‚moire }
    if ( SegAdr <> 0 ) then                    { Est-elle disponible ? }
      begin
        ChampAdresse[ NbAdresse ] := SegAdr;      { M‚morise l'adresse }
        inc( NbAdresse );
      end;
  until( SegAdr = 0 );                               { Tout est allou‚ }

    {-- 3ø LibŠre … nouveau les blocs de test--------------------------}

  if( SegConv > 0 ) then           { M‚moire conventionnelle allou‚e ? }
    begin                                                        { Oui }
      DOS_FreeMem( SegConv );
      dec( SegConv );                           { MCB ‚galement lib‚r‚ }
    end;
  if( UMBSeg > 0 ) then                 { M‚moire sup‚rieure allou‚e ? }
    begin                                                        { Oui }
      DOS_FreeMem( UMBSeg );
      dec( UMBSeg );                            { MCB ‚galement lib‚r‚ }
    end;
end;

{***********************************************************************
* LibereMemoire   : LibŠre la m‚moire allou‚e par AlloueMemoire        *
* Entr‚e          : n‚ant                                              *
* Sortie          : n‚ant                                              *
* Variables glob. : ChampAdresse/R                                     *
***********************************************************************}

procedure LibereMemoire;

var i : word;                                               { Compteur }

begin
  if( NbAdresse > 0 ) then             { A-t-on allou‚ de la m‚moire ? }
    for i := 0 to NbAdresse - 1 do      { Oui, la libŠre bloc par bloc }
      DOS_FreeMem( ChampAdresse[ i ] );
end;

{***********************************************************************
* AfficheResultat : Affiche l'occupation de la m‚moire                 *
* Entr‚e          : AVECCADRE = TRUE, si le cadre doit ‚galement ˆtre  *
*                                affich‚                               *
* Sortie          : n‚ant                                              *
***********************************************************************}

procedure AfficheResultat( AvecCadre : boolean );

var SChamp      : array[ 0..TEST_TA_KB - 1 ] of char;
    SChamp_UMB  : array[ 0..TEST_TA_UMB_KB - 1 ] of char;
    i,j         : word;                                    { Compteurs }
    Position    : word;                          { Variable auxiliaire }
    Sdummy      : string;
    DerCara     : char;        { M‚morise le dernier caractŠre affich‚ }
    CoulCour    : byte;                 { Couleur d'affichage courante }

begin
  fillchar( SChamp[ 0 ], TEST_TA_KB, #32 );       { Champs d'affichage }
  fillchar( SChamp_UMB[ 0 ], TEST_TA_UMB_KB, #32 );

  {-- Remplit le tableau de la m‚moire --------------------------------}

  for i := 0 to NBREBLOC - 1 do
    begin
      if( BlocChamp[ i ].Adresse > $A000 ) then                 { UMB? }
        begin
          Position := ( BlocChamp[ i ].Adresse - UMBSeg ) div 64;
          for j := 0 to BlocChamp[ i ].Taille div 64 do
            SChamp_UMB[ Position + j ] := chr( i + 65 );
        end
      else if( BlocChamp[ i ].Adresse > 0 ) then
        begin
          Position := ( BlocChamp[ i ].Adresse - SegConv ) div 64;
          for j := 0 to BlocChamp[ i ].Taille div 64 do
            SChamp[ Position + j ] := chr( i + 65 );
        end;
    end;

          {-- Dessine le cadre du tableau -----------------------------}

  if( AvecCadre ) then
    begin
      writeln( 'M‚moire conventionnelle :' );
      writeln( '                   1         2         3         4 ' );
      writeln( '          1        0         0         0         0 ' );
      writeln( 'ÉÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»' );
      for i := 0 to 3 do
        begin
          str( i * 40 : 3, Sdummy );
          writeln( 'º ' + Sdummy +
                   ' Ko º                                        º',
                   TexteTouche[ i ] );
        end;
      writeln( 'ÈÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼' );
      if ( UMBSeg > 0 ) then
       begin
        writeln(#13#10'UMB:' );
        writeln('                   1         2         3         4 ');
        writeln('          1        0         0         0         0 ');
        writeln('ÉÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»');
        writeln('º   0 KB º                                        º');
        writeln('ÈÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼');
       end
      else
       writeln( #13#10, 'Pas d''UMB disponible' );
    end;

  {-- Affiche le tableau de la m‚moire conventionnelle ----------------}

  DerCara := #0;                           { Dernier caractŠre affich‚ }
  CoulCour := 0;                           { DerniŠre couleur affich‚e }
  for i := 0 to 3 do
    for j := 0 to 39 do
      begin
        if( DerCara <> SChamp[ i * 40 + j ] ) then  { Chang. couleur ? }
          begin
            CoulCour := ( CoulCour + 1 ) mod 2; { Nouveau code couleur }
            textcolor( ChampCouleur[ CoulCour ] shr 4 );
            textbackground( ChampCouleur[ CoulCour ] and $0F );
            DerCara := SChamp[ i * 40 + j ];       { Symbole d'‚galit‚ }
          end;
        gotoxy( j + 11, i + 11  );              { Affiche un caractŠre }
        write( SChamp[ i * 40 + j ] );
      end;

  {-- AFfiche le tableau de la m‚moire sup‚rieure ---------------------}

  if ( UMBSeg > 0 ) then
    begin
      for j := 0 to 39 do
        begin
          if( DerCara <> SChamp_UMB[ j ] ) then     { Chang. couleur ? }
            begin
              CoulCour := ( CoulCour + 1 ) mod 2;       { code couleur }
              textcolor( ChampCouleur[ CoulCour ] shr 4 );
              textbackground( ChampCouleur[ CoulCour ] and $0F );
              DerCara := SChamp_UMB[  j ];         { Symbole d'‚galit‚ }
            end;
          gotoxy( j + 11, 21  );
          write( SChamp_UMB[ j ] );
        end;
    end;
  textcolor( $07 );
  textbackground( $00 );
end;

{***********************************************************************
* Demo         : D‚monstration de la gestion de la m‚moire             *
* Entr‚e       : Inclusion des UMB, recherche a priori dans les UMB ,  *
*                strat‚gie d'allocation de la m‚moire                  *
* Sortie       : n‚ant                                                 *
* Info         : Les fonctions UMB sont disponibles qu'… partir de la  *
*                version 5.0 de DOS                                    *
***********************************************************************}

procedure Demo( Avec_UMB    : boolean;
                UMB_dabord : boolean;
                Strategie  : integer );


var i        : integer;                        { Compteur d'it‚rations }
    Touche   : char;                                  { Touche frapp‚e }
    Marqueur : char;     { Marqueur (A-Z) souhait‚ pour la r‚servation }
    Essai    : word;                        { Taille de la r‚servation }
    Taille   : word;
    sdummy   : string;

begin
  {-- Initialise les champs adresse et taille -------------------------}

  for i := 0 to NBREBLOC - 1 do            { Pas encore de bloc allou‚ }
    with BlocChamp[ i ] do
      begin
        Adresse := 0;                     { Segment du bloc de m‚moire }
        Taille := 0;                                  { Taille du bloc }
      end;

  gotoxy( 1, 7 );
  AfficheResultat( TRUE );                        { Affiche le tableau }

 {-- Boucle de d‚monstration ------------------------------------------}

  repeat
                        {-- Fixe la strat‚gie souhait‚e ---------------}

    if ( Avec_UMB ) then           { Exploiter la m‚moire sup‚rieure ? }
      FixeUMB( UMB_OUI )
    else
      FixeUMB( UMB_NON );

    if ( UMB_dabord ) then
      FixeStrategie( Strategie or DABORD_UMB )
    else
      FixeStrategie( Strategie );

    {-- Affiche la strat‚gie actuelle ---------------------------------}

    gotoxy( 1, 3 );
    writeln( ' [F8] Gestion m‚moire           : ', SText[ Strategie ]);
    writeln( ' [F9] Recherche dans l''UMB      : ', OuiNon[UMB_dabord]);
    writeln( '[F10] Utilisation des blocs UMB : ', OuiNon[Avec_UMB ]);
    writeln( '--------------------------------------------------',
             '----------------------------' );

    {-- Saisie et traitement     --------------------------------------}

    repeat until keypressed;             { Attend une frappe de touche }
    Touche := readkey;                                 { Lit la touche }
    if( ( Touche = #0 ) and ( keypressed ) ) then     { T. de fonction }
     Touche := readkey;                              { Lit le 2me code }

    case Touche of
      F1 :                                 { Alloue le bloc de m‚moire }
        begin
          i := -1;                         { pas encore de bloc valide }
          repeat
            gotoxy( 1, 23 );
            write( 'Quel bloc faut-il r‚server [ A-Z ]   : ' );
            readln( Marqueur );
            Marqueur := upcase( Marqueur );
            if( Marqueur >= 'A' ) and ( Marqueur <= 'Z' ) then
              if( BlocChamp[ ord( Marqueur ) - 65 ].Adresse = 0 ) then
                i := ord( Marqueur ) - 65;
          until( i <> - 1 );
          write( 'Combien de Ko faut-il r‚server       : ' );
          readln( Essai );

          Essai := Essai * 64 - 1;         { Conversion en paragraphes }
          DOS_GetMem( Essai, BlocChamp[ i ].Adresse,
                      BlocChamp[ i ].Taille );
          if( BlocChamp[ i ].Taille <> Essai ) then         { Erreur ? }
            begin
              str( ( BlocChamp[ i ].Taille + 1 ) div 64, sdummy );
              write( 'Il ne reste plus que ' + sdummy + 'Ko ' );
              repeat
              until keypressed;

              while keypressed do
                Touche := readkey;
              Touche := #0;
            end;
          gotoxy( 1, 23 );
          writeln( '                                             ' );
          writeln( '                                             ' );
          write  ( '                                             ' );
          gotoxy( 1, 7 );
          AfficheResultat( FALSE );               { Affiche le tableau }
        end;

      F2 :                                             { LibŠre le bloc}
        begin
          i := -1;                        { Pas encore de bloc valable }
          repeat
            gotoxy( 1, 23 );
            write( 'Quel bloc faut-il lib‚rer [ A-Z ]    : ' );
            readln( Marqueur );
            Marqueur := upcase( Marqueur );
            if( Marqueur >= 'A' ) and ( Marqueur <= 'Z' ) then
              if( BlocChamp[ ord( Marqueur ) - 65 ].Adresse <> 0 ) then
                i := ord( Marqueur ) - 65;
          until ( i <> - 1 );
          DOS_FreeMem( BlocChamp[ i ].Adresse );
          BlocChamp[ i ].Adresse := 0;
          BlocChamp[ i ].Taille := 0;
          gotoxy( 1, 23 );
          writeln( '                                             ' );
          gotoxy( 1, 7 );
          AfficheResultat( FALSE );               { Affiche le tableau }
        end;

      F3 :                               { Modifie la taille d'un bloc }
        begin
          i := -1;                         { Pas encore de bloc valide }
          repeat
            gotoxy( 1, 23 );
            write( 'De quel bloc faut-il changer la taille [ A-Z ]: ' );
            readln( Marqueur );
            Marqueur := upcase( Marqueur );
            if ( Marqueur >= 'A' ) and ( Marqueur <= 'Z' ) then
              if ( BlocChamp[ ord( Marqueur ) - 65 ].Adresse <> 0 ) then
                i := ord( Marqueur ) - 65;
          until ( i <> - 1 );
          write( 'Combien de Ko faut-il r‚server :     ' );
          readln( Essai );
          Essai := Essai * 64 - 1;         { Conversion en paragraphes }
          DOS_ChangeMem( Essai, BlocChamp[ i ].Adresse, Taille );
          if( Taille <> Essai ) then                        { Erreur ? }
            begin
              str( ( Taille + 1 ) div 64, sdummy );
              write( 'Il ne reste plus que ' + sdummy + 'Ko ' );
              repeat until keypressed;
              while keypressed do
                Touche := readkey;
              Touche := #0;
            end
          else
            BlocChamp[ i ].Taille := Taille;  { Fixe une nvelle taille }
          gotoxy( 1, 23 );
          writeln( '                                             ' );
          writeln( '                                             ' );
          write  ( '                                             ' );
          gotoxy( 1, 7 );
          AfficheResultat( FALSE );               { Affiche le tableau }
        end;

      F8 :
         Strategie := ( Strategie + 1 ) mod 3;   { Change de strat‚gie }

      F9 :                                 { Commutation : UMB d'abord }
         UMB_dabord := not UMB_dabord;

      F10:                             { Commutation : Inclure les UMB }
         avec_UMB := not avec_UMB;
    end;
  until( Touche = ESC );
end;

{***********************************************************************
***                     Programme principal                          ***
***********************************************************************}

var StartStrategie : integer;       { Strat‚gie d'allocation au d‚part }
    StartUMB       : integer;           { Etat des blocs UMB au d‚part }
    ActUMB_oui     : boolean;       { Utiliser les blocs UMB (oui/non) }
    ActUMB_dabord  : boolean;         { M‚moire sup‚rieure prioritaire }
    ActStrategie   : integer;        { Strat‚gie d'allocation actuelle }

begin
       {-- Sauvegarde les valeurs courantes ---------------------------}

  StartStrategie := LitStrategie;             { Strat‚gie d'allocation }
  StartUMB := LitUMB;       { Prise en compte de la m‚moire sup‚rieure }
  AlloueMemoire;                        { Cr‚e l'environnement du test }
  FixeStrategie( Startstrategie );     { Restaure l'ancienne strat‚gie }
  FixeUMB( StartUMB );

  if ( SegConv = 0 ) then          { M‚moire conventionnelle allou‚e ? }
    begin                                 { Non, on arrˆte avec erreur }
      clrscr;
      writeln('MEMDEMOP : M‚moire insuffisante !');
      exit;                                               { C'est fini }
    end;

       {-- Valeurs de d‚part pour la gestion de la m‚moire ------------}

  ActUMB_oui := ( StartUMB = UMB_OUI );
  ActUMB_dabord := ( ( StartStrategie and DABORD_UMB ) = DABORD_UMB );
  ActStrategie := StartStrategie and ( $FF xor DABORD_UMB );

       {-- D‚monstration de la gestion de la m‚moire ------------------}

  clrscr;
  writeln( 'Programme de gestion m‚moire DOS               ',
             '(C) 1991, 92 by Michael TISCHER' );
  writeln( '==================================================',
           '============================' );
  Demo( ACTUMB_oui, ACTUMB_dabord, ActStrategie );

       {-- Restaure les anciennes valeurs de DOS-----------------------}

  LibereMemoire;                           { LibŠre la m‚moire allou‚e }
  FixeStrategie( StartStrategie );
  FixeUMB( StartUMB );
  clrscr;
end.
