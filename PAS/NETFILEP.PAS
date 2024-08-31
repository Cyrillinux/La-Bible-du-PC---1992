{**********************************************************************}
{*                      N E T F I L E P . P A S                       *}
{*--------------------------------------------------------------------*}
{*    Fonction     : Propose diff‚rentes proc‚dures et fonctions pour *}
{*                   r‚aliser des programmes en r‚seau sous DOS       *}
{*--------------------------------------------------------------------*}
{*    Auteur       : Michael Tischer                                  *}
{*    D‚velopp‚ le : 10.02.1992                                       *}
{*    DerniŠre MAJ : 13.02.1991                                       *}
{**********************************************************************}

unit NetFileP;

interface

uses Crt, Dos;                         { IntŠgre les unit‚s CRT et DOS }

const           {-- Types d'accŠs -------------------------------------}

      FM_R    = 0;                                     { Lecture seule }
      FM_W    = 1;                                    { Ecriture seule }
      FM_RW   = 2;      { Mode ordinaire en Pascal: lecture et ‚criture}

{-- Modes de partage ou types de protection ---------------------------}

      SM_COMP = $00;                           { Mode de compatibilit‚ }
                                      { aucune protection des fichiers }
      SM_RW   = $10;         { Lecture et ‚criture externes interdites }
      SM_R    = $20;   { Lecture externe autoris‚e, ‚criture interdite }
      SM_W    = $30;   { Lecture externe interdite, ‚criture autoris‚e }
      SM_NO   = $40;                      { Tout est permis, protection}
                                   { par verrouillage d'enregistrement }

       {-- Erreurs possibles … l'appel des proc‚dures -----------------}

      NE_OK            = $00;                           { Pas d'erreur }
      NE_FileNotFound  = $02;            { Erreur: Fichier non trouv‚  }
      NE_PathNotFound  = $03;      { Erreur: chemin d'accŠs non trouv‚ }
      NE_TooManyFiles  = $04;       { Erreur: trop de fichiers ouverts }
      NE_AccessDenied  = $05;        { Erreur: AccŠs au fichier refus‚ }
      NE_InvalidHandle = $06;  { Erreur: Handle de fichier non valable }
      NE_AccessCode    = $07;          { Erreur: Type d'accŠs interdit }
      NE_Share = $20;                { Non respect des rŠgles de Share }
      NE_Lock          = $21;    { Erreur de (d‚)verrouillage d'enreg. }
      NE_ShareBuffer   = $24;         { D‚bordement du buffer de Share }

var NetError : integer;      { Code d'erreur aprŠs interruption de DOS }

function ShareInst : boolean;                       { Share install‚ ? }

function NetErrorMsg( Numero : word ) : string;     { Message d'erreur }

procedure NetReset(     FNom  : string;     { Ouvre un fichier existant}
                        Mode  : integer;
                        RecS   : word;
                    var Fichier );

procedure NetRewrite(     FNom  : string;   { Ouvre un nouveau fichier }
                          Mode  : integer;
                          RecS   : word;
                      var Fichier );

procedure NetClose( var Fichier );                { Referme un fichier }

function NetLock( var Fichier;       { Verrouile une zone d'un fichier }
                      RecNo  : longint;
                      Nombre : longint ) : boolean;

function NetUnlock( var Fichier;        { LibŠre une zone d'un fichier }
                        RecNo  : longint;
                        Nombre : longint ) : boolean;

function Is_NetOpen( var Fichier ) : boolean;        { Fichier ouvert ?}

function Is_NetWriteOk( var Fichier ) : boolean;    { Enreg. autoris‚ ?}

function Is_NetReadOk( var Fichier ) : boolean;    { Lecture permise ? }

          { Les proc‚dures Read, Write et Seek ne fonctionnent qu'avec }
        { les fichiers dont le mode d'accŠs est Input-Output mais pour }
     { l'utilisation en r‚seau les fichiers typ‚s doivent ˆtre ouverts }
         { dans d'autres modes, c'est pourquoi il faut faire appel aux }
                             { proc‚dures  de substitution qui suivent }

procedure NetWrite( var Fichier;            { Ecriture dans un fichier }
                    var Donnees );

procedure NetRead( var Fichier;              { Lecture dans un fichier }
                   var Donnees );

procedure NetSeek( var Fichier;           { Positionnement du pointeur }
                       RecNo : longint );

implementation

const {-- Num‚ros des fonctions pour les appels … DOS -----------------}

      FCT_OPEN     = $3D;  { Fonction: Ouvre un fichier avec un handle }
      FCT_CLOSE    = $3E;{ Fonction: Referme un fichier avec un handle }
      FCT_CREATE   = $3C;   { Fonction: Cr‚e un fichier avec un handle }
      FCT_WRITE    = $40;            { Fonction: Ecrit dans un fichier }
      FCT_READ     = $3F;              { Fonction: Lit dans un fichier }
      FCT_LSEEK    = $42;           { Fonction: Positionne le pointeur }
      FCT_REC_LOCK = $5C;    { Fonction: Verrouille des enregistrements}

                 {-- Num‚ros des fonctions pour autres interruptions --}

      MULTIPLEX    = $2F;               { Interruption du multiplexeur }
      FCT_SHARE    = $1000;             { Test d'installation de Share }

        {-- Marquage  des fichiers sous TP   --------------------------}

      FMCLOSED     = $D7B0;                            { Fichier ferm‚ }
      FMINPUT      = $D7B1;               { Fichier ouvert en lecture  }
      FMOUTPUT     = $D7B2;           { Fichier ouvert en ‚criture     }
      FMINOUT      = $D7B3;  { Fichier ouvert en lecture et ‚criture   }

{**********************************************************************}
{* ShareInst   : Test d'installation de Share                         *}
{* Entr‚e     : n‚ant                                                 *}
{* Sortie     : true si Share install‚                                *}
{* Var. globale NetError/W (Code erreur aprŠs appel)                  *}
{**********************************************************************}

function ShareInst : boolean;

var regs   : registers;       { Registres pour g‚rer les interruptions }

begin
 regs.ax := FCT_SHARE;                    { Teste si Share est pr‚sent }
 intr( MULTIPLEX, regs );     { Appelle l'interruption du multiplexeur }
 ShareInst := ( regs.al = $FF );                { Exploite le r‚sultat }
 NetError := NE_OK;                                     { pas d'erreur }
end;

{**********************************************************************}
{* NetErrorMsg : Texte des messages d'erreur                          *}
{* Entr‚e     : Code d'erreur                                         *}
{* Sortie     : Explication                                           *}
{**********************************************************************}

function NetErrorMsg( Numero : word ) : string;

var Sdummy : string;

begin
  case Numero of
    NE_OK            : NetErrorMsg := 'Pas d''erreur                 ';
    NE_FileNotFound  : NetErrorMsg := 'Fichier non trouv‚            ';
    NE_PathNotFound  : NetErrorMsg := 'Chemin d''accŠs non trouv‚    ';
    NE_TooManyFiles  : NetErrorMsg := 'Trop de fichiers ouverts      ';
    NE_AccessDenied  : NetErrorMsg := 'AccŠs au fichier refus‚       ';
    NE_InvalidHandle : NetErrorMsg := 'Handle de fichier non valide  ';
    NE_AccessCode    : NetErrorMsg := 'Type d''accŠs interdit        ';
    NE_Share         : NetErrorMsg := 'Violation des rŠgles de SHARE ';
    NE_Lock          : NetErrorMsg := 'Erreur de verrouillage        ';
    NE_ShareBuffer   : NetErrorMsg := 'D‚bordement du buffer SHARE   ';
    else               begin
                         str( Numero, Sdummy );
             NetErrorMsg := 'Erreur DOS: ' + Sdummy;
                       end;
  end;
end;

{**********************************************************************}
{* NetRewrite    : Cr‚e un fichier                                    *}
{* Entr‚es       : Nom fichier, mode ouverture, taille enregistrement *}
{* Sortie        : Fichier ouvert                                     *}
{* Var. globales : NetError/W (code d'erreur … l'issue de l'appel     *}
{**********************************************************************}

procedure NetRewrite(     FNom  : string;
                          Mode  : integer;
                          RecS   : word;
                      var Fichier );

var regs   : registers;      { Registres pour g‚rer  les interruptions }
    FNom2 : string;                  { Nom du fichier pour usage local }

begin
  FNom2 := FNom + #0;           { Copie et complŠte le nom du fichier  }
  with regs do
    begin
      ds := seg( FNom2[ 1 ] );                        { Affecte le nom }
      dx := ofs( FNom2[ 1 ] );
      ah := FCT_CREATE;        { Num‚ro de la fonction "Cr‚er fichier" }
      cx := 0 ;                                  { Attribut du fichier }
      msdos( regs );                                   {  Interruption }
      if ( ( flags and fcarry ) = 0 ) then       { Ouverture r‚ussie ? }
        begin
      bx := ax;                                         { Handle en BX }
      ah := FCT_CLOSE;         { Num‚ro de la fonction "Fermer fichier"}
          msdos( regs );
      if ( ( flags and fcarry ) = 0 ) then       { Fermeture r‚ussie ? }
        NetReset( FNom, Mode, Recs, Fichier )      { Rouvre le fichier }
          else
        NetError := ax;                        { Note le code d'erreur }
        end
      else
    NetError := ax;                            { Note le code d'erreur }
    end;
end;

{**********************************************************************}
{* NetReset     : Ouvre un fichier pr‚existant                        *}
{* Entr‚es      : Nom fichier, mode ouverture, taille enregistrement  *}
{* Sortie       : Fichier ouvert                                      *}
{* Var. globales: NetError/W (Code d'erreur aprŠs appel)              *}
{**********************************************************************}

procedure NetReset(     FNom  : string;
                        Mode  : integer;
                        RecS   : word;
                    var Fichier );

var regs : registers;        { Registres pour g‚rer  les interruptions }

begin
  FNom := FNom + #0;        { Le nom du fichier doit se terminer par #0}
  with regs do
    begin
      ds := seg( FNom[ 1 ] );              { Affecte le nom du fichier }
      dx := ofs( FNom[ 1 ] );
      ah := FCT_OPEN;         { Num‚ro de la fonction "Ouvrir fichier" }
      al := Mode;     { Octet d'‚tat pour type d'accŠs et verrouillage }
      msdos( regs );                                   {  Interruption }
      if ( ( flags and fcarry ) = 0 ) then       { Ouverture r‚ussie ? }
        begin
      NetError := NE_OK;                                { Pas d'erreur }
          with filerec( Fichier ) do
            begin
          move( FNom[ 1 ], filerec( Fichier ).Name,{Affecte nom fichier}
            length( FNom ) );
          Handle := ax;                            { Handle du fichier }
          RecSize := RecS;                            { Fixe la taille }
          case ( Mode and $0F ) of            { Fixe le mode en Pascal }
                FM_R   : Mode := FMINPUT;
                FM_W   : Mode := FMOUTPUT;
                FM_RW  : Mode := FMINOUT;
              end;
            end;
        end
      else
        begin
          NetError := ax;                  { M‚morise le code d'erreur }
      filerec( Fichier ).Mode := FMCLOSED;        { Fichier non ouvert }
        end;
    end;
end;

{**********************************************************************}
{* NetClose : Ferme un fichier                                        *}
{* Entr‚e   : Fichier                                                 *}
{* Sortie   : n‚ant                                                   *}
{**********************************************************************}

procedure NetClose( var Fichier );

var regs : registers;        { Registres pour g‚rer  les interruptions }

begin
  if ( Filerec( Fichier ).Mode <> FMCLOSED ) then   { Fichier ouvert ? }
    begin
      with regs do
        begin
      ah := FCT_CLOSE;        { Num‚ro de la fonction "Fermer fichier" }
      bx := FileRec( Fichier ).Handle;             { Handle du fichier }
      msdos( regs );                                   {  Interruption }
        end;
      FileRec( Fichier ).Mode := FMCLOSED;             { Fichier ferm‚ }
      NetError := NE_OK;                                { Pas d'erreur }
    end
  else
    NetError := NE_InvalidHandle;                 { Fichier non ouvert }
end;

{**********************************************************************}
{* Locking     : Verrouillage ou d‚verrouillage d'une zone du fichier *}
{* Entr‚e      : Handle fichier, op‚ration, offset depuis le d‚but du *}
{*               fichier, taille de la zone concern‚e                 *}
{* Sortie      : true si r‚ussi                                       *}
{* Var globales: NetError/W (Code d'erreur … l'issue de l'appel )     *}
{* Info        : Usage exclusivement interne , appel par NetLock      *}
{*               et NetUnlock                                         *}
{**********************************************************************}

function Locking( Handle    : word;
                  Operation : byte;
                  Offset    : longint;
                  Longueur    : longint ) : boolean;

var regs : registers;        { Registres pour g‚rer  les interruptions }

begin
  with regs do
    begin
      ah := FCT_REC_LOCK;  { Num‚ro de la fonction pour l'interruption }
      al := Operation;                          { 0 = Lock, 1 = Unlock }
      bx := Handle;                                { Handle du fichier }
      cx := offset shr 16;                      { Mot fort de l'offset }
      dx := offset and $FFFF;                 { Mot faible de l'offset }
      si := Longueur shr 16;                 { Mot fort de la longueur }
      di := Longueur and $FFFF;            { Mot faible de la longueur }
      msdos( regs );                                   {  Interruption }
      if ( ( flags and fcarry ) = 0 ) then { (D‚)verrouillage r‚ussi ? }
        begin
      Locking := true;                                  { Pas d'erreur }
          NetError := NE_OK;
        end
      else
        begin
          Locking := false;
      NetError := ax;                      { M‚morise le code d'erreur }
        end;
    end;
end;

{**********************************************************************}
{* NetLock       : Verrouillage d'enregistrements                     *}
{* Entr‚e        : Fichier, num‚ro premier enregistrement, nb enreg.  *}
{* Sortie        : true si op‚ration r‚ussie                          *}
{* Var. globales : NetError/W (Code d'erreur … l'issue de l'appel)    *}
{**********************************************************************}

function NetLock( var Fichier;
                      RecNo  : longint;
                      Nombre : longint ) : boolean;

begin
  NetLock := Locking( filerec( Fichier ).Handle, 0,
                      filerec( Fichier ).Recsize * RecNo,
                      filerec( Fichier ).Recsize * Nombre );
end;

{**********************************************************************}
{* NetUnLock     : LibŠre des enregistrements verrouill‚s             *}
{* Entr‚e        : Fichier, num‚ro premier enregistrement, nb enreg.  *}
{* Sortie        : true si op‚ration r‚ussie                          *}
{* Var. globales : NetError/W (Code d'erreur … l'issue de l'appel)    *}
{**********************************************************************}

function NetUnlock( var Fichier;
                        RecNo  : longint;
                        Nombre : longint ) : boolean;
begin
  NetUnLock := Locking( filerec( Fichier).Handle, 1,
                        filerec( Fichier ).Recsize * RecNo,
                        filerec( Fichier ).Recsize * Nombre );
end;

{**********************************************************************}
{* Is_NetWriteOk : Teste si l'‚criture dans un fichier est autoris‚e  *}
{* Entr‚e        : Fichier                                            *}
{* Sortie        : true si ‚criture autoris‚e                         *}
{**********************************************************************}

function Is_NetWriteOk( var Fichier ) : boolean;

begin
  with Filerec( Fichier ) do
    Is_NetWriteOk := ( Mode = FMOUTPUT ) or ( Mode = FMINOUT );
end;

{**********************************************************************}
{* Is_NetReadOk : Teste si la lecture d'un fichier est autoris‚e      *}
{* Entr‚e       : Fichier                                             *}
{* Sortie       : true si lecture autoris‚e                           *}
{**********************************************************************}

function Is_NetReadOk( var Fichier ) : boolean;

begin
  with Filerec( Fichier ) do
    Is_NetReadOk := ( Mode = FMINPUT ) or ( Mode = FMINOUT );
end;

{**********************************************************************}
{* Is_NetOpen  : Teste si un fichier est ouvert                       *}
{* Entr‚e      : Fichier                                              *}
{* Sortie      : true si fichier ouvert                               *}
{**********************************************************************}

function Is_NetOpen( var Fichier ) : boolean;

begin
  with Filerec( Fichier ) do
    Is_Netopen := ( Mode = FMINPUT ) or ( Mode = FMOUTPUT ) or
               ( Mode = FMINOUT );
end;

{**********************************************************************}
{* NetWrite : Ecrit des donn‚es dans un fichier                       *}
{* Entr‚e   : Fichier, Donnees                                        *}
{* Sortie   : n‚ant                                                   *}
{* Info     : L'‚criture n'est possible avec les proc‚dures de pascal *}
{*            que si le fichier a ‚t‚ ouvert en mode Input-Output     *}
{* Attention: pas de contr“le de type                                 *}
{**********************************************************************}

procedure NetWrite( var Fichier;
                    var Donnees );

var regs : registers;        { Registres pour g‚rer  les interruptions }

begin
  with regs do
    begin
      ds := seg( Donnees );                      { Adresse des donn‚es }
      dx := ofs( Donnees );
      ah := FCT_WRITE;    { Num‚ro de la fonction "Ecrire dans fichier"}
      bx := filerec( Fichier ).Handle;             { Handle du fichier }
      cx := filerec( Fichier ).Recsize;              { Nombre d'octets }
      msdos( regs );                                   {  Interruption }
      if ( ( flags and fcarry ) = 0 ) then        { Ecriture r‚ussie ? }
        NetError := NE_OK                               { Pas d'erreur }
      else
        NetError := ax;                    { M‚morise le code d'erreur }
    end;
end;

{**********************************************************************}
{* NetRead  : Lit des donn‚es dans un fichier                         *}
{* Entr‚e   : Fichier, variable pour m‚moriser les donn‚es            *}
{* Sortie   : Donn‚es                                                 *}
{* Info     : La lecture n'est possible avec les proc‚dures de Pascal *}
{*            que si le fichier a ‚t‚ ouvert en mode Input-Output     *}
{ Attention : Pas de contr“le de type                                 *}
{**********************************************************************}

procedure NetRead( var Fichier;
                   var Donnees );

var regs : registers;        { Registres pour g‚rer  les interruptions }

begin
  with regs do
    begin
      ds := seg( Donnees );                      { Adresse des donn‚es }
      dx := ofs( Donnees );
      ah := FCT_READ;            { Num‚ro de la fonction "Lire fichier"}
      bx := filerec( Fichier ).Handle;             { Handle du fichier }
      cx := filerec( Fichier ).Recsize;               { Nombre d'octet }
      msdos( regs );                                   {  Interruption }
      if ( ( flags and fcarry ) = 0 ) then        { Ecriture r‚ussie ? }
        NetError := NE_OK                               { Pas d'erreur }
      else
        NetError := ax;                    { M‚morise le code d'erreur }
    end;
end;

{**********************************************************************}
{* NetSeek : Positionne le pointeur du fichier                        *}
{* Entr‚e  : Fichier, RecordNumero                                    *}
{* Sortie  : n‚ant                                                    *}
{* Info    : La proc‚dure Seek de Pascal n'est possible que si le     *}
{*           fichier a ‚t‚ ouvert en mode Input-Output                *}
{**********************************************************************}

procedure NetSeek( var Fichier;
                       RecNo : longint );

var regs : registers;        { Registres pour g‚rer  les interruptions }

begin
  with regs do
    begin
      ah := FCT_LSEEK;{ Num‚ro de la fonction "Positionner le pointeur"}
      al := 0;      { Position absolue par rapport au d‚but du fichier }
      bx := filerec( Fichier ).Handle;             { Handle du fichier }
      RecNo := RecNo * filerec( Fichier ).Recsize;  { Offset en octets }
      cx := RecNo shr 16;                       { Mot fort de l'offset }
      dx := RecNo and $FFFF;                  { Mot faible de l'offset }
      msdos( regs );                                   {  Interruption }
      if ( ( flags and fcarry ) = 0 ) then       { Op‚ration r‚ussie ? }
        NetError := NE_OK                               { Pas d'erreur }
      else
        NetError := ax;                    { M‚morise le code d'erreur }
    end;
end;

{-- Partie Initialisation de l'unit‚ ----------------------------------}

begin
end.
